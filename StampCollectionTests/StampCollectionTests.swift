//
//  StampCollectionTests.swift
//  StampCollectionTests
//
//  Created by Michael L Mehr on 4/9/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit
import XCTest
@testable import StampCollection

class StampCollectionTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testXCTestSystem() {
        // This is an example of a functional test case.
        XCTAssert(true, "Pass")
    }
//
//    func testPerformanceExample() {
//        // This is an example of a performance test case.
//        self.measureBlock() {
//            // Put the code you want to measure the time of here.
//        }
//    }
    
    func testMainStoreWithNoInitBlock() {
        let dataModel = CollectionStore()
        XCTAssert(!dataModel.initialized, "Uninitialized basic CoreData stack at start")
    }
    
    func testMainStoreWithInitBlock() {
        let timeout: TimeInterval = 10.0
        let expectation = self.expectation(description: "Should be initialized after start timeout of \(timeout) seconds.")
        let dataModel = CollectionStore() {
            expectation.fulfill()
            print("Called final block of init with INITIALIZED = ???.")
        }
        XCTAssert(!dataModel.initialized, "Uninitialized basic CoreData stack at start")
        waitForExpectations(timeout: timeout, handler: nil)
    }
    
}
