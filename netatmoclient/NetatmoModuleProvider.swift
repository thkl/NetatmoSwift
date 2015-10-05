//
//  NetadmoModuleProvider.swift
//  netatmoclient
//
//  Created by Thomas Kluge on 04.10.15.
//  Copyright © 2015 kSquare.de. All rights reserved.
//

import Foundation
import CoreData

struct NetatmoModule: Equatable {
  var id: String
  var moduleName: String
  var type: String
  var stationid : String
}

func ==(lhs: NetatmoModule, rhs: NetatmoModule) -> Bool {
  return lhs.id == rhs.id
}


extension NetatmoModule {
  
  init(managedObject : NSManagedObject) {
    self.id = managedObject.valueForKey("moduleid") as! String
    self.moduleName = managedObject.valueForKey("modulename") as! String
    self.type =  managedObject.valueForKey("moduletype") as! String
    self.stationid =  managedObject.valueForKey("parentstationid") as! String
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



class NetadmoModuleProvider {
  
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
  
  func modules()->Array<NetatmoModule> {
    let fetchRequest = NSFetchRequest(entityName: "Module")
    fetchRequest.fetchLimit = 1
    let results = try! coreDataStore.managedObjectContext.executeFetchRequest(fetchRequest) as! [NSManagedObject]
    return results.map{NetatmoModule(managedObject: $0 )}
  }

  
  func createModule(id: String, name: String, type : String,stationId : String)->NSManagedObject {
    let newModule = NSManagedObject(entity: coreDataStore.managedObjectContext.persistentStoreCoordinator!.managedObjectModel.entitiesByName["Module"]!, insertIntoManagedObjectContext: coreDataStore.managedObjectContext)
    
    newModule.setValue(id, forKey: "moduleid")
    newModule.setValue(name, forKey: "modulename")
    newModule.setValue(type, forKey: "moduletype")
    newModule.setValue(stationId, forKey: "parentstationid")
    try! coreDataStore.managedObjectContext.save()
    return newModule
  }
  
  func getModuleWithId(id: String)->NSManagedObject? {
    let fetchRequest = NSFetchRequest(entityName: "Module")
    fetchRequest.predicate = NSPredicate(format: "moduleid == %@", argumentArray: [id])
    fetchRequest.fetchLimit = 1
    let results = try! coreDataStore.managedObjectContext.executeFetchRequest(fetchRequest) as! [NSManagedObject]
    return results.first
  }
  
}