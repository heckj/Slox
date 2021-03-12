//
//  LoxInterpretter.swift
//  Slox
//
//  Created by Joseph Heck on 3/7/21.
//

// Chapter 7: https://craftinginterpreters.com/evaluating-expressions.html
// pending: https://craftinginterpreters.com/statements-and-state.html#global-variables

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
    func evaluate() -> Result<RuntimeValue, LoxRuntimeError>
    // NOTE(heckj): Okay - so I get it working, but holy crap that was a pain
    // in butt. It would be SO much easier if Result acted like a classic Promise
    // instead of forcing the switch to evaluate the result. It's seriously not
    // meant for chaining, so in the resulting implementation here is an
    // indention-from-hell scenario.
    // async/await MIGHT make this better, but really it begs for a promise-style
    // library rather than the fundamental Result type. A couple of places, the
    // binary and unary expressions specifically, I want to evaluate 2 or 3 promises
    // in parallel and jump ship to a propagating a failure if any of them fail.
}

// AST enums: Expression, LiteralExpression, UnaryExpression, OperatorExpression
extension Expression: Interpretable {
    public func evaluate() -> Result<RuntimeValue, LoxRuntimeError> {
        switch self {
        case let .literal(litexpr):
            return litexpr.evaluate()
        case let .unary(unaryexpr, expr):
            var val: RuntimeValue?

            switch expr.evaluate() {
            case let .success(workingval):
                val = workingval
            case let .failure(err):
                return .failure(err)
            }
            guard let runtimeValue = val else {
                return .failure(LoxRuntimeError.notImplemented)
            }

            switch unaryexpr {
            case let .minus(token):
                switch runtimeValue {
                case .boolean(_), .string(_), .none:
                    return .failure(LoxRuntimeError.oops(token)) // not allowed to 'minus' these types
                case let .number(value):
                    return .success(RuntimeValue.number(value: -value))
                }
            case let .not(token):
                switch runtimeValue {
                case .number(_), .string(_), .none:
                    return .failure(LoxRuntimeError.oops(token)) // not allowed to 'minus' these types
                case let .boolean(value):
                    return .success(RuntimeValue.boolean(value: !value))
                }
            }
        case let .binary(expr_l, expr_op, expr_r):
            var leftRuntimeValue: RuntimeValue?
            var rightRuntimeValue: RuntimeValue?
            // check left and right result, if either failed - propagate it
            switch expr_l.evaluate() {
            case let .success(leftval):
                leftRuntimeValue = leftval
            case let .failure(err):
                return .failure(err)
            }

            switch expr_r.evaluate() {
            case let .failure(err):
                return .failure(err)
            case let .success(righteval):
                rightRuntimeValue = righteval
            }

            switch expr_op {
            case let .Subtract(token):
                switch leftRuntimeValue {
                case let .number(leftval):
                    switch rightRuntimeValue {
                    case let .number(rightval):
                        return .success(RuntimeValue.number(value: leftval - rightval))
                    default:
                        return .failure(LoxRuntimeError.oops(token)) // can't 'subtract' these types from others
                    }
                default:
                    return .failure(LoxRuntimeError.oops(token)) // not allowed to 'subtract' these types
                }

            case let .Multiply(token):
                switch leftRuntimeValue {
                case let .number(leftval):
                    switch rightRuntimeValue {
                    case let .number(rightval):
                        return .success(RuntimeValue.number(value: leftval * rightval))
                    default:
                        return .failure(LoxRuntimeError.oops(token)) // can't 'subtract' these types from others
                    }
                default:
                    return .failure(LoxRuntimeError.oops(token)) // not allowed to 'subtract' these types
                }

            case let .Divide(token):
                switch leftRuntimeValue {
                case let .number(leftval):
                    switch rightRuntimeValue {
                    case let .number(rightval):
                        return .success(RuntimeValue.number(value: leftval / rightval))
                    default:
                        return .failure(LoxRuntimeError.oops(token)) // can't 'subtract' these types from others
                    }
                default:
                    return .failure(LoxRuntimeError.oops(token)) // not allowed to 'subtract' these types
                }

            case let .Add(token):
                switch leftRuntimeValue {
                // add the numbers
                case let .number(leftval):
                    switch rightRuntimeValue {
                    case let .number(rightval):
                        return .success(RuntimeValue.number(value: leftval + rightval))
                    default:
                        return .failure(LoxRuntimeError.oops(token)) // can't 'add' these types from others
                    }
                // concatenate the strings
                case let .string(leftval):
                    switch rightRuntimeValue {
                    case let .string(rightval):
                        return .success(RuntimeValue.string(value: leftval + rightval))
                    default:
                        return .failure(LoxRuntimeError.oops(token)) // can't 'add' these types from others
                    }
                default:
                    return .failure(LoxRuntimeError.oops(token)) // not allowed to 'add' these types
                }

            case let .LessThan(token):
                switch leftRuntimeValue {
                // compare the numbers
                case let .number(leftval):
                    switch rightRuntimeValue {
                    case let .number(rightval):
                        return .success(RuntimeValue.boolean(value: leftval < rightval))
                    default:
                        return .failure(LoxRuntimeError.oops(token)) // can't compare these types from others
                    }
                // compare the strings
                case let .string(leftval):
                    switch rightRuntimeValue {
                    case let .string(rightval):
                        return .success(RuntimeValue.boolean(value: leftval < rightval))
                    default:
                        return .failure(LoxRuntimeError.oops(token)) // can't compare these types from others
                    }
                default:
                    return .failure(LoxRuntimeError.oops(token)) // not allowed to compare these types
                }

            case let .LessThanOrEqual(token):
                switch leftRuntimeValue {
                // compare the numbers
                case let .number(leftval):
                    switch rightRuntimeValue {
                    case let .number(rightval):
                        return .success(RuntimeValue.boolean(value: leftval <= rightval))
                    default:
                        return .failure(LoxRuntimeError.oops(token)) // can't compare these types from others
                    }
                // compare the strings
                case let .string(leftval):
                    switch rightRuntimeValue {
                    case let .string(rightval):
                        return .success(RuntimeValue.boolean(value: leftval <= rightval))
                    default:
                        return .failure(LoxRuntimeError.oops(token)) // can't compare these types from others
                    }
                default:
                    return .failure(LoxRuntimeError.oops(token)) // not allowed to compare these types
                }

            case let .GreaterThan(token):
                switch leftRuntimeValue {
                // compare the numbers
                case let .number(leftval):
                    switch rightRuntimeValue {
                    case let .number(rightval):
                        return .success(RuntimeValue.boolean(value: leftval > rightval))
                    default:
                        return .failure(LoxRuntimeError.oops(token)) // can't compare these types from others
                    }
                // compare the strings
                case let .string(leftval):
                    switch rightRuntimeValue {
                    case let .string(rightval):
                        return .success(RuntimeValue.boolean(value: leftval > rightval))
                    default:
                        return .failure(LoxRuntimeError.oops(token)) // can't compare these types from others
                    }
                default:
                    return .failure(LoxRuntimeError.oops(token)) // not allowed to compare these types
                }

            case let .GreaterThanOrEqual(token):
                switch leftRuntimeValue {
                // compare the numbers
                case let .number(leftval):
                    switch rightRuntimeValue {
                    case let .number(rightval):
                        return .success(RuntimeValue.boolean(value: leftval >= rightval))
                    default:
                        return .failure(LoxRuntimeError.oops(token)) // can't compare these types from others
                    }
                // compare the strings
                case let .string(leftval):
                    switch rightRuntimeValue {
                    case let .string(rightval):
                        return .success(RuntimeValue.boolean(value: leftval >= rightval))
                    default:
                        return .failure(LoxRuntimeError.oops(token)) // can't compare these types from others
                    }
                default:
                    return .failure(LoxRuntimeError.oops(token)) // not allowed to compare these types
                }

            case let .Equals(token):
                switch leftRuntimeValue {
                // compare the numbers
                case let .number(leftval):
                    switch rightRuntimeValue {
                    case let .number(rightval):
                        return .success(RuntimeValue.boolean(value: leftval == rightval))
                    default:
                        return .failure(LoxRuntimeError.oops(token)) // can't compare these types from others
                    }
                // compare the strings
                case let .string(leftval):
                    switch rightRuntimeValue {
                    case let .string(rightval):
                        return .success(RuntimeValue.boolean(value: leftval == rightval))
                    default:
                        return .failure(LoxRuntimeError.oops(token)) // can't compare these types from others
                    }
                // compare the bools
                case let .boolean(leftval):
                    switch rightRuntimeValue {
                    case let .boolean(rightval):
                        return .success(RuntimeValue.boolean(value: leftval == rightval))
                    default:
                        return .failure(LoxRuntimeError.oops(token)) // can't compare these types from others
                    }
                default:
                    return .failure(LoxRuntimeError.oops(token)) // not allowed to compare these types
                }

            case let .NotEquals(token):
                switch leftRuntimeValue {
                // compare the numbers
                case let .number(leftval):
                    switch rightRuntimeValue {
                    case let .number(rightval):
                        return .success(RuntimeValue.boolean(value: leftval != rightval))
                    default:
                        return .failure(LoxRuntimeError.oops(token)) // can't compare these types from others
                    }
                // compare the strings
                case let .string(leftval):
                    switch rightRuntimeValue {
                    case let .string(rightval):
                        return .success(RuntimeValue.boolean(value: leftval != rightval))
                    default:
                        return .failure(LoxRuntimeError.oops(token)) // can't compare these types from others
                    }
                // compare the bools
                case let .boolean(leftval):
                    switch rightRuntimeValue {
                    case let .boolean(rightval):
                        return .success(RuntimeValue.boolean(value: leftval != rightval))
                    default:
                        return .failure(LoxRuntimeError.oops(token)) // can't compare these types from others
                    }
                default:
                    return .failure(LoxRuntimeError.oops(token)) // not allowed to compare these types
                }
            }
        // binary
        case let .grouping(expr):
            return expr.evaluate()
        case .variable(_):
            <#code#>
        }
    }
}

