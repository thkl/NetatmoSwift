//
//  NetatmoCientConstants.swift
//  netatmoclient
//
//  Created by Thomas Kluge on 05.10.15.
//  Copyright © 2015 kSquare.de. All rights reserved.
//

import Foundation

//  Create an Application at dev.netatmo.com for theese values 
let netatmo_client_id : String? = "..."
let netatmo_client_secret : String? = "..."

let netatmo_username : String = "..."
let netatmo_password : String = "..."

enum NetatmoMeasureType: String {
  case Temperature = "Temperature"
  case CO2 = "CO2"
  case Humidity = "Humidity"
  case Pressure = "Pressure"
  case Noise = "Noise"
  case Rain = "Rain"
  case WindStrength = "WindStrength"
  case WindAngle = "WindAngle"
}

enum NetatmoMeasureUnit: Int {
  case Temperature,CO2,Humidity,Pressure,Noise,Rain,WindStrength,WindAngle
    
  var unit : String {
    switch self {
    case .Temperature: return "°C"
    case .CO2: return "ppm"
    case .Humidity: return "%"
    case .Pressure: return "mbar"
    case .Noise: return "db"
    case .Rain: return "mm"
    case .WindStrength: return "km/h"
    case .WindAngle: return "°"
    }
  }
  
}



