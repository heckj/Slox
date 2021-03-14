//
//  LoxAST.swift
//  Slox
//
//  Created by Joseph Heck on 3/6/21.
//

import Foundation

// source material translated from Java in https://craftinginterpreters.com/representing-code.html
// grammar syntax for statements: https://craftinginterpreters.com/statements-and-state.html

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
            return "var(\(tok.lexeme))"
        case let .assign(tok, exp):
            return "\(tok.lexeme) = \(exp)"
        }
    }

    case literal(Literal)
    case unary(Unary, Expression)
    case binary(Expression, Operator, Expression)
    case grouping(Expression)
    case variable(Token)
    case assign(Token, Expression)
}

public indirect enum Literal: CustomStringConvertible {
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

public indirect enum Unary: CustomStringConvertible {
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

    static func fromToken(_ t: Token) throws -> Unary {
        switch t.type {
        case .MINUS:
            return Unary.minus(t)
        case .BANG:
            return Unary.not(t)
        default:
            Lox.error(0, message: "Invalid operator token")
            throw ParserError.invalidUnaryToken(t)
        }
    }
}

public indirect enum Operator: CustomStringConvertible {
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

    static func fromToken(_ t: Token) throws -> Operator {
        switch t.type {
        case .EQUAL: return Operator.Equals(t)
        case .MINUS:
            return Operator.Subtract(t)
        case .PLUS:
            return Operator.Add(t)
        case .SLASH:
            return Operator.Divide(t)
        case .STAR:
            return Operator.Multiply(t)
        case .BANG_EQUAL:
            return Operator.NotEquals(t)
        case .EQUAL_EQUAL:
            return Operator.Equals(t)
        case .GREATER:
            return Operator.GreaterThan(t)
        case .GREATER_EQUAL:
            return Operator.GreaterThanOrEqual(t)
        case .LESS:
            return Operator.LessThan(t)
        case .LESS_EQUAL:
            return Operator.LessThanOrEqual(t)
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
