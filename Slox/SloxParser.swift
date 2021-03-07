//
//  SloxParser.swift
//  Slox
//
//  Created by Joseph Heck on 3/6/21.
//

// Chapter 6: https://craftinginterpreters.com/parsing-expressions.html

import Foundation

/*
 Original grammar, chapter 5:

  expression     → literal
                 | unary
                 | binary
                 | grouping ;

  literal        → NUMBER | STRING | "true" | "false" | "nil" ;
  grouping       → "(" expression ")" ;
  unary          → ( "-" | "!" ) expression ;
  binary         → expression operator expression ;
  operator       → "==" | "!=" | "<" | "<=" | ">" | ">="
                 | "+"  | "-"  | "*" | "/" ;

 Updated grammar, incorporating precedence, Chapter 6

  expression     → equality ;
  equality       → comparison ( ( "!=" | "==" ) comparison )* ;
  comparison     → term ( ( ">" | ">=" | "<" | "<=" ) term )* ;
  term           → factor ( ( "-" | "+" ) factor )* ;
  factor         → unary ( ( "/" | "*" ) unary )* ;
  unary          → ( "!" | "-" ) unary
                 | primary ;
  primary        → NUMBER | STRING | "true" | "false" | "nil"
                 | "(" expression ")" ;

  */

class Parser {
    var tokens: [Token] = []
    var current: Int = 0

    init(_ tokens: [Token]) {
        self.tokens = tokens
    }

    //    expression     → equality ;
    private func expression() throws -> Expression {
        return try equality()
    }

    //    equality       → comparison ( ( "!=" | "==" ) comparison )* ;
    private func equality() throws -> Expression {
        var expr: Expression = try comparison()

        while match(TokenType.BANG_EQUAL, TokenType.EQUAL_EQUAL) {
            let op: Token = previous()
            let right: Expression = try comparison()
            expr = try Expression.binary(expr, OperatorExpression.fromToken(op), right)
        }
        return expr
    }

    //    comparison     → term ( ( ">" | ">=" | "<" | "<=" ) term )* ;
    private func comparison() throws -> Expression {
        var expr: Expression = try term()
        while match(TokenType.GREATER, TokenType.GREATER_EQUAL, TokenType.LESS, TokenType.LESS_EQUAL) {
            let op: Token = previous()
            let right: Expression = try term()
            expr = try Expression.binary(expr, OperatorExpression.fromToken(op), right)
        }
        return expr
    }

    //    term           → factor ( ( "-" | "+" ) factor )* ;
    private func term() throws -> Expression {
        var expr: Expression = try factor()
        while match(TokenType.MINUS, TokenType.PLUS) {
            let op: Token = previous()
            let right: Expression = try factor()
            expr = try Expression.binary(expr, OperatorExpression.fromToken(op), right)
        }
        return expr
    }

    //    factor         → unary ( ( "/" | "*" ) unary )* ;
    private func factor() throws -> Expression {
        var expr: Expression = try unary()
        while match(TokenType.SLASH, TokenType.STAR) {
            let op: Token = previous()
            let right: Expression = try unary()
            expr = try Expression.binary(expr, OperatorExpression.fromToken(op), right)
        }
        return expr
    }

    //    unary          → ( "!" | "-" ) unary
    //                   | primary ;
    private func unary() throws -> Expression {
        if match(TokenType.BANG, TokenType.MINUS) {
            let op: Token = previous()
            let right: Expression = try unary()
            return try Expression.unary(UnaryExpression.fromToken(op), right)
        }
        return try primary()
    }

    //    primary        → NUMBER | STRING | "true" | "false" | "nil"
    //                   | "(" expression ")" ;
    private func primary() throws -> Expression {
        if match(TokenType.FALSE) {
            return Expression.literal(.falseToken(previous()))
        }
        if match(TokenType.TRUE) {
            return Expression.literal(.trueToken(previous()))
        }
        if match(TokenType.NIL) {
            return Expression.literal(.nilToken(previous()))
        }
        if match(TokenType.STRING) {
            return Expression.literal(.string(previous()))
        }
        if match(TokenType.NUMBER) {
            return Expression.literal(.number(previous()))
        }
        if match(TokenType.LEFT_PAREN) {
            let expr = try expression()
            try consume(TokenType.RIGHT_PAREN, message: "Expect ')' after expression.")
            return Expression.grouping(expr)
        }
        throw error(peek(), message: "Expect expression.")
    }

    // feh: Error handling in Swift:
    // https://docs.swift.org/swift-book/LanguageGuide/ErrorHandling.html
    func parse() -> Expression? {
        do {
            let attempt = try expression()
            return attempt
        } catch GrammarError.syntaxError(_, _) {
            return nil
        } catch {
            return nil
        }
    }

    // helper functions for the parser
    // - moving around the list of tokens and checking them

    private func consume(_ type: TokenType, message: String) throws {
        if check(type) {
            _ = advance()
            return
        }
        throw GrammarError.syntaxError(peek(), message: message)
    }

    private func advance() -> Token {
        if !isAtEnd() {
            current += 1
        }
        return previous()
    }

    private func check(_ type: TokenType) -> Bool {
        if isAtEnd() {
            return false
        }
        return (peek().type == type)
    }

    private func isAtEnd() -> Bool {
        return peek().type == TokenType.EOF
    }

    private func peek() -> Token {
        return tokens[current]
    }

    private func previous() -> Token {
        return tokens[current - 1]
    }

    private func match(_ token: TokenType...) -> Bool {
        for type in token {
            if check(type) {
                _ = advance()
                return true
            }
        }
        return false
    }

    // ParseError and Syntax Issue handling

    private func error(_ token: Token, message: String) -> GrammarError {
        Lox.error(token.line, message: message)
        return GrammarError.syntaxError(token, message: message)
    }

    private func synchronize() {
        _ = advance()

        while !isAtEnd() {
            if previous().type == TokenType.SEMICOLON {
                return
            }
            switch peek().type {
            case .CLASS, .FUN, .VAR, .FOR, .IF, .WHILE, .PRINT, .RETURN:
                return
            default:
                _ = advance()
            }
        }
    }

    static func error(_ token: Token, message: String) {
        if token.type == TokenType.EOF {
            Lox.report(line: token.line, example: " at end ", message: message)
        } else {
            Lox.report(line: token.line, example: " at '" + token.lexeme + "'", message: message)
        }
    }
}
