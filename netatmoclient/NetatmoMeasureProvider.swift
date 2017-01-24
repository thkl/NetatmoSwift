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
  var timestamp : Date
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
    self.timestamp = managedObject.value(forKey: "timestamp") as! Date
    self.type =  managedObject.value(forKey: "type") as! Int
    self.value =  managedObject.value(forKey: "value") as! Double
  }
  
}



class NetatmoMeasureProvider {
  
  fileprivate let coreDataStore: CoreDataStore!
  
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
  
  func createMeasure(_ timeStamp : Date , type : Int, value: AnyObject? , forStation : NetatmoStation? , forModule : NetatmoModule? )->NSManagedObject? {
    guard let mvalue = value as? Double else {
      return nil
    }
    
    let test = self.getMeasureWithTimeStamp(timeStamp, andType: type)
    
    if (test != nil){
      return test!
    }
    
    
    let newMeasure = NSEntityDescription.insertNewObject(forEntityName: "Measurement", into: coreDataStore.managedObjectContext) 
    
    //let newMeasure = NSManagedObject(entity: coreDataStore.managedObjectContext.persistentStoreCoordinator!.managedObjectModel.entitiesByName["Measurement"]!,
    // insertInto: coreDataStore.managedObjectContext)
    
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
  
  func insertMeasuresWithJsonData(_ json: NSDictionary , forStation : NetatmoStation? , forModule : NetatmoModule?) {
    
    if let body = json["body"] as? Array<NSDictionary> {
      for dat : NSDictionary in body {
        
        let beg_time = (dat["beg_time"] as AnyObject).doubleValue
        var step : Double = 0
        
        let step_time = (dat["step_time"] as AnyObject).doubleValue
        let values = dat["value"] as! Array<NSArray>
        
        for value : NSArray in values {
          
          let dt = Date(timeIntervalSince1970: beg_time! + step)
          
          var measurelist = forStation!.measurementTypes
          
          if (forModule != nil) {
            measurelist = forModule!.measurementTypes
          }
          
          var i = 0
          
          for measureType: NetatmoMeasureType in measurelist {
            self.createMeasure(dt, type: measureType.hashValue , value: value[i] as AnyObject?, forStation: forStation, forModule: forModule)
            i += 1
          }
          
          if (step_time != nil ) { step = step + step_time! }
        }
      }
    }
    
  }
  
  func getLastMeasureDate(_ forStation : NetatmoStation? , forModule : NetatmoModule?)->Date {
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Measurement")
    
    if (forModule != nil) {
      fetchRequest.predicate = NSPredicate(format: "moduleid == %@", argumentArray: [forModule!.id])
    } else {
      if (forStation != nil) {
        fetchRequest.predicate = NSPredicate(format: "stationid == %@ && moduleid = NULL", argumentArray: [forStation!.id])
      }
    }
    
    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
    fetchRequest.fetchLimit = 1
    let results = try! coreDataStore.managedObjectContext.fetch(fetchRequest) as! [NSManagedObject]
    
    if ( results.first != nil ) {
      return results.first?.value(forKey: "timestamp") as! Date
    } else {
      return Date().addingTimeInterval(-86400)
    }
  }
  
  fileprivate func getMeasureWithTimeStamp(_ date : Date , andType : Int)->NSManagedObject? {
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Measurement")
    fetchRequest.predicate = NSPredicate(format: "timestamp == %@ && type == %@", argumentArray: [date,andType])
    
    fetchRequest.fetchLimit = 1
    let results = try! coreDataStore.managedObjectContext.fetch(fetchRequest) as! [NSManagedObject]
    return results.first
  }
  
  func getMeasurementfor(_ station : NetatmoStation, module : NetatmoModule?,
    withTypes:[NetatmoMeasureType], betweenStartDate: Date, andEndDate: Date)->Array<NetatmoMeasure> {
      return self.getMeasurementfor(station, module: module, withTypes: withTypes, betweenStartDate: betweenStartDate, andEndDate: andEndDate,ascending : false)
  }
  
  func getMeasurementfor(_ station : NetatmoStation, module : NetatmoModule?,
    withTypes:[NetatmoMeasureType], betweenStartDate: Date, andEndDate: Date, ascending: Bool)->Array<NetatmoMeasure> {
      
      let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Measurement")
      var resultArray = Array<NetatmoMeasure>()
      let types = withTypes.map({$0.hashValue})
      
      if (module == nil) {
        fetchRequest.predicate = NSPredicate(format: "stationid == %@ && moduleid == NULL && timestamp >= %@ && timestamp <= %@ && type IN %@", argumentArray: [station.id, betweenStartDate,andEndDate,types])
      } else {
        let moduleid = (module != nil) ? module!.id : ""
        fetchRequest.predicate = NSPredicate(format: "stationid == %@ && moduleid == %@ && timestamp >= %@ && timestamp <= %@ && type IN %@", argumentArray: [station.id,moduleid, betweenStartDate,andEndDate,types])
      }
      fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: ascending)]
      
      let results = try! coreDataStore.managedObjectContext.fetch(fetchRequest) as! [NSManagedObject]
      for obj: NSManagedObject in results {
        resultArray.append(NetatmoMeasure(managedObject: obj))
      }
      return resultArray
  }
}
