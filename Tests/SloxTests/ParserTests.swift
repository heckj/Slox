@testable import Slox
import XCTest

final class ParserTests: XCTestCase {
    let source = """
    var foo = 1;
    print foo;
    if (foo > 3) { print "many"; }
    // if (foo < 2);
    var pi = 3.14159;
    """

    func testParser() {
        let tokenlist = Scanner("1+2*3/4-5;").scanTokens()
        XCTAssertNotNil(tokenlist)
        XCTAssertEqual(tokenlist.count, 11)

        let parser = Parser(tokenlist)
        XCTAssertNotNil(parser)
        XCTAssertEqual(parser.current, 0)
        XCTAssertEqual(parser.tokens.count, 11)

        let statements = parser.parse()

        XCTAssertEqual(statements.count, 1)
        XCTAssertEqual(String(describing: statements[0]), "STMT<( ( 1.0 + ( ( 2.0 * 3.0 ) / 4.0 ) ) - 5.0 )>")
    }

    func testLargerParse() {
        let tokenlist = Scanner(source).scanTokens()
        XCTAssertNotNil(tokenlist)
        XCTAssertEqual(tokenlist.count, 25)

        let parser = Parser(tokenlist)
        XCTAssertNotNil(parser)
        XCTAssertEqual(parser.current, 0)
        XCTAssertEqual(parser.tokens.count, 25)

        let statements = parser.parse()
        XCTAssertEqual(parser.current, 24)
        XCTAssertEqual(parser.tokens.count, 25)
//        print(parser.tokens)

        XCTAssertEqual(statements.count, 4)
        XCTAssertEqual(String(describing: statements[0]), "VAR(IDENTIFIER[foo]):(1.0)")
        XCTAssertEqual(String(describing: statements[1]), "PRINT(var(foo))")
        XCTAssertEqual(String(describing: statements[2]), "IF(( var(foo) > 3.0 )) THEN {{ [PRINT(\"many\")] }} ELSE {nil}")
        XCTAssertEqual(String(describing: statements[3]), "VAR(IDENTIFIER[pi]):(3.14159)")
    }

    func testParsingLogicalComparison() throws {
    
        // THE ISSUE IS CASE SENSITIVITY TO KEYWORDS
        let snippetOfPain = """
        if ((foo > 3) and (bar == 5)) {
            print "many";
        }
        """
        let tokenlist = Slox.Scanner(snippetOfPain).scanTokens()
        let parser = Parser(tokenlist)
//        parser.omgVerbose = true
//        print("Source:")
//        print("  \(snippetOfPain)")
//        var indention = 1
//        for token in tokenlist {
//            print(String(repeating: " ", count: indention), terminator: "")
//            print("| \(token) |")
//            indention+=1
//        }
        let statements = parser.parse()
        XCTAssertEqual(tokenlist.count, 20, "expected 20 tokens, found \(tokenlist.count) tokens")
        XCTAssertEqual(statements.count, 1, "expected 1 statement, found \(statements.count)")
        XCTAssertEqual(parser.errors.count, 0)
        if (parser.errors.count != 0) {
            parser.printErrors()
        }
        print("Retrieved statements:")
        for stmt in statements {
            print("  \(stmt)")
        }
        
    }
    
    func testParsingExamples() throws {
        for sourceExample in LOXSource.allExamples {
            let tokenlist = Slox.Scanner(sourceExample.source).scanTokens()
            let parser = Parser(tokenlist)
            let statements = parser.parse()
            XCTAssertEqual(tokenlist.count, sourceExample.tokens, "source expected \(sourceExample.tokens) tokens, found \(tokenlist.count) tokens")
            XCTAssertEqual(statements.count, sourceExample.statements, "expected \(sourceExample.statements) statements, found \(statements.count) in the source:\n\(sourceExample.source)")
            XCTAssertEqual(parser.errors.count, sourceExample.errors, "unexpected parse error received:\n\(parser.errors)")
            if (parser.errors.count != 0) && (sourceExample.errors != parser.errors.count) {
                parser.printErrors()
            }
            if statements.count != sourceExample.statements {
                // if there's an issue - show me the generated statements that would
                // otherwise be run through the interpretter
                for stmt in statements {
                    print("  \(stmt)")
                }
            }
        }
    }
}
