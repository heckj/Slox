@testable import Slox
import XCTest

final class IntepretterTests: XCTestCase {
    func testTokenizing() {
        let tokens = Slox.Scanner("1+2*3/4-5;").scanTokens()
        XCTAssertEqual(tokens.count, 11)
        XCTAssertEqual(tokens[0].type, TokenType.NUMBER)
        XCTAssertEqual(tokens[1].type, TokenType.PLUS)
        XCTAssertEqual(tokens[2].type, TokenType.NUMBER)
        XCTAssertEqual(tokens[3].type, TokenType.STAR)
        XCTAssertEqual(tokens[4].type, TokenType.NUMBER)
        XCTAssertEqual(tokens[5].type, TokenType.SLASH)
        XCTAssertEqual(tokens[6].type, TokenType.NUMBER)
        XCTAssertEqual(tokens[7].type, TokenType.MINUS)
        XCTAssertEqual(tokens[8].type, TokenType.NUMBER)
        XCTAssertEqual(tokens[9].type, TokenType.SEMICOLON)
        XCTAssertEqual(tokens[10].type, TokenType.EOF)
    }
}
