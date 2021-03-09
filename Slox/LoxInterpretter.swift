//
//  LoxInterpretter.swift
//  Slox
//
//  Created by Joseph Heck on 3/7/21.
//

// Chapter 7: https://craftinginterpreters.com/evaluating-expressions.html

import Foundation

public enum LoxRuntimeError: Error {
    case notImplemented
    case oops(_ token: Token) // TODO: - remove this catch-all and replace with useful runtime errors
}

/// The form of value that evaluating from a LoxInterpretter returns. The source material choose to
/// do this as dynamic typing, and leveraged Java's runtime casting to convert things around as need
/// be, but I'm applying some structure under the covers with this enumeration to hold the related values.
public indirect enum RuntimeValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .none:
            return "None"
        case let .string(value: value):
            return value
        case let .number(value: value):
            return String(value)
        case let .boolean(value: value):
            return String(value)
        }
    }

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
    public func evaluate() throws -> RuntimeValue {
        switch self {
        case let .literal(litexpr):
            return try litexpr.evaluate()
        case let .unary(unaryexpr, expr):
            switch unaryexpr {
            case let .minus(token):
                let workingval = try expr.evaluate()
                switch workingval {
                case .boolean(_), .string(_), .none:
                    throw LoxRuntimeError.oops(token) // not allowed to 'minus' these types
                case let .number(value):
                    return RuntimeValue.number(value: -value)
                }
            case let .not(token):
                let workingval = try expr.evaluate()
                switch workingval {
                case .number(_), .string(_), .none:
                    throw LoxRuntimeError.oops(token) // not allowed to 'minus' these types
                case let .boolean(value):
                    return RuntimeValue.boolean(value: !value)
                }
            }
        case let .binary(expr_l, expr_op, expr_r):
            let lefteval = try expr_l.evaluate()
            let righteval = try expr_r.evaluate()
            switch expr_op {
            case let .Subtract(token):
                switch lefteval {
                case let .number(leftval):
                    switch righteval {
                    case let .number(rightval):
                        return RuntimeValue.number(value: leftval - rightval)
                    default:
                        throw LoxRuntimeError.oops(token) // can't 'subtract' these types from others
                    }
                default:
                    throw LoxRuntimeError.oops(token) // not allowed to 'subtract' these types
                }

            case let .Multiply(token):
                switch lefteval {
                case let .number(leftval):
                    switch righteval {
                    case let .number(rightval):
                        return RuntimeValue.number(value: leftval * rightval)
                    default:
                        throw LoxRuntimeError.oops(token) // can't 'subtract' these types from others
                    }
                default:
                    throw LoxRuntimeError.oops(token) // not allowed to 'subtract' these types
                }

            case let .Divide(token):
                switch lefteval {
                case let .number(leftval):
                    switch righteval {
                    case let .number(rightval):
                        return RuntimeValue.number(value: leftval / rightval)
                    default:
                        throw LoxRuntimeError.oops(token) // can't 'subtract' these types from others
                    }
                default:
                    throw LoxRuntimeError.oops(token) // not allowed to 'subtract' these types
                }

            case let .Add(token):
                switch lefteval {
                // add the numbers
                case let .number(leftval):
                    switch righteval {
                    case let .number(rightval):
                        return RuntimeValue.number(value: leftval + rightval)
                    default:
                        throw LoxRuntimeError.oops(token) // can't 'add' these types from others
                    }
                // concatenate the strings
                case let .string(leftval):
                    switch righteval {
                    case let .string(rightval):
                        return RuntimeValue.string(value: leftval + rightval)
                    default:
                        throw LoxRuntimeError.oops(token) // can't 'add' these types from others
                    }
                default:
                    throw LoxRuntimeError.oops(token) // not allowed to 'add' these types
                }

            case let .LessThan(token):
                switch lefteval {
                // compare the numbers
                case let .number(leftval):
                    switch righteval {
                    case let .number(rightval):
                        return RuntimeValue.boolean(value: leftval < rightval)
                    default:
                        throw LoxRuntimeError.oops(token) // can't compare these types from others
                    }
                // compare the strings
                case let .string(leftval):
                    switch righteval {
                    case let .string(rightval):
                        return RuntimeValue.boolean(value: leftval < rightval)
                    default:
                        throw LoxRuntimeError.oops(token) // can't compare these types from others
                    }
                default:
                    throw LoxRuntimeError.oops(token) // not allowed to compare these types
                }

            case let .LessThanOrEqual(token):
                switch lefteval {
                // compare the numbers
                case let .number(leftval):
                    switch righteval {
                    case let .number(rightval):
                        return RuntimeValue.boolean(value: leftval <= rightval)
                    default:
                        throw LoxRuntimeError.oops(token) // can't compare these types from others
                    }
                // compare the strings
                case let .string(leftval):
                    switch righteval {
                    case let .string(rightval):
                        return RuntimeValue.boolean(value: leftval <= rightval)
                    default:
                        throw LoxRuntimeError.oops(token) // can't compare these types from others
                    }
                default:
                    throw LoxRuntimeError.oops(token) // not allowed to compare these types
                }

            case let .GreaterThan(token):
                switch lefteval {
                // compare the numbers
                case let .number(leftval):
                    switch righteval {
                    case let .number(rightval):
                        return RuntimeValue.boolean(value: leftval > rightval)
                    default:
                        throw LoxRuntimeError.oops(token) // can't compare these types from others
                    }
                // compare the strings
                case let .string(leftval):
                    switch righteval {
                    case let .string(rightval):
                        return RuntimeValue.boolean(value: leftval > rightval)
                    default:
                        throw LoxRuntimeError.oops(token) // can't compare these types from others
                    }
                default:
                    throw LoxRuntimeError.oops(token) // not allowed to compare these types
                }

            case let .GreaterThanOrEqual(token):
                switch lefteval {
                // compare the numbers
                case let .number(leftval):
                    switch righteval {
                    case let .number(rightval):
                        return RuntimeValue.boolean(value: leftval >= rightval)
                    default:
                        throw LoxRuntimeError.oops(token) // can't compare these types from others
                    }
                // compare the strings
                case let .string(leftval):
                    switch righteval {
                    case let .string(rightval):
                        return RuntimeValue.boolean(value: leftval >= rightval)
                    default:
                        throw LoxRuntimeError.oops(token) // can't compare these types from others
                    }
                default:
                    throw LoxRuntimeError.oops(token) // not allowed to compare these types
                }

            case let .Equals(token):
                switch lefteval {
                // compare the numbers
                case let .number(leftval):
                    switch righteval {
                    case let .number(rightval):
                        return RuntimeValue.boolean(value: leftval == rightval)
                    default:
                        throw LoxRuntimeError.oops(token) // can't compare these types from others
                    }
                // compare the strings
                case let .string(leftval):
                    switch righteval {
                    case let .string(rightval):
                        return RuntimeValue.boolean(value: leftval == rightval)
                    default:
                        throw LoxRuntimeError.oops(token) // can't compare these types from others
                    }
                // compare the bools
                case let .boolean(leftval):
                    switch righteval {
                    case let .boolean(rightval):
                        return RuntimeValue.boolean(value: leftval == rightval)
                    default:
                        throw LoxRuntimeError.oops(token) // can't compare these types from others
                    }
                default:
                    throw LoxRuntimeError.oops(token) // not allowed to compare these types
                }

            case let .NotEquals(token):
                switch lefteval {
                // compare the numbers
                case let .number(leftval):
                    switch righteval {
                    case let .number(rightval):
                        return RuntimeValue.boolean(value: leftval != rightval)
                    default:
                        throw LoxRuntimeError.oops(token) // can't compare these types from others
                    }
                // compare the strings
                case let .string(leftval):
                    switch righteval {
                    case let .string(rightval):
                        return RuntimeValue.boolean(value: leftval != rightval)
                    default:
                        throw LoxRuntimeError.oops(token) // can't compare these types from others
                    }
                // compare the bools
                case let .boolean(leftval):
                    switch righteval {
                    case let .boolean(rightval):
                        return RuntimeValue.boolean(value: leftval != rightval)
                    default:
                        throw LoxRuntimeError.oops(token) // can't compare these types from others
                    }
                default:
                    throw LoxRuntimeError.oops(token) // not allowed to compare these types
                }
            }
        // binary
        case let .grouping(expr):
            return try expr.evaluate()
        }
    }
}

