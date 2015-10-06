//
//  NetatmoMeasureProvider.swift
//  netatmoclient
//
//  Created by Thomas Kluge on 04.10.15.
//  Copyright © 2015 kSquare.de. All rights reserved.
//

import Foundation
import CoreData

struct NetatmoMeasure: Equatable {
  var timestamp : NSDate
  var type: Int
  var value : Double
  
  var unit : String {
    return (NetatmoMeasureUnit(rawValue: self.type)?.unit)!
  }
}

func ==(lhs: NetatmoMeasure, rhs: NetatmoMeasure) -> Bool {
  return (lhs.timestamp.timeIntervalSince1970 == rhs.timestamp.timeIntervalSince1970) && (lhs.type == rhs.type)
}


extension NetatmoMeasure {
  
  init(managedObject : NSManagedObject) {
    self.timestamp = managedObject.valueForKey("timestamp") as! NSDate
    self.type =  managedObject.valueForKey("type") as! Int
    self.value =  managedObject.valueForKey("value") as! Double
  }
  
}



class NetatmoMeasureProvider {
  
  private let coreDataStore: CoreDataStore!
  
  init(coreDataStore : CoreDataStore?) {
    if (coreDataStore != nil) {
      self.coreDataStore = coreDataStore
    } else {
      self.coreDataStore = CoreDataStore()
    }
  }
  
  func save() {
    try! coreDataStore.managedObjectContext.save()
  }
  
  func createMeasure(timeStamp : NSDate , type : Int, value: AnyObject? , forStation : NetatmoStation? , forModule : NetatmoModule? )->NSManagedObject? {
    guard let mvalue = value as? Double else {
      return nil
    }
    
    let test = self.getMeasureWithTimeStamp(timeStamp, andType: type)
    
    if (test != nil){
      return test!
    }
    
    let newMeasure = NSManagedObject(entity: coreDataStore.managedObjectContext.persistentStoreCoordinator!.managedObjectModel.entitiesByName["Measurement"]!,
      insertIntoManagedObjectContext: coreDataStore.managedObjectContext)
    
    newMeasure.setValue(timeStamp, forKey: "timestamp")
    newMeasure.setValue(type, forKey: "type")
    newMeasure.setValue(mvalue , forKey: "value")
    
    // Fetch Station or Module
    
    if (forStation != nil) {
      newMeasure.setValue(forStation!.id , forKey: "stationid")
    }
    
    if (forModule != nil) {
      newMeasure.setValue(forModule!.id , forKey: "moduleid")
    }
    
    
    try! coreDataStore.managedObjectContext.save()
    return newMeasure
  }
  
  func insertMeasuresWithJsonData(json: NSDictionary , forStation : NetatmoStation? , forModule : NetatmoModule?) {
    
    if let body = json["body"] as? Array<NSDictionary> {
      for dat : NSDictionary in body {
        
        let beg_time = dat["beg_time"]?.doubleValue
        var step : Double = 0
        
        let step_time = dat["step_time"]?.doubleValue
        let values = dat["value"] as! Array<NSArray>
        
        for value : NSArray in values {
          
          let dt = NSDate(timeIntervalSince1970: beg_time! + step)
          
          var measurelist = forStation!.measurementTypes
          
          if (forModule != nil) {
            measurelist = forModule!.measurementTypes
          }
          
          var i = 0
          
          for measureType: NetatmoMeasureType in measurelist {
            self.createMeasure(dt, type: measureType.hashValue , value: value[i], forStation: forStation, forModule: forModule)
            i++
          }
          
          if (step_time != nil ) { step = step + step_time! }
        }
      }
    }
    
  }
  
  func getLastMeasureDate(forStation : NetatmoStation? , forModule : NetatmoModule?)->NSDate {
    let fetchRequest = NSFetchRequest(entityName: "Measurement")
    
    if (forModule != nil) {
      fetchRequest.predicate = NSPredicate(format: "moduleid == %@", argumentArray: [forModule!.id])
    } else {
      fetchRequest.predicate = NSPredicate(format: "stationid == %@ && moduleid = NULL", argumentArray: [forStation!.id])
    }
    
    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
    fetchRequest.fetchLimit = 1
    let results = try! coreDataStore.managedObjectContext.executeFetchRequest(fetchRequest) as! [NSManagedObject]
    
    if ( results.first != nil ) {
      return results.first?.valueForKey("timestamp") as! NSDate
    } else {
      return NSDate().dateByAddingTimeInterval(-3600)
    }
  }
  
  private func getMeasureWithTimeStamp(date : NSDate , andType : Int)->NSManagedObject? {
    let fetchRequest = NSFetchRequest(entityName: "Measurement")
    fetchRequest.predicate = NSPredicate(format: "timestamp == %@ && type == %@", argumentArray: [date,andType])
    
    fetchRequest.fetchLimit = 1
    let results = try! coreDataStore.managedObjectContext.executeFetchRequest(fetchRequest) as! [NSManagedObject]
    return results.first
  }
  
  func getMeasurementfor(station : NetatmoStation, module : NetatmoModule?,
    withTypes:[NetatmoMeasureType], betweenStartDate: NSDate, andEndDate: NSDate)->Array<NetatmoMeasure> {
      return self.getMeasurementfor(station, module: module, withTypes: withTypes, betweenStartDate: betweenStartDate, andEndDate: andEndDate,ascending : false)
  }
  
  func getMeasurementfor(station : NetatmoStation, module : NetatmoModule?,
    withTypes:[NetatmoMeasureType], betweenStartDate: NSDate, andEndDate: NSDate, ascending: Bool)->Array<NetatmoMeasure> {
      
      let fetchRequest = NSFetchRequest(entityName: "Measurement")
      var resultArray = Array<NetatmoMeasure>()
      let types = withTypes.map({$0.hashValue})
      
      if (module == nil) {
        fetchRequest.predicate = NSPredicate(format: "stationid == %@ && moduleid == NULL && timestamp >= %@ && timestamp <= %@ && type IN %@", argumentArray: [station.id, betweenStartDate,andEndDate,types])
      } else {
        let moduleid = (module != nil) ? module!.id : ""
        fetchRequest.predicate = NSPredicate(format: "stationid == %@ && moduleid == %@ && timestamp >= %@ && timestamp <= %@ && type IN %@", argumentArray: [station.id,moduleid, betweenStartDate,andEndDate,types])
      }
      fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: ascending)]
      
      let results = try! coreDataStore.managedObjectContext.executeFetchRequest(fetchRequest) as! [NSManagedObject]
      for obj: NSManagedObject in results {
        resultArray.append(NetatmoMeasure(managedObject: obj))
      }
      return resultArray
  }
}