//
//  NetatmoStationProvider.swift
//  netatmoclient
//
//  Created by Thomas Kluge on 04.10.15.
//  Copyright © 2015 kSquare.de. All rights reserved.
//

import Foundation
import CoreData

struct NetatmoStation: Equatable {
  var id: String
  var stationName: String!
  var type: String!
  
  var lastUpgrade : Date!
  var firmware : Int!
  var moduleIds : Array<String> = []
  
  var lastStatusStore : Date = Date()
}

func ==(lhs: NetatmoStation, rhs: NetatmoStation) -> Bool {
  return lhs.id == rhs.id
}


extension NetatmoStation {
  
  init(managedObject : NSManagedObject) {
    self.id = managedObject.value(forKey: "stationid") as! String
    self.stationName = managedObject.value(forKey: "stationname") as! String
    self.type =  managedObject.value(forKey: "stationtype") as! String
  }
  
  var measurementTypes : [NetatmoMeasureType] {
    switch self.type {
    case "NAMain":
      return [.Temperature,.CO2,.Humidity,.Pressure,.Noise]
    case "NAModule1","NAModule4":
      return [.Temperature,.Humidity]
    case "NAModule3":
      return [.Rain]
    case "NAModule2":
      return [.WindStrength,.WindAngle]
    default:
      return []
    }
  }
  
}

class NetatmoStationProvider {
  
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
  
  func stations()->Array<NetatmoStation> {
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Station")
    fetchRequest.fetchLimit = 1
    let results = try! coreDataStore.managedObjectContext.fetch(fetchRequest) as! [NSManagedObject]
    return results.map{NetatmoStation(managedObject: $0 )}
  }
  
  func createStation(_ id: String, name: String, type : String)->NSManagedObject {
    let newStation = NSManagedObject(entity: coreDataStore.managedObjectContext.persistentStoreCoordinator!.managedObjectModel.entitiesByName["Station"]!, insertInto: coreDataStore.managedObjectContext)
    
    newStation.setValue(id, forKey: "stationid")
    newStation.setValue(name, forKey: "stationname")
    newStation.setValue(type, forKey: "stationtype")
    try! coreDataStore.managedObjectContext.save()
    return newStation
  }
  
  func getStationWithId(_ id: String)->NSManagedObject? {
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Station")
    fetchRequest.predicate = NSPredicate(format: "stationid == %@", argumentArray: [id])
    fetchRequest.fetchLimit = 1
    let results = try! coreDataStore.managedObjectContext.fetch(fetchRequest) as! [NSManagedObject]
    return results.first
  }
  
}
