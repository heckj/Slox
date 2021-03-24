@testable import Slox
import XCTest

final class ParserTests: XCTestCase {
    let source = """
var foo = 1;
print foo;
if (foo > 3) { print "many" };
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
        XCTAssertEqual(String(describing: statements[0]), "STMT<( - ( + 1.0 ( / ( * 2.0 3.0 ) 4.0 ) ) 5.0 )>")
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
        print(parser.tokens)

        XCTAssertEqual(statements.count, 2)
        XCTAssertEqual(String(describing: statements[0]), "VAR(IDENTIFIER foo):(1.0)")
        XCTAssertEqual(String(describing: statements[1]), "PRINT(var(foo))")
    }
}
