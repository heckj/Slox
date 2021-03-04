//
//  Lox.swift
//  Slox
//
//  Created by Joseph Heck on 3/2/21.
//

import Darwin
import Foundation

final class Token: CustomStringConvertible {
    let type: TokenType
    let lexeme: String
    let literal: String // AnyObject?
    let line: Int
    var description: String {
        return "\(type) \(lexeme) \(literal)"
    }

    init(type: TokenType, lexeme: String, literal: String, line: Int) {
        self.type = type
        self.lexeme = lexeme
        self.literal = literal
        self.line = line
    }

    enum TokenType {
        // single-character tokens
        case LEFT_PAREN, RIGHT_PAREN
        case LEFT_BRACE, RIGHT_BRACE
        case COMMA
        case DOT
        case MINUS
        case PLUS
        case SEMICOLON
        case SLASH
        case STAR

        // one or two-character tokens
        case BANG, BANG_EQUAL
        case EQUAL, EQUAL_EQUAL
        case GREATER, GREATER_EQUAL
        case LESS, LESS_EQUAL

        // Literals
        case IDENTIFIER, STRING, NUMBER

        // Keywords
        case AND, CLASS, ELSE, FALSE, FUN, FOR, IF, NIL
        case OR, PRINT, RETURN, SUPER, THIS, TRUE, VAR, WHILE

        case EOF
    }
}

final class Scanner {
    var source: String
    var tokens: [Token] = []

    private var start: Int = 0
    private var current: Int = 0
    private var line: Int = 1

    init(_ source: String) {
        self.source = source
    }

    func scanTokens() -> [Token] {
        while !isAtEnd() {
            start = current
            scanToken()
        }

        tokens.append(Token(type: .EOF, lexeme: "", literal: "", line: line))
        return tokens
    }
    
    private func isAtEnd() -> Bool {
        return current >= source.count
    }
}

public enum Lox {
    static var hadError: Bool = false
    public static func main(args: [String]) throws {
        if args.count > 1 {
            print("Usage: slox [script]")
            exit(64)
        } else if args.count == 1 {
            try runFile(args[0])
        } else {
            try runPrompt()
        }
    }

    // translated through https://craftinginterpreters.com/scanning.html#token-type

    static func runFile(_ path: String) throws {
//        byte[] bytes = Files.readAllBytes(Paths.get(path));
//        run(new String(bytes, Charset.defaultCharset()));
        let contents = try String(contentsOfFile: path, encoding: .utf8)
        run(contents)
        if hadError {
            exit(65)
        }
    }

    static func runPrompt() throws {
//        InputStreamReader input = new InputStreamReader(System.in);
//        BufferedReader reader = new BufferedReader(input);
//
//        for (;;) {
//          System.out.print("> ");
//          String line = reader.readLine();
//          if (line == null) break;
//          run(line);
//        }
        while true {
            print("> ", terminator: "")
            if let interactiveString = readLine(strippingNewline: true) {
                run(interactiveString)
                hadError = false
            }
        }
    }

    static func run(_ source: String) {
//        List<Token> tokens = scanner.scanTokens();
//
//        // For now, just print the tokens.
//        for (Token token : tokens) {
//          System.out.println(token);
//        }
        let tokenlist = source.components(separatedBy: .whitespacesAndNewlines)
        for token in tokenlist {
            print(token)
        }
    }

    public static func error(_ line: Int, message: String) {
        report(line: line, example: "", message: message)
    }

    static func report(line: Int, example: String, message: String) {
        print("[\(line)] Error \(example): \(message)")
        hadError = true
    }
}
