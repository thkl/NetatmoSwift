//
//  CoreDataStack.swift
//  netatmoclient
//
//  Created by Thomas Kluge on 04.10.15.
//  Copyright © 2015 kSquare.de. All rights reserved.
//

import Foundation
import CoreData


class CoreDataStore {
  
  
  fileprivate lazy var applicationDocumentsDirectory: URL = {
    let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return urls[urls.count-1]
    }()
  
  fileprivate lazy var managedObjectModel: NSManagedObjectModel = {
    let modelURL = Bundle.main.url(forResource: "netatmoclient", withExtension: "momd")!
    return NSManagedObjectModel(contentsOf: modelURL)!
    }()
  
  fileprivate lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
    let url = self.applicationDocumentsDirectory.appendingPathComponent("netatmoclient.sqlite")
    do {
      try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
    } catch {
      fatalError("Couldn't load database: \(error)")
    }
    
    return coordinator
    }()
  
  lazy var managedObjectContext: NSManagedObjectContext = {
    let coordinator = self.persistentStoreCoordinator
    var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    managedObjectContext.persistentStoreCoordinator = coordinator
    return managedObjectContext
    }()
  
  func deleteObject(_ object : NSManagedObject) {
    self.managedObjectContext.delete(object)
    try! self.managedObjectContext.save()
  }
}
