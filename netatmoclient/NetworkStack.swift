//
//  NetworkStack.swift
//  netatmoclient
//
//  Created by Thomas Kluge on 05.10.15.
//  Copyright © 2015 kSquare.de. All rights reserved.
//

import Foundation


class NetworkStack: NSObject, URLSessionDelegate {
  
  enum httpMethod: String {
    case GET = "GET"
    case POST = "POST"
    case HEAT = "HEAT"
    case PUT = "PUT"
  }
  
  let config = URLSessionConfiguration.default

  func callUrl(_ url: URL, method: httpMethod, arguments: [String: AnyObject]?,  completionHandler:  @escaping (_ resultData : Data?, _ error : Error?)->Void) {
    var query : String = ""
    if (arguments != nil) {
        var components: [(String, String)] = []
        for key in Array(arguments!.keys).sorted(by: <) {
          let value = arguments![key]!
          components += queryComponents(key, value)
        }
        query =  (components.map { "\($0)=\($1)" } as [String]).joined(separator: "&")
      }
    let request = NSMutableURLRequest(url: url)

    switch method {
    case .GET , .HEAT , .PUT :
      request.url = url.appendingPathComponent(query)
    case .POST :
      request.httpBody = query.data(using: String.Encoding.utf8)
      request.addValue("application/x-www-form-urlencoded;charset=UTF-8", forHTTPHeaderField: "Content-Type")
    }
    
    request.httpMethod = method.rawValue
    let session = URLSession(configuration: self.config, delegate: self, delegateQueue: nil)
    
    
    let dataTask = session.dataTask(with: request as URLRequest) {data,response,error in
      completionHandler(data, error)
    }

    dataTask.resume()
    
    
    print("Call URL %@", request.url!)
    dataTask.resume()
  }

  
  fileprivate func queryComponents(_ key: String, _ value: AnyObject) -> [(String, String)] {
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
      let value = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
      components.append(key.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!,value!)
    }
    
    return components
  }
  
  
}
