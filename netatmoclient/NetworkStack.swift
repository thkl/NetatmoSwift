//
//  NetworkStack.swift
//  netatmoclient
//
//  Created by Thomas Kluge on 05.10.15.
//  Copyright © 2015 kSquare.de. All rights reserved.
//

import Foundation


class NetworkStack: NSObject, NSURLSessionDelegate {
  
  enum httpMethod: String {
    case GET = "GET"
    case POST = "POST"
    case HEAT = "HEAT"
    case PUT = "PUT"
  }
  
  let config = NSURLSessionConfiguration.defaultSessionConfiguration()

  func callUrl(url: NSURL, method: httpMethod, arguments: [String: AnyObject]?,  completionHandler: (resultData : NSData?, error : NSError?)->Void) {
    var query : String = ""
    if (arguments != nil) {
        var components: [(String, String)] = []
        for key in Array(arguments!.keys).sort(<) {
          let value = arguments![key]!
          components += queryComponents(key, value)
        }
        query =  (components.map { "\($0)=\($1)" } as [String]).joinWithSeparator("&")
      }
    let request = NSMutableURLRequest(URL: url)

    switch method {
    case .GET , .HEAT , .PUT :
      request.URL = url.URLByAppendingPathComponent(query)
    case .POST :
      request.HTTPBody = query.dataUsingEncoding(NSUTF8StringEncoding)
      request.addValue("application/x-www-form-urlencoded;charset=UTF-8", forHTTPHeaderField: "Content-Type")
    }
    
    request.HTTPMethod = method.rawValue
    let session = NSURLSession(configuration: self.config, delegate: self, delegateQueue: nil)
    let task = session.dataTaskWithRequest(request, completionHandler: { (data, response, error) -> Void in
      completionHandler(resultData: data, error: error)
    })
    task.resume()
  }

  
  private func queryComponents(key: String, _ value: AnyObject) -> [(String, String)] {
    var components: [(String, String)] = []
    if let dictionary = value as? [String: AnyObject] {
      for (nestedKey, value) in dictionary {
        components += queryComponents("\(key)[\(nestedKey)]", value)
      }
    } else if let array = value as? [AnyObject] {
      for value in array {
        components += queryComponents("\(key)[]", value)
      }
    } else {
      let value = "\(value)".stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())
      components.append(key.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!,value!)
    }
    
    return components
  }
  
  
}
