//
//  SloxParser.swift
//  Slox
//
//  Created by Joseph Heck on 3/6/21.
//

// Chapter 6: https://craftinginterpreters.com/parsing-expressions.html
// Chapter 7: https://craftinginterpreters.com/evaluating-expressions.html
// Chapter 8: https://craftinginterpreters.com/statements-and-state.html
// Chapter 9: https://craftinginterpreters.com/control-flow.html
// Chapter 10: https://craftinginterpreters.com/functions.html

import Foundation

enum ParserError: Error {
    case invalidOperatorToken(Token)
    case invalidUnaryToken(Token)
    case syntaxError(Token, message: String)
    case unparsableExpression(Token)
}

struct ErrorInfo: CustomStringConvertible {
    let error: Error
    let position: Int
    let syncPosition: Int
    let count: Int

    var description: String {
        return "Error \(error) at token \(position) of \(count), recovered at \(syncPosition)."
    }
}

//enum ANSIColors: String, CaseIterable {
//    case black = "\u{001B}[0;30m"
//    case red = "\u{001B}[0;31m"
//    case green = "\u{001B}[0;32m"
//    case yellow = "\u{001B}[0;33m"
//    case blue = "\u{001B}[0;34m"
//    case magenta = "\u{001B}[0;35m"
//    case cyan = "\u{001B}[0;36m"
//    case white = "\u{001B}[0;37m"
//    case reset = "\u{001B}[0;0m"
//
//    func name() -> String {
//        switch self {
//        case .black: return "Black"
//        case .red: return "Red"
//        case .green: return "Green"
//        case .yellow: return "Yellow"
//        case .blue: return "Blue"
//        case .magenta: return "Magenta"
//        case .cyan: return "Cyan"
//        case .white: return "White"
//        case .reset: return "_default_"
//        }
//    }
//}

class Parser {
    var tokens: [Token] = []
    var current: Int = 0

    var errors: [ErrorInfo] = []
    var omgVerbose = false
    var omgIndent: Int = 0;

    private func indent() {
        for _ in 0...omgIndent {
            print(" ", terminator: "")
        }
    }

    init(_ tokens: [Token]) {
        self.tokens = tokens
    }

    private func expression() throws -> Expression {
        if omgVerbose { indent(); print( "expression()"); omgIndent+=1 }
        return try assignment()
    }

    private func assignment() throws -> Expression {
        if omgVerbose { indent(); print( "assignment()"); omgIndent+=1 }
        let expr = try or()

        if match(.EQUAL) {
            let equals = previous()
            let value = try assignment()

            switch expr {
            case let .variable(token):
                return Expression.assign(token, value)
            default:
                throw ParserError.syntaxError(equals, message: "Invalid Assignment Target")
            }
        }
        return expr
    }

    private func or() throws -> Expression {
        if omgVerbose { indent(); print( "or()"); omgIndent+=1 }
        var expr = try and()

        while match(.OR) {
            let op: Token = previous()
            let right: Expression = try and()
            expr = try Expression.logical(expr, LogicalOperator.fromToken(op), right)
        }
        return expr
    }

    private func and() throws -> Expression {
        if omgVerbose { indent(); print( "and()"); omgIndent+=1 }

        var expr = try equality()

        while match(.AND) {
            let op: Token = previous()
            let right: Expression = try equality()
            expr = try Expression.logical(expr, LogicalOperator.fromToken(op), right)
        }
        return expr
    }

    private func equality() throws -> Expression {
        if omgVerbose { indent(); print( "equality()"); omgIndent+=1 }
        var expr: Expression = try comparison()

        while match(TokenType.BANG_EQUAL, TokenType.EQUAL_EQUAL) {
            let op: Token = previous()
            let right: Expression = try comparison()
            expr = try Expression.binary(expr, Operator.fromToken(op), right)
        }
        return expr
    }

    private func comparison() throws -> Expression {
        if omgVerbose { indent(); print( "comparison()"); omgIndent+=1 }
        var expr: Expression = try term()
        while match(TokenType.GREATER, TokenType.GREATER_EQUAL, TokenType.LESS, TokenType.LESS_EQUAL) {
            let op: Token = previous()
            let right: Expression = try term()
            expr = try Expression.binary(expr, Operator.fromToken(op), right)
        }
        return expr
    }

    private func term() throws -> Expression {
        if omgVerbose { indent(); print( "term()"); omgIndent+=1 }
        var expr: Expression = try factor()
        while match(TokenType.MINUS, TokenType.PLUS) {
            let op: Token = previous()
            let right: Expression = try factor()
            expr = try Expression.binary(expr, Operator.fromToken(op), right)
        }
        return expr
    }

    private func factor() throws -> Expression {
        if omgVerbose { indent(); print( "factor()"); omgIndent+=1 }
        var expr: Expression = try unary()
        while match(TokenType.SLASH, TokenType.STAR) {
            let op: Token = previous()
            let right: Expression = try unary()
            expr = try Expression.binary(expr, Operator.fromToken(op), right)
        }
        return expr
    }

