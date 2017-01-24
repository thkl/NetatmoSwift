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
  fileprivate func getTokenObject(_ tokenName : String)->NSManagedObject? {
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Metadata")
    fetchRequest.predicate = NSPredicate(format: "key == %@",tokenName)
    fetchRequest.fetchLimit = 1
    let results = try! coreDataStore.managedObjectContext.fetch(fetchRequest) as! [NSManagedObject]
    if results.count == 0 {
      return nil
    }
    return results.first!
  }
  
  
  /**
   Returns the current token which stored in the Database
   if the token is not there or if its invalid the method returns nil
   */
  func getAuthenticationToken(_ completionhandler:@escaping (_ token: String?)->Void) {
    
    guard let token = self.getTokenObject("authToken") else {
      completionhandler(nil)
      return
    }
    
    guard let expiration = token.value(forKey: "expires") as? Date else {
      completionhandler(nil)
      return
    }
    
    if (expiration.timeIntervalSince(Date())>0) {
      NSLog("Authentication Token found, is still valid")
      completionhandler(token.value(forKey: "value") as? String)
      return
    }
    
    // token is no longer valid - lets refresh them
    NSLog("Authentication Token found, have to refresh")
    self.refreshAuthenticationToken { (newToken, error) -> Void in
      if (error == nil) {
        completionhandler(newToken)
        return
      } else {
        completionhandler(nil)
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
  func refreshAuthenticationToken(_ completionhandler:@escaping (_ newToken: String?, _ error:NSError?)->Void) {
    guard let refreshToken = self.getTokenObject("refresh_token") else {
      completionhandler(nil, NSError(domain: "de.ksquare.netatmo.refreshtoken_notfound", code: 500, userInfo: nil))
      return
    }
    
    let networkStack = NetworkStack()
    let url = URL(string: "https://api.netatmo.net/oauth2/token")
    let strToken = refreshToken.value(forKey: "value") as! String
    
    let postData = ["grant_type":"refresh_token",
                    "client_id":netatmo_client_id!,
                    "client_secret":netatmo_client_secret!,
                    "refresh_token":strToken]
    
    networkStack.callUrl(url!, method: .POST, arguments: postData as [String : AnyObject]?) { (resultData, error) -> Void in
      
      if (error == nil) {
        do {
          if let parsed = try JSONSerialization.jsonObject(with: resultData!, options: JSONSerialization.ReadingOptions.allowFragments) as? NSDictionary {
            let expireDate = Date().addingTimeInterval(parsed["expires_in"] as! Double)
            let accessToken = parsed["access_token"] as! String
            let refreshToken = parsed["refresh_token"] as! String
            self.storeToken("authToken", tokenValue: accessToken, expiredAt: expireDate)
            self.storeToken("refreshToken", tokenValue: refreshToken, expiredAt: expireDate)
            completionhandler(accessToken, nil)
          }
          
        }catch let error as NSError {
          print("A JSON parsing error occurred, here are the details:\n \(error)")
          completionhandler(nil,error)
        }
      }
    }
  }
  
  
  fileprivate func storeToken(_ tokenName : String, tokenValue: String, expiredAt: Date) {
    // First check an old Token for updateing
    if let token = self.getTokenObject(tokenName) {
      token.setValue(tokenValue, forKey: "value")
      token.setValue(expiredAt, forKey: "expires")
      try! coreDataStore.managedObjectContext.save()
    } else {
      // Create a new DB Object
      let newToken = NSManagedObject(entity: coreDataStore.managedObjectContext.persistentStoreCoordinator!.managedObjectModel.entitiesByName["Metadata"]!, insertInto: coreDataStore.managedObjectContext)
      newToken.setValue(tokenName, forKey: "key")
      newToken.setValue(tokenValue, forKey: "value")
      newToken.setValue(expiredAt, forKey: "expires")
      try! coreDataStore.managedObjectContext.save()
    }
  }
  
  /**
   Make a full Login onto the Netatmo API
   */
  func authenticate(_ username: String, password: String, completionhandler:@escaping (_ newToken: String? , _ error : Error?)->Void) {
    
    //do nothing if the token is still valid
    //todo Refresh the token
    self.getAuthenticationToken { (token) -> Void in
      
      if (token != nil) {
        NSLog("Use cached Token")
        completionhandler(token, nil)
        return
      }
      
      let networkStack = NetworkStack()
      let url = URL(string: "https://api.netatmo.net/oauth2/token")
      
      let postData = ["grant_type":"password",
                      "client_id":netatmo_client_id!,
                      "client_secret":netatmo_client_secret!,
                      "username":username,
                      "password":password]
      
      networkStack.callUrl(url!, method: .POST, arguments: postData as [String : AnyObject]?) { (resultData, error) -> Void in
        
        if (error == nil) {
          do {
            if let parsed = try JSONSerialization.jsonObject(with: resultData!, options: JSONSerialization.ReadingOptions.allowFragments) as? NSDictionary {
              if let expired = parsed["expires_in"] as? Double {
                let expireDate = Date().addingTimeInterval(expired)
                let accessToken = parsed["access_token"] as! String
                let refreshToken = parsed["refresh_token"] as! String
                self.storeToken("authToken", tokenValue: accessToken, expiredAt: expireDate)
                self.storeToken("refreshToken", tokenValue: refreshToken, expiredAt: expireDate)
                completionhandler(accessToken , nil)
              } else {
                completionhandler(nil , nil)
              }
            }
            
          }catch let error as NSError {
            print("A JSON parsing error occurred, here are the details:\n \(error)")
            completionhandler(nil, error)
          }
        } else {
          completionhandler(nil, error)
        }
      }
    }
  }
  
}
