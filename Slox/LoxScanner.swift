//
//  LoxScanner.swift
//  Slox
//
//  Created by Joseph Heck on 3/6/21.
//

import Foundation

// source material translated from Java in https://craftinginterpreters.com/scanning.html

extension Character {
    var isIdentifier: Bool {
        return isLetter || self == "_"
    }
}

let reservedWords: [String: TokenType] = ["and": TokenType.AND,
                                          "class": TokenType.CLASS,
                                          "else": TokenType.ELSE,
                                          "false": TokenType.FALSE,
                                          "for": TokenType.FOR,
                                          "fun": TokenType.FUN,
                                          "if": TokenType.IF,
                                          "nil": TokenType.NIL,
                                          "or": TokenType.OR,
                                          "print": TokenType.PRINT,
                                          "return": TokenType.RETURN,
                                          "super": TokenType.SUPER,
                                          "this": TokenType.THIS,
                                          "true": TokenType.TRUE,
                                          "var": TokenType.VAR,
                                          "while": TokenType.WHILE]

final class Scanner {
    var source: String
    var tokens: [Token] = []

    private var start: String.Index
    private var current: String.Index
    private var line: Int = 1

    init(_ source: String) {
        self.source = source
        start = source.startIndex
        current = start
    }

    func scanTokens() -> [Token] {
        while !isAtEnd() {
            start = current
            scanToken()
        }

        tokens.append(Token(type: .EOF, lexeme: "", line: line))
        return tokens
    }

    private func isAtEnd() -> Bool {
        return current >= source.endIndex
    }

    private func advance() -> Character {
        let nextIndexPosition = source.index(after: current)
        current = nextIndexPosition
        let char: Character = source[current]
        return char
    }

    private func peek() -> Character {
        // single character "look ahead" function
        if isAtEnd() {
            return "\0" // unicode NUL character
        }
        return source[current]
    }

    private func peekNext() -> Character {
        // double character "look ahead" function
        let nextIndex: String.Index = source.index(after: current)
        if isAtEnd() || (nextIndex >= source.endIndex) {
            return "\0" // unicode NUL character
        }
        return source[nextIndex]
    }

    private func string() {
        // increment the cursor to find the bounds of the string
        while peek() != "\"", !isAtEnd() {
            if peek() == "\n" { line += 1 }
            _ = advance()
        }
        if isAtEnd() {
            Lox.error(line, message: "Unterminated string.")
            return
        }

        // The closing " character
        _ = advance()
        let value = source[source.index(after: start) ... source.index(before: current)]
        addToken(TokenType.STRING, literal: String(value))
    }

    private func number() {
        // increment the cursor to find the bounds of the number
        while peek().isNumber {
            _ = advance()
        }
        if (peek() == ".") && peekNext().isNumber {
            // Consume the '.'
            _ = advance()
            while peek().isNumber {
                _ = advance()
            }
        }
        guard let value = Double(source[start ... current]) else {
            Lox.error(line, message: "Unexpected error parsing a number from \(source[start ... current]).")
            return
        }
        addToken(TokenType.NUMBER, literal: value)
    }

    private func identifier() {
        // increment the cursor to find the bounds of the identifier
        while peek().isIdentifier {
            _ = advance()
        }
        let text = source[start ... current]
        if let type = reservedWords[String(text)] {
            addToken(type)
        }
        addToken(.IDENTIFIER)
    }

    private func scanToken() {
        let char: Character = advance()
        switch char {
        case "(": addToken(.LEFT_PAREN)
        case ")": addToken(.RIGHT_PAREN)
        case "{": addToken(.LEFT_BRACE)
        case "}": addToken(.RIGHT_BRACE)
        case ",": addToken(.COMMA)
        case ".": addToken(.DOT)
        case "-": addToken(.MINUS)
        case "+": addToken(.PLUS)
        case ";": addToken(.SEMICOLON)
        case "*": addToken(.STAR)
        case "!": addToken(match("=") ? .BANG_EQUAL : .BANG)
        case "=": addToken(match("=") ? .EQUAL_EQUAL : .EQUAL)
        case "<": addToken(match("=") ? .LESS_EQUAL : .LESS)
        case ">": addToken(match("=") ? .GREATER_EQUAL : .GREATER)
        case "/": if match("/") {
                // represents a comment - ignored content until the end of the line
                while (!peek().isNewline) && !isAtEnd() {
                    _ = advance()
                }
            } else {
                addToken(.SLASH)
            }
        case " ", "\r", "\t": break
        case "\n": line += 1
        case "\"": string()
        default:
            if char.isNumber {
                number()
            } else if char.isLetter {
                identifier()
            } else {
                Lox.error(line, message: "Unexpected character.")
            }
        }
    }

    private func addToken(_ type: TokenType) {
        let text = source[start ... current]
        tokens.append(Token(type: type, lexeme: String(text), line: line))
    }

    private func addToken(_ type: TokenType, literal: String) {
        let text = source[start ... current]
        tokens.append(Token(type: type, lexeme: String(text), literal: literal, line: line))
    }

    private func addToken(_ type: TokenType, literal: Double) {
        let text = source[start ... current]
        tokens.append(Token(type: type, lexeme: String(text), literal: literal, line: line))
    }

    private func match(_ expected: Character) -> Bool {
        if isAtEnd() {
            return false
        }
        if source[current] != expected { return false }
        // it matches, so advance the index position
        current = source.index(after: current)
        return true
    }
}