extension LiteralExpression: Interpretable {
    public func evaluate() throws -> RuntimeValue {
        switch self {
        case let .number(token):
            switch token.literal {
            case .none:
                throw LoxRuntimeError.oops(token)
            case .string:
                throw LoxRuntimeError.oops(token)
            case let .number(value: value):
                return RuntimeValue.number(value: value)
            }
        case let .string(token):
            switch token.literal {
            case .none:
                throw LoxRuntimeError.oops(token)
            case let .string(value: value):
                return RuntimeValue.string(value: value)
            case .number:
                throw LoxRuntimeError.oops(token)
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
    public func evaluate() throws -> RuntimeValue {
        // foo
        throw LoxRuntimeError.notImplemented
    }
}

extension OperatorExpression: Interpretable {
    public func evaluate() throws -> RuntimeValue {
        // foo
        throw LoxRuntimeError.notImplemented
    }
}

public protocol RuntimeEvaluation {
    func execute() throws
}

extension Statement: RuntimeEvaluation {
    public func execute() throws {
        switch self {
        case let .printStatement(expr):
            let result = try expr.evaluate() // _ is a RuntimeValue
            print(result)

        case let .expressionStatement(expr):
            _ = try expr.evaluate()
        }
    }
}

public class Interpretter {
    public func interpretStatements(_ statements: [Statement]) {
        do {
            for statement in statements {
                try statement.execute()
            }
        } catch LoxRuntimeError.notImplemented {
            Lox.runtimeError(LoxRuntimeError.notImplemented)
        } catch let LoxRuntimeError.oops(token) {
            Lox.runtimeError(LoxRuntimeError.oops(token))
        } catch {
            Lox.runtimeError(LoxRuntimeError.notImplemented) // unknown error actually
        }
    }

//    public func interpretResult(expr: Expression) -> Result<RuntimeValue, LoxRuntimeError> {
//        do {
//            let result = try expr.evaluate()
//            return .success(result)
//        } catch LoxRuntimeError.notImplemented {
//            return .failure(LoxRuntimeError.notImplemented)
//        } catch let LoxRuntimeError.oops(token) {
//            return .failure(LoxRuntimeError.oops(token))
//        } catch {
//            return .failure(LoxRuntimeError.notImplemented) // unknown error actually
//        }
//    }
}
