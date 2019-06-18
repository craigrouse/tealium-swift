//
//  TealiumDiskTests.swift
//  tealium-swift
//
//  Created by Craig Rouse on 18/06/2019.
//  Copyright © 2019 Tealium, Inc. All rights reserved.
//

import XCTest
@testable import Tealium

class TealiumDiskTests: XCTestCase {

    let helper = TestTealiumHelper()
    var config: TealiumConfig!
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        config = helper.newConfig()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    func testInit() {
        let diskstorage = TealiumDiskStorage(config: config, forModule: "Tests")
        XCTAssertNotNil(diskstorage)
        XCTAssertEqual(diskstorage.filePrefix, "/\(TealiumTestValue.account).\(TealiumTestValue.profile)/")
    }

    // test that item saved to disk can be retrieved
    func testSave() {
//        let diskstorage = TealiumDiskStorage(config: config, forModule: "Tests")
    }
    
}
