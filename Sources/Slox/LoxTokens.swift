//
//  LoxTokens.swift
//  Slox
//
//  Created by Joseph Heck on 3/6/21.
//

import Foundation

// source material translated from Java in https://craftinginterpreters.com/scanning.html

public enum TokenType {
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

public indirect enum LiteralType {
    // The rough equivalent of a Union for swift - a literal is one of these kinds of things,
    // but I didn't want to store each option in the Token class directly, nor make the Token class
    // into an enumeration itself.
    case string(value: String)
    case number(value: Double)
    case none
}

public final class Token: CustomStringConvertible {
    let type: TokenType
    let lexeme: String
    let literal: LiteralType
    let line: Int
    public var description: String {
        switch literal {
        case let .number(value):
            return "\(type) \(lexeme) \(value)"
        case let .string(value):
            return "\(type) \(lexeme) \(value)"
        case .none:
            return "\(type) \(lexeme)"
        }
    }

    init(type: TokenType, lexeme: String, literal: String, line: Int) {
        self.type = type
        self.lexeme = lexeme
        self.literal = LiteralType.string(value: literal)
        self.line = line
    }

    init(type: TokenType, lexeme: String, literal: Double, line: Int) {
        self.type = type
        self.lexeme = lexeme
        self.literal = LiteralType.number(value: literal)
        self.line = line
    }

    init(type: TokenType, lexeme: String, line: Int) {
        self.type = type
        self.lexeme = lexeme
        literal = LiteralType.none
        self.line = line
    }
}