extension LiteralExpression: Interpretable {
    public func evaluate() -> Result<RuntimeValue, LoxRuntimeError> {
        switch self {
        case let .number(token):
            switch token.literal {
            case .none:
                return .failure(LoxRuntimeError.oops(token))
            case .string:
                return .failure(LoxRuntimeError.oops(token))
            case let .number(value: value):
                return .success(RuntimeValue.number(value: value))
            }
        case let .string(token):
            switch token.literal {
            case .none:
                return .failure(LoxRuntimeError.oops(token))
            case let .string(value: value):
                return .success(RuntimeValue.string(value: value))
            case .number:
                return .failure(LoxRuntimeError.oops(token))
            }
        case .trueToken:
            return .success(RuntimeValue.boolean(value: true))
        case .falseToken:
            return .success(RuntimeValue.boolean(value: false))
        case .nilToken:
            return .success(RuntimeValue.none)
        }
    }
}

public protocol RuntimeEvaluation {
    func execute() -> Result<Int, LoxRuntimeError>
}

extension Statement: RuntimeEvaluation {
    public func execute() -> Result<Int, LoxRuntimeError> {
        switch self {
        case let .printStatement(expr):
            let result = expr.evaluate() // _ is a RuntimeValue
            switch result {
            case let .success(runtimevalue):
                print(runtimevalue)
            case let .failure(err):
                print("ERROR: \(err)")
                return .failure(err)
            }
        default:
            return .failure(LoxRuntimeError.notImplemented)
        }
        return .success(0)
    }
}

public class Interpretter {
    private func pass() {}
    public func interpretStatements(_ statements: [Statement]) {
        for statement in statements {
            switch statement.execute() {
            case let .failure(err):
                print("INTERPRETTER HALTING: \(err)")
                return
            case .success:
                pass()
            }
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
