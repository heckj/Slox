@testable import Slox
import XCTest

final class IntepretterTests: XCTestCase {
    var interpretter = Interpretter()

    override func setUp() {
        // fresh new interpretter for each test
        interpretter = Interpretter(collectOutput: true)
    }

    func testInterpretterInspection() throws {
        XCTAssertEqual(interpretter.globals.stack.count,1)
        // initial setup should only have the external 'clock' function defined
        XCTAssertNotNil(interpretter.globals.testGet("clock"))
        XCTAssertEqual(interpretter.globals.testCount(), 1)
        
        XCTAssertEqual(interpretter.environment.stack.count,1)
        // initial setup should only have the external 'clock' function defined
        XCTAssertNotNil(interpretter.environment.testGet("clock"))
        XCTAssertEqual(interpretter.environment.testCount(), 1)
        
        // collected print statements should be 0 at the start
        XCTAssertNotNil(interpretter.tickerTape)
        XCTAssertEqual(interpretter.tickerTape?.count, 0)
    }

    func testInterpretterWithRuntimeError() throws {
        let tokenlist = Slox.Scanner(LOXSource.chap10_1.source).scanTokens()
        let parser = Parser(tokenlist)
        let statements = parser.parse()
        XCTAssertEqual(parser.errors.count, 0, "expected 0 errors, found \(parser.errors.count)")
        if parser.errors.count != 0 {
            parser.printErrors()
        }
        XCTAssertThrowsError(try interpretter.interpretStatements(statements), "Expected incorrectArgumentCount error") { err in
            if let rte = err as? RuntimeError {
                switch rte {
                case let .incorrectArgumentCount(expected: expected, actual: _):
                    XCTAssertEqual(expected, 3, "3 expected arguments")
                default:
                    XCTFail("Expected .incorrectArgumentCount error")
                }
            } else {
                XCTFail("Expected RuntimeError error")
            }
        }

        // print(interpretter.environment.stack)
        // print(interpretter.tickerTape)
        // base of 'clock'
        XCTAssertEqual(interpretter.environment.stack.count,1)
        // initial setup should only have the external 'clock' function defined
        XCTAssertNotNil(interpretter.environment.testGet("clock"))
        XCTAssertNotNil(interpretter.environment.testGet("add"))
        XCTAssertEqual(interpretter.environment.testCount(), 2)
        
        // collected print statements should be 0 at the start
        XCTAssertNotNil(interpretter.tickerTape)
        if let collectedOutput = interpretter.tickerTape {
            XCTAssertEqual(collectedOutput.count, 0)
            // print(collectedOutput)
        }
    }

    func testInterprettingCounterWithExplicitReturn() throws {
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
        let resolver = Resolver(interpretter)
        interpretter.omgIndent = 0
        interpretter.omgVerbose = true
        try resolver.resolve(statements)
        // print("Retrieved statements:")
        // for stmt in statements {
        //     print("  \(stmt)")
        // }
        try interpretter.interpretStatements(statements)
//        print("-----------------------------------------------------")
//        print(interpretter.environment.values)
//        print(interpretter.tickerTape as Any)

        // base of 'clock'
        // and added the function 'count' from the sample
        XCTAssertNotNil(interpretter.environment.testGet("clock"))
        XCTAssertNotNil(interpretter.environment.testGet("count"))
        XCTAssertEqual(interpretter.environment.testCount(), 2)

        
        // collected print statements should be 0 at the start
        XCTAssertNotNil(interpretter.tickerTape)
        if let collectedOutput = interpretter.tickerTape {
            XCTAssertEqual(collectedOutput.count, 2)
            // print(collectedOutput)
            XCTAssertEqual(collectedOutput[0], "1.0")
            XCTAssertEqual(collectedOutput[1], "2.0")
        }
    }

    func testFibonaciInterpretterExecution() throws {
        let tokenlist = Slox.Scanner(LOXSource.chap10_8.source).scanTokens()
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
        // print("Retrieved statements:")
        // for stmt in statements {
        //     print("  \(stmt)")
        // }
        let resolver = Resolver(interpretter)
        try resolver.resolve(statements)
        // interpretter.omgIndent = 0
        // interpretter.omgVerbose = true
        try interpretter.interpretStatements(statements)
        // print("-----------------------------------------------------")
        // print(interpretter.environment.values)
        // print(interpretter.tickerTape as Any)

        // base of 'clock'
        // and added the function 'count' from the sample
        XCTAssertNotNil(interpretter.environment.testGet("clock"))
        XCTAssertNotNil(interpretter.environment.testGet("fib"))
        XCTAssertEqual(interpretter.environment.testCount(), 2)

        // collected print statements should be 0 at the start
        XCTAssertNotNil(interpretter.tickerTape)
        if let collectedOutput = interpretter.tickerTape {
            XCTAssertEqual(collectedOutput.count, 20)
            // print(collectedOutput)
            XCTAssertEqual(collectedOutput,
                           ["0.0", "1.0", "1.0", "2.0", "3.0", "5.0",
                            "8.0", "13.0", "21.0", "34.0", "55.0",
                            "89.0", "144.0", "233.0", "377.0", "610.0",
                            "987.0", "1597.0", "2584.0", "4181.0"])
        }
    }
}
