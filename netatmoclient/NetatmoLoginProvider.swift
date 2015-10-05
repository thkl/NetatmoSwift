//
//  NetatmoLoginProvider.swift
//  netatmoclient
//
//  Created by Thomas Kluge on 05.10.15.
//  Copyright © 2015 kSquare.de. All rights reserved.
//

import Foundation
import CoreData

class NetatmoLoginProvider {
  
  let coreDataStore = CoreDataStore()
  
  /**
  Fetch current Token as an NSManagedObject from the Database
  */
  private func getTokenObject(tokenName : String)->NSManagedObject? {
    let fetchRequest = NSFetchRequest(entityName: "Metadata")
    fetchRequest.predicate = NSPredicate(format: "key == %@",tokenName)
    fetchRequest.fetchLimit = 1
    let results = try! coreDataStore.managedObjectContext.executeFetchRequest(fetchRequest) as! [NSManagedObject]
    if results.count == 0 {
      return nil
    }
    return results.first!
  }
  
  
  /**
  Returns the current token which stored in the Database
  if the token is not there or if its invalid the method returns nil
  */
  func getAuthenticationToken(completionhandler:(token: String?)->Void) {
    
    guard let token = self.getTokenObject("authToken") else {
      completionhandler(token: nil)
      return
    }
    
    guard let expiration = token.valueForKey("expires") as? NSDate else {
      completionhandler(token: nil)
      return
    }
    
    if (expiration.timeIntervalSinceDate(NSDate())>0) {
      completionhandler(token: token.valueForKey("value") as? String)
      return
    }

    // token is no longer valid - lets refresh them
    NSLog("Authentication Token found, have to refresh")
    self.refreshAuthenticationToken { (newToken, error) -> Void in
      if (error == nil) {
        completionhandler(token: newToken)
        return
      } else {
        completionhandler(token: nil)
        return
      }
    }
  }
  
  /**
  Deletes the current token Object in the Database
  */
  func deleteAuthenticationToken() {
    guard let token = self.getTokenObject("authToken") else {
      return
    }
    coreDataStore.deleteObject(token)
  }
  
  
  
  /**
  Refreshes the current Token agains the Netatmo API
  */
  func refreshAuthenticationToken(completionhandler:(newToken: String?, error:NSError?)->Void) {
    guard let refreshToken = self.getTokenObject("refresh_token") else {
      completionhandler(newToken: nil, error: NSError(domain: "de.ksquare.netatmo.refreshtoken_notfound", code: 500, userInfo: nil))
      return
    }
    
    let networkStack = NetworkStack()
    let url = NSURL(string: "https://api.netatmo.net/oauth2/token")
    let strToken = refreshToken.valueForKey("value") as! String
    
    let postData = ["grant_type":"refresh_token",
      "client_id":netatmo_client_id!,
      "client_secret":netatmo_client_secret!,
      "refresh_token":strToken]
    
    networkStack.callUrl(url!, method: .POST, arguments: postData) { (resultData, error) -> Void in
      
      if (error == nil) {
        do {
          if let parsed = try NSJSONSerialization.JSONObjectWithData(resultData!, options: NSJSONReadingOptions.AllowFragments) as? NSDictionary {
            let expireDate = NSDate().dateByAddingTimeInterval(parsed["expires_in"] as! Double)
            let accessToken = parsed["access_token"] as! String
            let refreshToken = parsed["refresh_token"] as! String
            self.storeToken("authToken", tokenValue: accessToken, expiredAt: expireDate)
            self.storeToken("refreshToken", tokenValue: refreshToken, expiredAt: expireDate)
            completionhandler(newToken: accessToken, error: nil)
          }
          
        }catch let error as NSError {
          print("A JSON parsing error occurred, here are the details:\n \(error)")
          completionhandler(newToken: nil,error: error)
        }
      }
    }
  }
  
  
  private func storeToken(tokenName : String, tokenValue: String, expiredAt: NSDate) {
    // First check an old Token for updateing
    if let token = self.getTokenObject(tokenName) {
      token.setValue(tokenValue, forKey: "value")
      token.setValue(expiredAt, forKey: "expires")
      try! coreDataStore.managedObjectContext.save()
    } else {
      // Create a new DB Object
      let newToken = NSManagedObject(entity: coreDataStore.managedObjectContext.persistentStoreCoordinator!.managedObjectModel.entitiesByName["Metadata"]!, insertIntoManagedObjectContext: coreDataStore.managedObjectContext)
      newToken.setValue(tokenName, forKey: "key")
      newToken.setValue(tokenValue, forKey: "value")
      newToken.setValue(expiredAt, forKey: "expires")
      try! coreDataStore.managedObjectContext.save()
    }
  }
  
  /**
  Make a full Login onto the Netatmo API
  */
  func authenticate(username: String, password: String, completionhandler:(newToken: String? , error : NSError?)->Void) {
    
    //do nothing if the token is still valid
    //todo Refresh the token
    self.getAuthenticationToken { (token) -> Void in
      
      if (token != nil) {
        NSLog("Use cached Token")
        completionhandler(newToken: token, error: nil)
        return
      }
      
      let networkStack = NetworkStack()
      let url = NSURL(string: "https://api.netatmo.net/oauth2/token")
      
      let postData = ["grant_type":"password",
        "client_id":netatmo_client_id!,
        "client_secret":netatmo_client_secret!,
        "username":username,
        "password":password]
      
      networkStack.callUrl(url!, method: .POST, arguments: postData) { (resultData, error) -> Void in
        
        if (error == nil) {
          do {
            if let parsed = try NSJSONSerialization.JSONObjectWithData(resultData!, options: NSJSONReadingOptions.AllowFragments) as? NSDictionary {
              let expireDate = NSDate().dateByAddingTimeInterval(parsed["expires_in"] as! Double)
              let accessToken = parsed["access_token"] as! String
              let refreshToken = parsed["refresh_token"] as! String
              self.storeToken("authToken", tokenValue: accessToken, expiredAt: expireDate)
              self.storeToken("refreshToken", tokenValue: refreshToken, expiredAt: expireDate)
              completionhandler(newToken: accessToken , error: nil)
            }
            
          }catch let error as NSError {
            print("A JSON parsing error occurred, here are the details:\n \(error)")
            completionhandler(newToken: nil, error: error)
          }
        } else {
          completionhandler(newToken: nil, error: error)
        }
      }
    }
  }
  
}