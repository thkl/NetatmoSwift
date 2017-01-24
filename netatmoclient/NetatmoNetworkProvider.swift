//
//  NetworkStack.swift
//  netatmoclient
//
//  Created by Thomas Kluge on 03.10.15.
//  Copyright © 2015 kSquare.de. All rights reserved.
//

import Foundation
import CoreData

class NetatmoNetworkProvider  {
  
  fileprivate let stationprovider = NetatmoStationProvider(coreDataStore: nil)
  fileprivate let moduleprovider = NetadmoModuleProvider(coreDataStore: nil)
  fileprivate let networkStack = NetworkStack()
  fileprivate let loginProvider = NetatmoLoginProvider()
  
  init() {
    assert(netatmo_client_id != nil,"Please provide your ClientID from Netatmo Dev Center (NetatmoCientConstants.swift)")
    assert(netatmo_client_secret != nil,"Please provide your ClientSecret from Netatmo Dev Center (NetatmoCientConstants.swift)")
  }
  
  func loginWithUser(_ username : String, password : String, completionHandler: @escaping (_ token : String, _ error : Error?)->Void) {
    loginProvider.authenticate(username, password: password) { (newToken, error) -> Void in
      completionHandler(newToken!, error)
    }
  }
  
  func getStationData(_ completionHandler:@escaping (_ stations :Array<NSManagedObject>? , _ error : Error?)->Void) {
    
    loginProvider.getAuthenticationToken { (token) -> Void in
      if token == nil {
        completionHandler(nil, NSError(domain: "de.ksquare.netatmo.authenticationtoken_notfound", code: 500, userInfo: nil))
        return
      }
      
      var stations = Array<NSManagedObject>()
      
      let postData = ["access_token":token!]
      let url = URL(string: "https://api.netatmo.net/api/devicelist")
      
      self.networkStack.callUrl(url!, method: .POST, arguments: postData as [String : AnyObject]?) { (resultData, error) -> Void in
        
        do {
          if let parsed = try JSONSerialization.jsonObject(with: resultData!, options: JSONSerialization.ReadingOptions.allowFragments) as? NSDictionary {
            if let body = parsed["body"] as? NSDictionary {
              
              if let devices = body["devices"] as? Array<NSDictionary> {
                for device : NSDictionary in devices {
                  
                  let d_id = device["_id"] as! String
                  let d_name = device["station_name"] as! String
                  let d_type = device["type"] as! String
                  
                  if let station = self.stationprovider.getStationWithId(d_id) {
                    stations.append(station)
                  } else {
                    let station = self.stationprovider.createStation(d_id, name: d_name, type: d_type)
                    stations.append(station)
                  }
                  
                }
              }
              
              if let modules = body["modules"] as? Array<NSDictionary> {
                for module : NSDictionary in modules {
                  let m_mainID = module["main_device"] as! String
                  let m_id = module["_id"] as! String
                  let m_name = module["module_name"] as! String
                  let m_type = module["type"] as! String
                  
                  if (self.moduleprovider.getModuleWithId(m_id) == nil) {
                    self.moduleprovider.createModule(m_id, name: m_name, type: m_type, stationId: m_mainID)
                  }
                }
              }
            }
            completionHandler(stations ,error)
          }
        } catch let error as Error {
          print("A JSON parsing error occurred, here are the details:\n \(error)")
          completionHandler(nil , error)
        }
      }
    }
  }
  
