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
        current = source.startIndex
    }

    func scanTokens() -> [Token] {
        while !isAtEnd() {
            // move the 'start' index cursor forward to our current location when starting a token scan
            start = current
            // then get on with it, and find the next token
            scanToken()
        }

        tokens.append(Token(type: .EOF, lexeme: "", line: line))
        return tokens
    }

    private func isAtEnd() -> Bool {
        return current >= source.endIndex
    }

    private func advance() -> Character {
        // if we're at the end of the string, return a NUL character and return
        // without advancing the index forward
        if isAtEnd() {
            // and don't try to read the current character
            return "\0" // unicode NUL character
        }
        // get the character at the current position BEFORE advancing the cursor
        let char = source[current]
        // step forward one index position
        current = source.index(after: current)
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
        if isAtEnd() {
            return "\0" // unicode NUL character
        }
        let nextIndex: String.Index = source.index(after: current)
        if nextIndex >= source.endIndex {
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
        guard let value = Double(source[start ... source.index(before: current)]) else {
            Lox.error(line, message: "Unexpected error parsing a number from \(source[start ... source.index(before: current)]).")
            return
        }
        addToken(TokenType.NUMBER, literal: value)
    }

    private func identifier() {
        // increment the cursor to find the bounds of the identifier
        while peek().isIdentifier {
            _ = advance()
        }
        let text = source[start ... source.index(before: current)]
        if let type = reservedWords[String(text)] {
            addToken(type)
        } else {
            addToken(.IDENTIFIER)
        }
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
        let text = source[start ... source.index(before: current)]
        tokens.append(Token(type: type, lexeme: String(text), line: line))
    }

    private func addToken(_ type: TokenType, literal: String) {
        let text = source[start ... source.index(before: current)]
        tokens.append(Token(type: type, lexeme: String(text), literal: literal, line: line))
    }

    private func addToken(_ type: TokenType, literal: Double) {
        let text = source[start ... source.index(before: current)]
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