    private func unary() throws -> Expression {
        if omgVerbose { indent(); print( "unary()"); omgIndent+=1 }
        if match(TokenType.BANG, TokenType.MINUS) {
            let op: Token = previous()
            let right: Expression = try unary()
            return try Expression.unary(Unary.fromToken(op), right)
        }
        return try call()
    }

    private func call() throws -> Expression {
        if omgVerbose { indent(); print( "call()"); omgIndent+=1 }
        var expr = try primary()

        while true {
            if match(.LEFT_PAREN) {
                expr = try finishCall(expr)
            } else {
                break
            }
        }
        return expr
    }

    private func finishCall(_ callee: Expression) throws -> Expression {
        if omgVerbose { indent(); print( "finishCall()"); omgIndent+=1 }
        guard case .variable(let _) = callee else {
            struct Failure: Error {}
            throw Failure()
        }

        var arguments: [Expression] = []

        if !check(.RIGHT_PAREN) {
            repeat {
                arguments.append(try expression())
            } while match(.COMMA)

            if arguments.count >= 255 {
                throw error(peek(), message: "Can't have more than 255 arguments.")
            }
        }
        let paren = try consume(.RIGHT_PAREN, message: "Expect ')' after arguments.")
        return Expression.call(callee, paren, arguments)
    }

    private func primary() throws -> Expression {
        if omgVerbose { indent(); print( "primary()"); omgIndent+=1 }
        if match(TokenType.FALSE) {
            if omgVerbose { indent(); print( "Expression.literal"); omgIndent=0 }
            return Expression.literal(.falseToken)
        }
        if match(TokenType.TRUE) {
            if omgVerbose { indent(); print( "Expression.literal"); omgIndent=0 }
            return Expression.literal(.trueToken)
        }
        if match(TokenType.NIL) {
            if omgVerbose { indent(); print( "Expression.literal"); omgIndent=0 }
            return Expression.literal(.nilToken)
        }
        if match(TokenType.STRING) {
            switch previous().literal {
            case let .string(value: stringValue):
                if omgVerbose { indent(); print( "Expression.literal"); omgIndent=0 }
                return Expression.literal(.string(stringValue))
            default:
                throw error(previous(), message: "Token doesn't match expected String literal type")
            }
        }
        if match(TokenType.NUMBER) {
            switch previous().literal {
            case let .number(value: doubleValue):
                if omgVerbose { indent(); print( "Expression.literal"); omgIndent=0 }
                return Expression.literal(.number(doubleValue))
            default:
                throw error(previous(), message: "Token doesn't match expected Double literal type")
            }
        }
        if match(TokenType.IDENTIFIER) {
            if omgVerbose { indent(); print( "Expression.variable"); omgIndent=0 }
            return Expression.variable(previous())
        }
        if match(TokenType.LEFT_PAREN) {
            let expr = try expression()
            try consume(TokenType.RIGHT_PAREN, message: "Expect ')' after expression.")
            if omgVerbose { indent(); print( "Expression.grouping"); omgIndent=0 }
            return Expression.grouping(expr)
        }
        if omgVerbose { indent(); print( "NO MORE PRIMARY TOKENS - Error"); omgIndent=0 }
        throw error(peek(), message: "Expect expression.")
    }

    // MARK: STATEMENTS and DECLARATIONS

    private func declaration() throws -> Statement? {
        if omgVerbose { indent(); print( "declaration()"); omgIndent+=1 }
        do {
            if match(.VAR) {
                return try variableDeclaration()
            }
            if match(.FUN) {
                return try functionDeclaration("function")
            }
            return try statement()
        } catch {
            if omgVerbose { indent(); print( "RECORDING ERROR"); omgIndent=0 }
            let errorPosition = current
            synchronize()
            self.errors.append(ErrorInfo(error: error, position: errorPosition, syncPosition: current, count: tokens.count))
            return nil
        }
    }

    private func statement() throws -> Statement {
        if omgVerbose { indent(); print( "statement()"); omgIndent+=1 }
        if match(.FOR) {
            return try forStatement()
        }
        if match(.IF) {
            return try ifStatement()
        }
        if match(.PRINT) {
            return try printStatement()
        }
        if match(.WHILE) {
            return try whileStatement()
        }
        if match(.LEFT_BRACE) {
            return try Statement.block(block())
        }

        return try expressionStatement()
    }

    private func variableDeclaration() throws -> Statement {
        if omgVerbose { indent(); print( "variableDeclaration()"); omgIndent+=1 }

        let variableToken: Token = try consume(.IDENTIFIER, message: "Expect variable name.")
        let initializer: Expression

        if match(.EQUAL) {
            initializer = try expression()
        } else {
            throw ParserError.unparsableExpression(tokens[current])
        }

        try consume(.SEMICOLON, message: "Expect ';' after variable declaration.")
        if omgVerbose { indent(); print( "Statement.variable"); omgIndent=0 }
        return Statement.variable(variableToken, initializer)
    }

