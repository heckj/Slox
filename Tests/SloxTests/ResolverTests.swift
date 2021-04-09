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
    var interpretter = Interpretter()
    var resolver: Resolver?

    override func setUp() {
        // fresh new interpretter for each test
        interpretter = Interpretter(collectOutput: true)
    }

    /*
     general flow of the pipeline
     let tokenlist = Scanner(source).scanTokens()
     // print("Scanner generated tokens: \(tokenlist)")
     let parser = Parser(tokenlist)
     let statements = parser.parse()
     let resolver = Resolver(interpretter: interpretter)
     resolver.resolve(statements)
     ^^ we want to test sequencing through here,
        inspect the resolver's included scopes
        and verify it was created correctly.
     try interpretter.interpretStatements(statements)
     */

    func testResolverInspection() throws {
        XCTAssertNil(interpretter.globals.enclosing)
        // initial setup should only have the external 'clock' function defined
        XCTAssertEqual(interpretter.globals.values.count, 1)
        XCTAssertNotNil(interpretter.globals.values["clock"])

        // print(interpretter.globals.values)
        let envKeys = interpretter.environment.values.keys
        XCTAssertEqual(envKeys.count, 1)
        // collected print statements should be 0 at the start
        XCTAssertNotNil(interpretter.tickerTape)
        XCTAssertEqual(interpretter.tickerTape?.count, 0)

        resolver = Resolver(interpretter)
        // make sure we've got one first...
        guard let resolver = resolver else {
            XCTFail("Nil resolver")
            return
        }
        // resolve should start completely empty
        XCTAssertEqual(resolver.scopes.count, 0)
    }

    func testResolverWithVariousScopes() throws {
        let tokenlist = Slox.Scanner(LOXSource.chap8_14.source).scanTokens()
        let parser = Parser(tokenlist)
//         print("Source:")
//         print("  \(LOXSource.chap8_14)")
        let statements = parser.parse()
        XCTAssertEqual(parser.errors.count, 0, "expected 0 errors, found \(parser.errors.count)")
        if parser.errors.count != 0 {
            parser.printErrors()
        }
        let resolver = Resolver(interpretter)
//        interpretter.omgVerbose = true
//        resolver.omgVerbose = true

        try resolver.resolve(statements)

//        print("Scopes: \(resolver.scopes)")
        XCTAssertEqual(resolver.scopes.count, 0)

//        print("Interpreter locals: \(interpretter.locals)")
        XCTAssertEqual(interpretter.locals.count, 4)
    }

    func testResolverWithShadowedblock() throws {
        let tokenlist = Slox.Scanner(LOXSource.chap11_1a.source).scanTokens()
        let parser = Parser(tokenlist)
        // print("Source:")
        // print("  \(LOXSource.chap11_1a)")
        let statements = parser.parse()
        XCTAssertEqual(parser.errors.count, 0, "expected 0 errors, found \(parser.errors.count)")
        if parser.errors.count != 0 {
            parser.printErrors()
        }
        let resolver = Resolver(interpretter)
        // resolver.omgVerbose = true

        XCTAssertThrowsError(try resolver.resolve(statements), "Expected RuntimeError.readingVarInInitialization") { err in
            if let rte = err as? RuntimeError {
                switch rte {
                case RuntimeError.readingVarInInitialization:
                    return
                default:
                    XCTFail("Expected .incorrectArgumentCount error")
                }
            } else {
                XCTFail("Expected RuntimeError error")
            }
        }
    }

    func testResolvingCounterWithExplicitReturn() throws {
        let tokenlist = Slox.Scanner(LOXSource.chap10_7.source).scanTokens()
        let parser = Parser(tokenlist)
        // XTRA verboseness for debugging parsing
        // parser.omgVerbose = true
        // print("Source:")
        // print("  \(LOXSource.chap10_7)")
        // var indention = 1
        // for token in tokenlist {
        //     print(String(repeating: " ", count: indention), terminator: "")
        //     print("| \(token) |")
        // indention += 1
        // }
        let statements = parser.parse()
        XCTAssertEqual(parser.errors.count, 0, "expected 0 errors, found \(parser.errors.count)")
        if parser.errors.count != 0 {
            parser.printErrors()
        }
//         print("Retrieved statements:")
//         for stmt in statements {
//             print("  \(stmt)")
//         }
        let resolver = Resolver(interpretter)
        // resolver.omgVerbose = true
        try resolver.resolve(statements)

        // interpretter.omgIndent = 0
        // interpretter.omgVerbose = true
        // resolver.omgVerbose = true

        XCTAssertEqual(resolver.scopes.count, 0)

//        print("Interpreter locals: \(interpretter.locals)")
        XCTAssertEqual(interpretter.locals.count, 6)
    }

    func testResolvingForLoop() throws {
        let tokenlist = Slox.Scanner(LOXSource.chap11_4.source).scanTokens()
        let parser = Parser(tokenlist)
        // XTRA verboseness for debugging parsing
        // parser.omgVerbose = true
//        print("Source: =====================")
//        print("\(LOXSource.chap11_4.source)")
//        print("=============================")
        // var indention = 1
        // for token in tokenlist {
        //     print(String(repeating: " ", count: indention), terminator: "")
        //     print("| \(token) |")
        // indention += 1
        // }
        let statements = parser.parse()
        XCTAssertEqual(parser.errors.count, 0, "expected 0 errors, found \(parser.errors.count)")
        if parser.errors.count != 0 {
            parser.printErrors()
        }
//         print("Retrieved statements:")
//         for stmt in statements {
//             print("  \(stmt)")
//         }
        let resolver = Resolver(interpretter)
//        resolver.omgVerbose = true
//        interpretter.omgIndent = 0
//        interpretter.omgVerbose = true
        try resolver.resolve(statements)

        XCTAssertEqual(resolver.scopes.count, 0)

//        print("Interpreter locals: \(interpretter.locals)")
        XCTAssertEqual(interpretter.locals.count, 4)
    }

    func testResolvingFibonaci() throws {
        let tokenlist = Slox.Scanner(LOXSource.chap10_8.source).scanTokens()
        let parser = Parser(tokenlist)
        // XTRA verboseness for debugging parsing
        // parser.omgVerbose = true
//        print("Source: =====================")
//        print("\(LOXSource.chap10_8.source)")
//        print("=============================")
        // var indention = 1
        // for token in tokenlist {
        //     print(String(repeating: " ", count: indention), terminator: "")
        //     print("| \(token) |")
        // indention += 1
        // }
        let statements = parser.parse()
        XCTAssertEqual(parser.errors.count, 0, "expected 0 errors, found \(parser.errors.count)")
        if parser.errors.count != 0 {
            parser.printErrors()
        }
        // print("Retrieved statements:")
        // for stmt in statements {
        //     print("  \(stmt)")
        // }
        let resolver = Resolver(interpretter)
//        resolver.omgVerbose = true
//        interpretter.omgIndent = 0
//        interpretter.omgVerbose = true
        try resolver.resolve(statements)

        XCTAssertEqual(resolver.scopes.count, 0)

//        print("Interpreter locals: \(interpretter.locals)")
        XCTAssertEqual(interpretter.locals.count, 8)
    }
}
