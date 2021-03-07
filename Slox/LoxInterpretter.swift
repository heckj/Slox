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

/// The form of value that evaluating from a LoxInterpretter returns. The source material choose to
/// do this as dynamic typing, and leveraged Java's runtime casting to convert things around as need
/// be, but I'm applying some structure under the covers with this enumeration to hold the related values.
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
            let lefteval = try expr_l.evaluate()
            let righteval = try expr_r.evaluate()
            switch expr_op {
            case .Subtract:
                switch lefteval {
                case let .number(leftval):
                    switch righteval {
                    case let .number(rightval):
                        return RuntimeValue.number(value: leftval - rightval)
                    default:
                        throw LoxRuntimeError.oops // can't 'subtract' these types from others
                    }
                default:
                    throw LoxRuntimeError.oops // not allowed to 'subtract' these types
                }

            case .Multiply:
                switch lefteval {
                case let .number(leftval):
                    switch righteval {
                    case let .number(rightval):
                        return RuntimeValue.number(value: leftval * rightval)
                    default:
                        throw LoxRuntimeError.oops // can't 'subtract' these types from others
                    }
                default:
                    throw LoxRuntimeError.oops // not allowed to 'subtract' these types
                }

            case .Divide:
                switch lefteval {
                case let .number(leftval):
                    switch righteval {
                    case let .number(rightval):
                        return RuntimeValue.number(value: leftval / rightval)
                    default:
                        throw LoxRuntimeError.oops // can't 'subtract' these types from others
                    }
                default:
                    throw LoxRuntimeError.oops // not allowed to 'subtract' these types
                }

            case .Add:
                switch lefteval {
                // add the numbers
                case let .number(leftval):
                    switch righteval {
                    case let .number(rightval):
                        return RuntimeValue.number(value: leftval + rightval)
                    default:
                        throw LoxRuntimeError.oops // can't 'add' these types from others
                    }
                // concatenate the strings
                case let .string(leftval):
                    switch righteval {
                    case let .string(rightval):
                        return RuntimeValue.string(value: leftval + rightval)
                    default:
                        throw LoxRuntimeError.oops // can't 'add' these types from others
                    }
                default:
                    throw LoxRuntimeError.oops // not allowed to 'add' these types
                }

            case .LessThan:
                switch lefteval {
                // compare the numbers
                case let .number(leftval):
                    switch righteval {
                    case let .number(rightval):
                        return RuntimeValue.boolean(value: leftval < rightval)
                    default:
                        throw LoxRuntimeError.oops // can't compare these types from others
                    }
                // compare the strings
                case let .string(leftval):
                    switch righteval {
                    case let .string(rightval):
                        return RuntimeValue.boolean(value: leftval < rightval)
                    default:
                        throw LoxRuntimeError.oops // can't compare these types from others
                    }
                default:
                    throw LoxRuntimeError.oops // not allowed to compare these types
                }

            case .LessThanOrEqual:
                switch lefteval {
                // compare the numbers
                case let .number(leftval):
                    switch righteval {
                    case let .number(rightval):
                        return RuntimeValue.boolean(value: leftval <= rightval)
                    default:
                        throw LoxRuntimeError.oops // can't compare these types from others
                    }
                // compare the strings
                case let .string(leftval):
                    switch righteval {
                    case let .string(rightval):
                        return RuntimeValue.boolean(value: leftval <= rightval)
                    default:
                        throw LoxRuntimeError.oops // can't compare these types from others
                    }
                default:
                    throw LoxRuntimeError.oops // not allowed to compare these types
                }

            case .GreaterThan:
                switch lefteval {
                // compare the numbers
                case let .number(leftval):
                    switch righteval {
                    case let .number(rightval):
                        return RuntimeValue.boolean(value: leftval > rightval)
                    default:
                        throw LoxRuntimeError.oops // can't compare these types from others
                    }
                // compare the strings
                case let .string(leftval):
                    switch righteval {
                    case let .string(rightval):
                        return RuntimeValue.boolean(value: leftval > rightval)
                    default:
                        throw LoxRuntimeError.oops // can't compare these types from others
                    }
                default:
                    throw LoxRuntimeError.oops // not allowed to compare these types
                }

            case .GreaterThanOrEqual:
                switch lefteval {
                // compare the numbers
                case let .number(leftval):
                    switch righteval {
                    case let .number(rightval):
                        return RuntimeValue.boolean(value: leftval >= rightval)
                    default:
                        throw LoxRuntimeError.oops // can't compare these types from others
                    }
                // compare the strings
                case let .string(leftval):
                    switch righteval {
                    case let .string(rightval):
                        return RuntimeValue.boolean(value: leftval >= rightval)
                    default:
                        throw LoxRuntimeError.oops // can't compare these types from others
                    }
                default:
                    throw LoxRuntimeError.oops // not allowed to compare these types
                }

            case .Equals:
                switch lefteval {
                // compare the numbers
                case let .number(leftval):
                    switch righteval {
                    case let .number(rightval):
                        return RuntimeValue.boolean(value: leftval == rightval)
                    default:
                        throw LoxRuntimeError.oops // can't compare these types from others
                    }
                // compare the strings
                case let .string(leftval):
                    switch righteval {
                    case let .string(rightval):
                        return RuntimeValue.boolean(value: leftval == rightval)
                    default:
                        throw LoxRuntimeError.oops // can't compare these types from others
                    }
                // compare the bools
                case let .boolean(leftval):
                    switch righteval {
                    case let .boolean(rightval):
                        return RuntimeValue.boolean(value: leftval == rightval)
                    default:
                        throw LoxRuntimeError.oops // can't compare these types from others
                    }
                default:
                    throw LoxRuntimeError.oops // not allowed to compare these types
                }

            case .NotEquals:
                switch lefteval {
                // compare the numbers
                case let .number(leftval):
                    switch righteval {
                    case let .number(rightval):
                        return RuntimeValue.boolean(value: leftval != rightval)
                    default:
                        throw LoxRuntimeError.oops // can't compare these types from others
                    }
                // compare the strings
                case let .string(leftval):
                    switch righteval {
                    case let .string(rightval):
                        return RuntimeValue.boolean(value: leftval != rightval)
                    default:
                        throw LoxRuntimeError.oops // can't compare these types from others
                    }
                // compare the bools
                case let .boolean(leftval):
                    switch righteval {
                    case let .boolean(rightval):
                        return RuntimeValue.boolean(value: leftval != rightval)
                    default:
                        throw LoxRuntimeError.oops // can't compare these types from others
                    }
                default:
                    throw LoxRuntimeError.oops // not allowed to compare these types
                }
            }
        // binary
        case let .grouping(expr):
            return try expr.evaluate()
        }
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
