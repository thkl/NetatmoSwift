//
//  netatmoclientTests.swift
//  netatmoclientTests
//
//  Created by Thomas Kluge on 03.10.15.
//  Copyright © 2015 kSquare.de. All rights reserved.
//

import XCTest
@testable import netatmoclient

class netatmoclientTests: XCTestCase {
  
  let provider = NetatmoNetworkProvider()
  
  let stationProvider = NetatmoStationProvider(coreDataStore: nil)
  let moduleProvider = NetadmoModuleProvider(coreDataStore: nil)
  let measurementProvider = NetatmoMeasureProvider(coreDataStore: nil)
  
  override func setUp() {
    super.setUp()
    let readyExpectation = expectationWithDescription("ready")
    
    provider.loginWithUser(netatmo_username, password: netatmo_password) { (token, error) -> Void in
      XCTAssertNotNil(token)
      readyExpectation.fulfill()
    }
    
    waitForExpectationsWithTimeout(60, handler: { error in
      XCTAssertNil(error, "Error")
    })
  }
  
  
  func testLoadElements() {
    let readyExpectation = expectationWithDescription("ready")
    provider.getStationData { (stations, error) -> Void in
      XCTAssertNotNil(stations)
      readyExpectation.fulfill()
    }
    
    waitForExpectationsWithTimeout(60, handler: { error in
      XCTAssertNil(error, "Error")
    })
  }
  
  func testFetchStationMeasurements() {
    let readyExpectation = expectationWithDescription("ready")
    let station = stationProvider.stations().first
    provider.fetchMeasurements(station!, module: nil) { (error) -> Void in
      XCTAssertNil(error)
      readyExpectation.fulfill()
    }
    
    waitForExpectationsWithTimeout(60, handler: { error in
      XCTAssertNil(error, "Error")
    })
  }

  func testFetchModuleMeasurements() {
    let readyExpectation = expectationWithDescription("ready")
    let station = stationProvider.stations().first
    let module = moduleProvider.modules().first
    
    provider.fetchMeasurements(station!, module: module) { (error) -> Void in
      XCTAssertNil(error)
      readyExpectation.fulfill()
    }
    
    waitForExpectationsWithTimeout(60, handler: { error in
      XCTAssertNil(error, "Error")
    })
  }

  func testFetchLastMeasurementFromDatabase() {

    let station = stationProvider.stations().first
    let module = moduleProvider.modules().first
    let startDate = measurementProvider.getLastMeasureDate(station, forModule: module)
    let result = measurementProvider.getMeasurementfor(station!, module: nil, withType: .CO2 , betweenStartDate: startDate, andEndDate: NSDate())
    
    XCTAssertNotEqual(result.count, 0)
    let lr = result.last
    let strResult = "Last Measurement in Database is \(lr!.timestamp) - \(lr!.value)\(lr!.unit)"
    print(strResult)
  }

  
}
