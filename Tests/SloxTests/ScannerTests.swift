@testable import Slox
import XCTest

final class ScannerTests: XCTestCase {
    func verifyTokens(_ actual: [Token], types: [TokenType]) {
        XCTAssertEqual(actual.count, types.count)
        for (a, b) in zip(actual, types) {
            XCTAssertEqual(a.type, b)
        }
    }

    func testTokenizing() throws {
        let tokens = Slox.Scanner("1+2*3/4-5;").scanTokens()
        XCTAssertEqual(tokens.count, 11)
        let expected: [TokenType] = [
            .NUMBER, .PLUS, .NUMBER, .STAR, .NUMBER,
            .SLASH, .NUMBER, .MINUS, .NUMBER, .SEMICOLON,
            .EOF,
        ]
        verifyTokens(tokens, types: expected)
    }

    func testTokenizingIdentifier() throws {
        let tokens = Slox.Scanner("var a = \"one\";").scanTokens()
        XCTAssertEqual(tokens.count, 6)
        let expected: [TokenType] = [
            .VAR, .IDENTIFIER, .EQUAL, .STRING, .SEMICOLON,
            .EOF,
        ]
        verifyTokens(tokens, types: expected)
        print("description \(tokens[3].description)")
        
        print("lexeme \(tokens[3].lexeme)")
        XCTAssertEqual(tokens[3].lexeme, "\"one\"")
        
        print("line \(tokens[3].line)")
        XCTAssertEqual(tokens[3].line, 1)
        
        print("type \(tokens[3].type)")
        XCTAssertEqual(tokens[3].type, TokenType.STRING)
        
        print("literal \(tokens[3].literal)")
        XCTAssertEqual(tokens[3].literal, LiteralType.string(value: "\"one\""))
    }

    func testTokenizingMultiline() throws {
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
            .EOF,
        ]
        verifyTokens(tokens, types: expected)
    }

    func testTokenizingExamples() throws {
        for sourceExample in LOXSource.allExamples {
            let tokenlist = Slox.Scanner(sourceExample.source).scanTokens()
            XCTAssertEqual(tokenlist.count, sourceExample.tokens, "source expected \(sourceExample.tokens), found \(tokenlist.count) tokens")
        }
    }
}