  /**
  query measurements for all known stations and modules
  
  - parameter startDate:         date of the first Measurement
  - parameter endDate:           date of the last Measurement
  - parameter completionHandler: the completion Handler
  */
  func fetchMeasurements(_ startDate : Date , endDate: Date, completionHandler:(_ error : Error?)->Void) {
    let stations = self.stationprovider.stations()
    
    let semaphore = DispatchSemaphore(value: 0);
    let fetching_queue = DispatchQueue(label: "de.ksquare.netatmo", attributes: [])
    for station in stations {
      
      fetching_queue.sync(execute: {
        self.fetchMeasurements(station , module: nil, startDate : startDate , endDate: endDate, completionHandler: { (error) -> Void in
           semaphore.signal();
        })
      })
     
      semaphore.wait(timeout: DispatchTime.distantFuture);
      
      for module in moduleprovider.modulesAtStation(station) {
        fetching_queue.sync(execute: {
          self.fetchMeasurements(station , module: module, startDate : startDate , endDate: endDate, completionHandler: { (error) -> Void in
            semaphore.signal();
          })
        })
        semaphore.wait(timeout: DispatchTime.distantFuture);
      }
      
    }
    completionHandler(nil)
  }

  func fetchMeasurements() {
    let stations = self.stationprovider.stations()
    
    for station in stations {
      
        self.fetchMeasurements(station , module: nil, completionHandler: { (error) -> Void in
          NotificationCenter.default.post(name: Notification.Name(rawValue: "databaseChanged"), object: nil)
        })
  
      
      
      for module in moduleprovider.modulesAtStation(station) {
          self.fetchMeasurements(station , module: module, completionHandler: { (error) -> Void in
            NotificationCenter.default.post(name: Notification.Name(rawValue: "databaseChanged"), object: nil)
          })
      }
      
    }
  }
  
  
  /**
  query measurements for a given Station or Module
  the Date of the first Measurement is the last known Date of an existing Value in Database
  the End Date is the current Date
  
  - parameter device:            the Device
  - parameter module:            option the Module
  - parameter completionHandler: completiona Handler
  */
  func fetchMeasurements(_ device:NetatmoStation ,module: NetatmoModule? ,completionHandler:@escaping (_ error : Error?)->Void) {
    let mp = NetatmoMeasureProvider(coreDataStore: nil)
    let startDate = mp.getLastMeasureDate(device, forModule: module)
    
    let endDate = Date()
    self.fetchMeasurements(device, module: module, startDate: startDate, endDate: endDate, completionHandler: completionHandler)
  }
  
  func fetchMeasurements(_ device:NetatmoStation ,module: NetatmoModule?, startDate : Date , endDate: Date, completionHandler:@escaping (_ error : Error?)->Void) {
    
    loginProvider.getAuthenticationToken { (token) -> Void in
      if token == nil {
        completionHandler(NSError(domain: "", code: 500, userInfo: nil))
        return
      }
      
      let url = URL(string: "https://api.netatmo.net/api/getmeasure")
      let mp = NetatmoMeasureProvider(coreDataStore: nil)
      let dbegin = Int(startDate.timeIntervalSince1970)
      let dend = Int(endDate.timeIntervalSince1970)
      
      var measurelist = device.measurementTypes
      var module_id = ""
      
      if (module != nil) {
        module_id =  module!.id
        measurelist = module!.measurementTypes
      }
      
      let typeList = (measurelist.map { "\($0.rawValue)" } as [String]).joined(separator: ",")

      
      let postData : [String:AnyObject] = ["access_token":token! as AnyObject,
        "optimize":"true" as AnyObject,
        "device_id":device.id as AnyObject,
        "scale":"max" as AnyObject,
        "module_id":module_id as AnyObject,
        "type": typeList as AnyObject,
        "date_begin":dbegin as AnyObject,
        "date_end":dend as AnyObject];
      
      self.networkStack.callUrl(url!, method: .POST, arguments: postData) { (resultData, error) -> Void in
        if (error == nil) {
          do {
            if let parsed = try JSONSerialization.jsonObject(with: resultData!, options: JSONSerialization.ReadingOptions.allowFragments) as? NSDictionary {
             
              DispatchQueue.main.async {
                mp.insertMeasuresWithJsonData(parsed, forStation: device, forModule: module)
              }
              
            }
            completionHandler(error)
            
          } catch let error as NSError {
            print("A JSON parsing error occurred, here are the details:\n \(error)")
            completionHandler(error)
          }
          
        } else {
          print(error)
          completionHandler(error)
        }
        
      };
    }
  }
  
}
