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

/*
 //  expression     → equality ;
 indirect enum Expression: CustomStringConvertible {
     var description: String {
         switch self {
         case let .exp(exp):
             return "equality \(exp)"
         }
     }

     case exp(EqualityExpression)
 }

 // equality       → comparison ( ( "!=" | "==" ) comparison )* ;
 indirect enum EqualityExpression: CustomStringConvertible {
     var description: String {
         switch self {
         case let .equal(comparison_l, comparison_r):
             return "\(comparison_l)==\(comparison_r)"
         case let .notEqual(comparison_l, comparison_r):
             return "\(comparison_l)!=\(comparison_r)"
         }
     }

     case equal(ComparisonExpression, /* implied token ==, */ ComparisonExpression)
     case notEqual(ComparisonExpression, /* implied token !=, */ ComparisonExpression)
 }

 // comparison     → term ( ( ">" | ">=" | "<" | "<=" ) term )* ;
 indirect enum ComparisonExpression: CustomStringConvertible {
     var description: String {
         switch self {
         case let .lessThan(term_l, term_r):
             return "\(term_l)<\(term_r)"
         case let .lessThanOrEqual(term_l, term_r):
             return "\(term_l)<=\(term_r)"
         case let .greaterThan(term_l, term_r):
             return "\(term_l)>\(term_r)"
         case let .greaterThanOrEqual(term_l, term_r):
             return "\(term_l)>=\(term_r)"
         }
     }

     case lessThan(TermExpression, /* implied token <, */ TermExpression)
     case lessThanOrEqual(TermExpression, /* implied token <=, */ TermExpression)
     case greaterThan(TermExpression, /* implied token >, */ TermExpression)
     case greaterThanOrEqual(TermExpression, /* implied token >=, */ TermExpression)
 }

 // term           → factor ( ( "-" | "+" ) factor )* ;
 indirect enum TermExpression: CustomStringConvertible {
     var description: String {
         switch self {
         case let .plus(factor_l, factor_r):
             return "\(factor_l) + \(factor_r)"
         case let .minus(factor_l, factor_r):
             return "\(factor_l) - \(factor_r)"
         }
     }

     case plus(FactorExpression, /* implied token +, */ FactorExpression)
     case minus(FactorExpression, /* implied token -, */ FactorExpression)
 }

 // factor         → unary ( ( "/" | "*" ) unary )* ;
 indirect enum FactorExpression: CustomStringConvertible {
     var description: String {
         switch self {
         case let .multiply(unary_l, unary_r):
             return "\(unary_l) * \(unary_r)"
         case let .divide(unary_l, unary_r):
             return "\(unary_l) / \(unary_r)"
         }
     }

     case multiply(UnaryExpression, /* implied token *, */ UnaryExpression)
     case divide(UnaryExpression, /* implied token /, */ UnaryExpression)
 }

 // unary          → ( "!" | "-" ) unary
 //                | primary ;
 indirect enum UnaryExpression: CustomStringConvertible {
     var description: String {
         switch self {
         case let .not(unary):
             return "!\(unary)"
         case let .minus(unary):
             return "-\(unary)"
         case let .primary(primary):
             return "\(primary)"
         }
     }

     case not(UnaryExpression)
     case minus(UnaryExpression)
     case primary(PrimaryExpression)
 }

 // primary        → NUMBER | STRING | "true" | "false" | "nil"
 //                | "(" expression ")" ;
 indirect enum PrimaryExpression: CustomStringConvertible {
     var description: String {
         switch self {
         case let .number(value):
             return "\(value.lexeme)"
         case let .string(value):
             return "\(value.lexeme)"
         case .trueToken:
             return "true"
         case .falseToken:
             return "false"
         case .nilToken:
             return "nil"
         case let .expression(exp):
             return "\(exp)"
         }
     }

     case number(Token) // double rather than token?
     case string(Token) // string rather than token?
     case trueToken
     case falseToken
     case nilToken
     case expression(Expression)
 }
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
            return try Expression.unary(UnaryType.fromToken(op), right)
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
        throw GrammarError.syntaxError(previous(), message: "No idea WTF just happened")
    }

//    private Token consume(TokenType type, String message) {
//        if (check(type)) return advance();
//
//        throw error(peek(), message);
//      }
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
}
