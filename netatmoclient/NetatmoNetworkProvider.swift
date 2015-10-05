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
  
  private let stationprovider = NetatmoStationProvider(coreDataStore: nil)
  private let moduleprovider = NetadmoModuleProvider(coreDataStore: nil)
  private let networkStack = NetworkStack()
  private let loginProvider = NetatmoLoginProvider()
  
  init() {
    assert(netatmo_client_id != nil,"Please provide your ClientID from Netatmo Dev Center (NetatmoCientConstants.swift)")
    assert(netatmo_client_secret != nil,"Please provide your ClientSecret from Netatmo Dev Center (NetatmoCientConstants.swift)")
  }
  
  func loginWithUser(username : String, password : String, completionHandler: (token : String, error : NSError?)->Void) {
    loginProvider.authenticate(username, password: password) { (newToken, error) -> Void in
      completionHandler(token: newToken!, error: error)
    }
  }
  
  func getStationData(completionHandler:(stations :Array<NSManagedObject>? , error : NSError?)->Void) {
    
    loginProvider.getAuthenticationToken { (token) -> Void in
      if token == nil {
        completionHandler(stations: nil, error: NSError(domain: "de.ksquare.netatmo.authenticationtoken_notfound", code: 500, userInfo: nil))
        return
      }
      
      var stations = Array<NSManagedObject>()
      
      let postData = ["access_token":token!]
      let url = NSURL(string: "https://api.netatmo.net/api/devicelist")
      
      self.networkStack.callUrl(url!, method: .POST, arguments: postData) { (resultData, error) -> Void in
        
        do {
          if let parsed = try NSJSONSerialization.JSONObjectWithData(resultData!, options: NSJSONReadingOptions.AllowFragments) as? NSDictionary {
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
            completionHandler(stations: stations ,error: error)
          }
        } catch let error as NSError {
          print("A JSON parsing error occurred, here are the details:\n \(error)")
          completionHandler(stations: nil , error: error)
        }
      }
    }
  }
  
  func fetchMeasurements(device:NetatmoStation ,module: NetatmoModule? ,completionHandler:(error : NSError?)->Void) {
    let mp = NetatmoMeasureProvider(coreDataStore: nil)
    let startDate = mp.getLastMeasureDate(device, forModule: module)
    let endDate = NSDate()
    self.fetchMeasurements(device, module: module, startDate: startDate, endDate: endDate, completionHandler: completionHandler)
  }
  
  func fetchMeasurements(device:NetatmoStation ,module: NetatmoModule?, startDate : NSDate , endDate: NSDate, completionHandler:(error : NSError?)->Void) {
    
    loginProvider.getAuthenticationToken { (token) -> Void in
      if token == nil {
        completionHandler(error: NSError(domain: "", code: 500, userInfo: nil))
        return
      }
      
      let url = NSURL(string: "https://api.netatmo.net/api/getmeasure")
      let mp = NetatmoMeasureProvider(coreDataStore: nil)
      let dbegin = Int(startDate.timeIntervalSince1970)
      let dend = Int(endDate.timeIntervalSince1970)
      
      var measurelist = device.measurementTypes
      var module_id = ""
      
      if (module != nil) {
        module_id =  module!.id
        measurelist = module!.measurementTypes
      }
      
      let typeList = (measurelist.map { "\($0.rawValue)" } as [String]).joinWithSeparator(",")

      
      let postData : [String:AnyObject] = ["access_token":token!,
        "optimize":"true",
        "device_id":device.id,
        "scale":"max",
        "module_id":module_id,
        "type": typeList,
        "date_begin":dbegin,
        "date_end":dend];
      
      self.networkStack.callUrl(url!, method: .POST, arguments: postData) { (resultData, error) -> Void in
        if (error == nil) {
          do {
            if let parsed = try NSJSONSerialization.JSONObjectWithData(resultData!, options: NSJSONReadingOptions.AllowFragments) as? NSDictionary {
              mp.insertMeasuresWithJsonData(parsed, forStation: device, forModule: module)
            }
            completionHandler(error: error)
            
          } catch let error as NSError {
            print("A JSON parsing error occurred, here are the details:\n \(error)")
            completionHandler(error: error)
          }
          
        } else {
          print(error)
          completionHandler(error: error)
        }
        
      };
    }
  }
  
}