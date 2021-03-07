//
//  LoxInterpretter.swift
//  Slox
//
//  Created by Joseph Heck on 3/7/21.
//

// Chapter 7: https://craftinginterpreters.com/evaluating-expressions.html

import Foundation

enum LoxRuntimeError: Error {
    case oops
}

public indirect enum RuntimeValue {
    case string(value: String)
    case number(value: Double)
    case boolean(value: Bool)
    case none
}

public protocol Interpretable {
    func evaluate() throws -> RuntimeValue
}

// AST enums: Expression, LiteralExpression, UnaryType, OperatorExpression
extension Expression: Interpretable {
    func evaluate() throws -> RuntimeValue {
        switch self {
        case let .literal(litexpr):
            return try litexpr.evaluate()
        case let .unary(unaryexpr, expr):
            switch unaryexpr {
            case .minus:
                let workingval = try expr.evaluate()
                switch workingval {
                case .boolean(_), .string(_), .none:
                    throw LoxRuntimeError.oops // not allowed to 'minus' these types
                case let .number(value):
                    return RuntimeValue.number(value: -value)
                }
            case .not:
                let workingval = try expr.evaluate()
                switch workingval {
                case .number(_), .string(_), .none:
                    throw LoxRuntimeError.oops // not allowed to 'minus' these types
                case let .boolean(value):
                    return RuntimeValue.boolean(value: !value)
                }
            }
        case let .binary(expr_l, expr_op, expr_r):
            print("uh...")
        // binary
        case let .grouping(expr):
            return try expr.evaluate()
        }
        throw LoxRuntimeError.oops
    }
}

extension LiteralExpression: Interpretable {
    func evaluate() throws -> RuntimeValue {
        switch self {
        case let .number(token):
            switch token.literal {
            case .none:
                throw LoxRuntimeError.oops
            case .string:
                throw LoxRuntimeError.oops
            case let .number(value: value):
                return RuntimeValue.number(value: value)
            }
        case let .string(token):
            switch token.literal {
            case .none:
                throw LoxRuntimeError.oops
            case let .string(value: value):
                return RuntimeValue.string(value: value)
            case .number:
                throw LoxRuntimeError.oops
            }
        case .trueToken:
            return RuntimeValue.boolean(value: true)
        case .falseToken:
            return RuntimeValue.boolean(value: false)
        case .nilToken:
            return RuntimeValue.none
        }
    }
}

extension UnaryExpression: Interpretable {
    func evaluate() throws -> RuntimeValue {
        // foo
        throw LoxRuntimeError.oops
    }
}

extension OperatorExpression: Interpretable {
    func evaluate() throws -> RuntimeValue {
        // foo
        throw LoxRuntimeError.oops
    }
}

class Interpretter {}
