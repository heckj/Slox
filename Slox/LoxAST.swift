//
//  LoxAST.swift
//  Slox
//
//  Created by Joseph Heck on 3/6/21.
//

import Foundation

// source material translated from Java in https://craftinginterpreters.com/representing-code.html
// grammar syntax for statements: https://craftinginterpreters.com/statements-and-state.html

/*
 LOX grammar
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

 program        → declaration* EOF ;

 declaration    → varDecl
                | statement ;

 statement      → exprStmt
                | printStmt ;

 exprStmt       → expression ";" ;
 printStmt      → "print" expression ";" ;
 varDecl        → "var" IDENTIFIER ( "=" expression )? ";" ;

 */

// public indirect enum Program {
//
// }
public indirect enum Statement {
    case expressionStatement(Expression)
    case printStatement(Expression)
    case variable(Token, Expression)
}

enum ParserError: Error {
    case invalidOperatorToken(Token)
    case invalidUnaryToken(Token)
    case syntaxError(Token, message: String)
    case unparsableExpression(Token)
}

public indirect enum Expression: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .literal(exp):
            return "\(exp)"
        case let .unary(unaryexp, exp):
            return "( \(unaryexp) \(exp) )"
        case let .binary(lhs, op, rhs):
            return "( \(op) \(lhs) \(rhs) )"
        case let .grouping(exp):
            return "(group \(exp))"
        case let .variable(tok):
            return "\(tok.lexeme)"
        }
    }

    case literal(LiteralExpression)
    case unary(UnaryExpression, Expression)
    case binary(Expression, OperatorExpression, Expression)
    case grouping(Expression)
    case variable(Token)
}

public indirect enum LiteralExpression: CustomStringConvertible {
    public var description: String {
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
        }
    }

    case number(Token) // double rather than token?
    case string(Token) // string rather than token?
    case trueToken(Token)
    case falseToken(Token)
    case nilToken(Token)
}

public indirect enum UnaryExpression: CustomStringConvertible {
    public var description: String {
        switch self {
        case .minus:
            return "-"
        case .not:
            return "!"
        }
    }

    case minus(Token)
    case not(Token)

    static func fromToken(_ t: Token) throws -> UnaryExpression {
        switch t.type {
        case .MINUS:
            return UnaryExpression.minus(t)
        case .BANG:
            return UnaryExpression.not(t)
        default:
            Lox.error(0, message: "Invalid operator token")
            throw ParserError.invalidUnaryToken(t)
        }
    }
}

public indirect enum OperatorExpression: CustomStringConvertible {
    public var description: String {
        switch self {
        case .Equals:
            return "="
        case .NotEquals:
            return "!="
        case .LessThan:
            return "<"
        case .LessThanOrEqual:
            return "<="
        case .GreaterThan:
            return ">"
        case .GreaterThanOrEqual:
            return ">="
        case .Add:
            return "+"
        case .Subtract:
            return "-"
        case .Multiply:
            return "*"
        case .Divide:
            return "/"
        }
    }

    case Equals(Token)
    case NotEquals(Token)
    case LessThan(Token)
    case LessThanOrEqual(Token)
    case GreaterThan(Token)
    case GreaterThanOrEqual(Token)
    case Add(Token)
    case Subtract(Token)
    case Multiply(Token)
    case Divide(Token)

    static func fromToken(_ t: Token) throws -> OperatorExpression {
        switch t.type {
        case .EQUAL: return OperatorExpression.Equals(t)
        case .MINUS:
            return OperatorExpression.Subtract(t)
        case .PLUS:
            return OperatorExpression.Add(t)
        case .SLASH:
            return OperatorExpression.Divide(t)
        case .STAR:
            return OperatorExpression.Multiply(t)
        case .BANG_EQUAL:
            return OperatorExpression.NotEquals(t)
        case .EQUAL_EQUAL:
            return OperatorExpression.Equals(t)
        case .GREATER:
            return OperatorExpression.GreaterThan(t)
        case .GREATER_EQUAL:
            return OperatorExpression.GreaterThanOrEqual(t)
        case .LESS:
            return OperatorExpression.LessThan(t)
        case .LESS_EQUAL:
            return OperatorExpression.LessThanOrEqual(t)
        default:
            Lox.error(0, message: "Invalid operator token")
            throw ParserError.invalidOperatorToken(t)
        }
    }
}

// translated example code, with every AST node having a copy of the token that generated it...
// The more direct example allowed for a Token to be inserted for Operator from the Java code,
// but it's not clear how the underlying data in the AST is used, so I'm hesitant to separate that.
// Otherwise, I think a lot of the tokens could be horribly redundant, and you end up mapping tokens
// into an AST that just includes them.

let expression = Expression.binary(
    Expression.unary(
        .minus(Token(type: .MINUS, lexeme: "-", literal: "-", line: 1)),
        Expression.literal(.number(Token(type: .NUMBER, lexeme: "123", literal: 123, line: 1)))
    ),
    .Multiply(Token(type: .STAR, lexeme: "*", line: 1)),
    Expression.grouping(
        Expression.literal(
            .number(
                Token(type: .NUMBER, lexeme: "45.67", literal: 45.67, line: 1)
            )
        )
    )
)

// prints: ( * ( - NUMBER 123 123.0 ) (group NUMBER 45.67 45.67) )
// ( * ( - 123 ) (group 45.67) ) // using just the lexeme in the token
