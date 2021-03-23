@testable import Slox
import XCTest


final class ScannerTests: XCTestCase {
    func verifyTokens(_ actual: [Token], types: [TokenType]) {
        XCTAssertEqual(actual.count, types.count)
        for (a, b) in zip(actual, types) {
            XCTAssertEqual(a.type, b)
        }
    }
    func testTokenizing() {
        let tokens = Slox.Scanner("1+2*3/4-5;").scanTokens()
        XCTAssertEqual(tokens.count, 11)
        let expected: [TokenType] = [
            .NUMBER, .PLUS, .NUMBER, .STAR, .NUMBER,
            .SLASH, .NUMBER, .MINUS, .NUMBER, .SEMICOLON,
            .EOF
        ]
        verifyTokens(tokens, types: expected)
    }

    func testTokenizingMultiline() {
        let source = """
var foo = 1;
print foo;
if (foo > 3) { print "many" };
// if (foo < 2);
var pi = 3.14159;
"""
        let tokens = Slox.Scanner(source).scanTokens()
        XCTAssertEqual(tokens.count, 25)
        let expected: [TokenType] = [
            .VAR, .IDENTIFIER, .EQUAL, .NUMBER, .SEMICOLON,
            .PRINT, .IDENTIFIER, .SEMICOLON,
            .IF, .LEFT_PAREN, .IDENTIFIER, .GREATER, .NUMBER, .RIGHT_PAREN,
                .LEFT_BRACE, .PRINT, .STRING, .RIGHT_BRACE, .SEMICOLON,
            // comment here
            .VAR, .IDENTIFIER, .EQUAL, .NUMBER, .SEMICOLON,
            .EOF
        ]
        verifyTokens(tokens, types: expected)
    }

}
