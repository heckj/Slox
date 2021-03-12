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

 Updated grammar, identifiers, Chapter 8

 primary        → "true" | "false" | "nil"
                | NUMBER | STRING
                | "(" expression ")"
                | IDENTIFIER ;
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
    //                   | "(" expression ")" | IDENTIFIER;
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
        if match(TokenType.IDENTIFIER) {
            return Expression.variable(previous())
        }
        if match(TokenType.LEFT_PAREN) {
            let expr = try expression()
            _ = try consume(TokenType.RIGHT_PAREN, message: "Expect ')' after expression.")
            return Expression.grouping(expr)
        }
        throw error(peek(), message: "Expect expression.")
    }

    private func statement() throws -> Statement {
        if match(.PRINT) {
            return try printStatement()
        }
        return try expressionStatement()
    }

    private func declaration() throws -> Statement? {
        do {
            if match(.VAR) {
                return try variableDeclaration()
            }
            return try statement()
        } catch {
            // expected one of ParserError
            synchronize()
            return nil
        }
    }

    private func variableDeclaration() throws -> Statement {
        let variableToken: Token = try consume(.IDENTIFIER, message: "Expect variable name.")
        var initializer: Expression?
        if match(.EQUAL) {
            initializer = try expression()
        }
        guard let anInitializer = initializer else {
            throw ParserError.unparsableExpression(tokens[current])
        }
        _ = try consume(.SEMICOLON, message: "Expect ';' after variable declaration.")
        return Statement.variable(variableToken, anInitializer)
    }

    private func printStatement() throws -> Statement {
        let value: Expression = try expression()
        _ = try consume(.SEMICOLON, message: "Expect ';' after value.")
        return Statement.printStatement(value)
    }

    private func expressionStatement() throws -> Statement {
        let value: Expression = try expression()
        _ = try consume(.SEMICOLON, message: "Expect ';' after value.")
        return Statement.expressionStatement(value)
    }

    // feh: Error handling in Swift:
    // https://docs.swift.org/swift-book/LanguageGuide/ErrorHandling.html
    func parse() -> [Statement] {
        var statements: [Statement] = []
        do {
            while !isAtEnd() {
                if let dec = try declaration() {
                    statements.append(dec)
                }
            }

        } catch ParserError.syntaxError(_, _) {
            return statements // maybe bad idea - error handling w/ statements?
        } catch {
            return statements // maybe bad idea
        }
        return statements
    }

    // helper functions for the parser
    // - moving around the list of tokens and checking them

    private func consume(_ type: TokenType, message: String) throws -> Token {
        if check(type) {
            return advance()
        }
        throw ParserError.syntaxError(peek(), message: message)
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

    private func error(_ token: Token, message: String) -> ParserError {
        Lox.error(token.line, message: message)
        return ParserError.syntaxError(token, message: message)
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