    private func functionDeclaration(_ kind: String) throws -> Statement {
        if omgVerbose { indent(); print( "functionDeclaration()"); omgIndent+=1 }
        let name = try consume(.IDENTIFIER, message: "Expect \(kind) name.")
        try consume(.LEFT_PAREN, message: "Expect '(' after \(kind) name.")
        var parameters: [Token] = []
        if !check(.RIGHT_PAREN) {
            while match(.COMMA) {
                if parameters.count >= 255 {
                    throw error(peek(), message: "Can't have more than 255 parameters.")
                }
                parameters.append(try consume(.IDENTIFIER, message: "Expect parameter name"))
            }
        }
        try consume(.RIGHT_PAREN, message: "Expect ')' after parameters.")

        try consume(.LEFT_BRACE, message: "Expect '{' before \(kind) body.")
        let body = try block()
        if omgVerbose { indent(); print( "Statement.function"); omgIndent=0 }
        return Statement.function(name, parameters, body)
    }

    private func printStatement() throws -> Statement {
        if omgVerbose { indent(); print( "functionDeclaration()"); omgIndent+=1 }
        let value: Expression = try expression()
        try consume(.SEMICOLON, message: "Expect ';' after value.")
        if omgVerbose { indent(); print( "Statement.printStatement"); omgIndent=0 }
        return Statement.printStatement(value)
    }

    private func expressionStatement() throws -> Statement {
        if omgVerbose { indent(); print( "expressionStatement()"); omgIndent+=1 }
        let value: Expression = try expression()
        try consume(.SEMICOLON, message: "Expect ';' after value.")
        if omgVerbose { indent(); print( "Statement.expressionStatement"); omgIndent=0 }
        return Statement.expressionStatement(value)
    }

    private func block() throws -> [Statement] {
        if omgVerbose { indent(); print( "block()"); omgIndent+=1 }
        var statements: [Statement] = []
        while !check(.RIGHT_BRACE), !isAtEnd() {
            if let nextstatement = try declaration() {
                statements.append(nextstatement)
            }
        }
        try consume(.RIGHT_BRACE, message: "Expect '}' after block.")
        if omgVerbose { indent(); print( "[Statement]"); omgIndent=0 }
        return statements
    }

    private func ifStatement() throws -> Statement {
        if omgVerbose { indent(); print( "ifStatement()"); omgIndent+=1 }
        try consume(.LEFT_PAREN, message: "Expect '(' after 'if'.")
        let condition = try expression()
        try consume(.RIGHT_PAREN, message: "Expect ')' after if condition.")

        let thenBranch = try statement()
        var elseBranch: Statement?
        if match(.ELSE) {
            elseBranch = try statement()
        }
        if omgVerbose { indent(); print( "Statement.ifStatement"); omgIndent=0 }
        return Statement.ifStatement(condition, thenBranch, elseBranch)
    }

    private func whileStatement() throws -> Statement {
        if omgVerbose { indent(); print( "whileStatement()"); omgIndent+=1 }
        try consume(.LEFT_PAREN, message: "Expect '(' after 'while'.")
        let condition = try expression()
        try consume(.RIGHT_PAREN, message: "Expect ')' after condition.")
        let body = try statement()
        if omgVerbose { indent(); print( "Statement.ifStatement"); omgIndent=0 }
        return Statement.whileStatement(condition, body)
    }

    private func forStatement() throws -> Statement {
        if omgVerbose { indent(); print( "forStatement()"); omgIndent+=1 }
        try consume(.LEFT_PAREN, message: "Expect '(' after 'for    '.")
        let initializer: Statement?
        if match(.SEMICOLON) {
            initializer = nil
        } else if match(.VAR) {
            initializer = try variableDeclaration()
        } else {
            initializer = try expressionStatement()
        }

        let condition: Expression
        if check(.SEMICOLON) {
            condition = try expression()
        } else {
            condition = Expression.literal(.trueToken)
        }
        try consume(.SEMICOLON, message: "Expect ';' after loop condition.")

        let increment: Expression?
        if check(.RIGHT_PAREN) {
            increment = try expression()
        } else {
            increment = nil
        }
        try consume(.RIGHT_PAREN, message: "Expect ')' after for clauses.")
        var body = try statement()

        // Add the increment to the end of the body
        if let increment = increment {
            body = .block([body, Statement.expressionStatement(increment)])
        }
        // Add the condition
        body = .whileStatement(condition, body)
        // Prepend the initializer to before the while loop
        if let initializer = initializer {
            body = .block([initializer, body])
        }
        if omgVerbose { indent(); print( "desugared FOR statement"); omgIndent=0 }
        return body
    }

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

    @discardableResult
    private func consume(_ type: TokenType, message: String) throws -> Token {
        if check(type) {
            return advance()
        }
        throw ParserError.syntaxError(peek(), message: message)
    }

    @discardableResult
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
                advance()
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
        advance()

        while !isAtEnd() {
            if previous().type == TokenType.SEMICOLON {
                return
            }
            switch peek().type {
            case .CLASS, .FUN, .VAR, .FOR, .IF, .WHILE, .PRINT, .RETURN:
                return
            default:
                advance()
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
