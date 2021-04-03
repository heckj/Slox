//
//  File.swift
//
//
//  Created by Joseph Heck on 4/3/21.
//

import Foundation
@testable import Slox
import XCTest

final class ResolverTests: XCTestCase {
    var interpretter: Interpretter
    var resolver: Resolver

    override init() {
        interpretter = Interpretter()
        resolver = Resolver(interpretter: interpretter)
        super.init()
    }

    override func setUp() {
        // fresh new interpretter for each test
        interpretter = Interpretter(collectOutput: true)
        resolver = Resolver(interpretter: interpretter)
    }
}
