//
//  LoxInterpretter.swift
//  Slox
//
//  Created by Joseph Heck on 3/7/21.
//

// Chapter 7: https://craftinginterpreters.com/evaluating-expressions.html
// pending: https://craftinginterpreters.com/statements-and-state.html#scope

import Foundation

public enum RuntimeError: Error {
    case notImplemented
    case typeMismatch(_ token: Token, message: String = "")
    case undefinedVariable(_ token: Token, message: String = "")
    case unexpectedNullValue
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
    func evaluate(_ env: Environment) -> Result<RuntimeValue, RuntimeError>
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

// Other versions of this, which I think end up being far more readable
// and understandable, don't do this within a massive switch, but break up
// the whole thing into sub-functions (private func...) for each kind of
// statement. Expressions each get "evaluated" - with a function named akin
// to the type of expression - e.g. evaluateUnary(unary: Unary) -> RuntimeValue
// Two other versions of this in swift that are worth looking at for comparsions:
// - https://github1s.com/danielctull/lox
// - https://github1s.com/hashemi/slox

extension Expression: Interpretable {
    public func evaluate(_ env: Environment) -> Result<RuntimeValue, RuntimeError> {
        switch self {
        case let .literal(literal):
            return evaluateLiteral(literal, env: env)

        case let .assign(tok, expr):
            return evaluateAssign(tok, expr: expr, env: env)

        case let .unary(unary, expr):
            return evaluateUnary(unary, expr: expr, env: env)

        case let .binary(lhs, op, rhs):
            return evaluateBinary(expr_l: lhs, expr_op: op, expr_r: rhs, env: env)

        case let .grouping(expr):
            return evaluateGrouping(expr, env: env)
        case let .variable(token):
            return evaluateVariable(token, env: env)
        }
    }

    private func evaluateBinary(expr_l: Expression, expr_op: Operator, expr_r: Expression, env: Environment) -> Result<RuntimeValue, RuntimeError> {
        let leftValue: RuntimeValue
        let rightValue: RuntimeValue
        // check left and right result, if either failed - propagate it
        switch expr_l.evaluate(env) {
        case let .success(resolvedExpression):
            leftValue = resolvedExpression
        case let .failure(err):
            return .failure(err)
        }

        switch expr_r.evaluate(env) {
        case let .failure(err):
            return .failure(err)
        case let .success(resolvedExpression):
            rightValue = resolvedExpression
        }

        switch expr_op {
        case let .Subtract(token):
            return evaluateSubtract(token, leftValue: leftValue, rightValue: rightValue)

        case let .Multiply(token):
            return evaluateMultiply(token, leftValue: leftValue, rightValue: rightValue)

        case let .Divide(token):
            return evaluateDivide(token, leftValue: leftValue, rightValue: rightValue)

        case let .Add(token):
            return evaluateAdd(token, leftValue: leftValue, rightValue: rightValue)

        case let .LessThan(token):
            return evaluateLessThan(token, leftValue: leftValue, rightValue: rightValue)

        case let .LessThanOrEqual(token):
            return evaluateLessThanEqual(token, leftValue: leftValue, rightValue: rightValue)

        case let .GreaterThan(token):
            return evaluateGreaterThan(token, leftValue: leftValue, rightValue: rightValue)

        case let .GreaterThanOrEqual(token):
            return evaluateGreaterThanEqual(token, leftValue: leftValue, rightValue: rightValue)

        case let .Equals(token):
            return evaluateEquals(token, leftValue: leftValue, rightValue: rightValue)

        case let .NotEquals(token):
            return evaluateNotEquals(token, leftValue: leftValue, rightValue: rightValue)
        }
    }

    // Binary operation evaluations

    private func evaluateSubtract(_ token: Token, leftValue: RuntimeValue, rightValue: RuntimeValue) -> Result<RuntimeValue, RuntimeError> {
        switch leftValue {
        case let .number(leftval):
            switch rightValue {
            case let .number(rightval):
                return .success(RuntimeValue.number(value: leftval - rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't subtract these types from others"))
            }
        default:
            return .failure(RuntimeError.typeMismatch(token, message: "not allowed to 'subtract' these types"))
        }
    }

    private func evaluateMultiply(_ token: Token, leftValue: RuntimeValue, rightValue: RuntimeValue) -> Result<RuntimeValue, RuntimeError> {
        switch leftValue {
        case let .number(leftval):
            switch rightValue {
            case let .number(rightval):
                return .success(RuntimeValue.number(value: leftval * rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't subtract these types from others"))
            }
        default:
            return .failure(RuntimeError.typeMismatch(token, message: "not allowed to 'subtract' these types"))
        }
    }

    private func evaluateDivide(_ token: Token, leftValue: RuntimeValue, rightValue: RuntimeValue) -> Result<RuntimeValue, RuntimeError> {
        switch leftValue {
        case let .number(leftval):
            switch rightValue {
            case let .number(rightval):
                return .success(RuntimeValue.number(value: leftval / rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't subtract these types from others"))
            }
        default:
            return .failure(RuntimeError.typeMismatch(token, message: "not allowed to 'subtract' these types"))
        }
    }

    private func evaluateAdd(_ token: Token, leftValue: RuntimeValue, rightValue: RuntimeValue) -> Result<RuntimeValue, RuntimeError> {
        switch leftValue {
        // add the numbers
        case let .number(leftval):
            switch rightValue {
            case let .number(rightval):
                return .success(RuntimeValue.number(value: leftval + rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't add these types from others"))
            }
        // concatenate the strings
        case let .string(leftval):
            switch rightValue {
            case let .string(rightval):
                return .success(RuntimeValue.string(value: leftval + rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't add these types from others"))
            }
        default:
            return .failure(RuntimeError.typeMismatch(token, message: "can't add these types"))
        }
    }

    private func evaluateLessThan(_ token: Token, leftValue: RuntimeValue, rightValue: RuntimeValue) -> Result<RuntimeValue, RuntimeError> {
        switch leftValue {
        // compare the numbers
        case let .number(leftval):
            switch rightValue {
            case let .number(rightval):
                return .success(RuntimeValue.boolean(value: leftval < rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
            }
        // compare the strings
        case let .string(leftval):
            switch rightValue {
            case let .string(rightval):
                return .success(RuntimeValue.boolean(value: leftval < rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
            }
        default:
            return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
        }
    }

    private func evaluateLessThanEqual(_ token: Token, leftValue: RuntimeValue, rightValue: RuntimeValue) -> Result<RuntimeValue, RuntimeError> {
        switch leftValue {
        // compare the numbers
        case let .number(leftval):
            switch rightValue {
            case let .number(rightval):
                return .success(RuntimeValue.boolean(value: leftval <= rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
            }
        // compare the strings
        case let .string(leftval):
            switch rightValue {
            case let .string(rightval):
                return .success(RuntimeValue.boolean(value: leftval <= rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
            }
        default:
            return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
        }
    }

    private func evaluateGreaterThan(_ token: Token, leftValue: RuntimeValue, rightValue: RuntimeValue) -> Result<RuntimeValue, RuntimeError> {
        switch leftValue {
        // compare the numbers
        case let .number(leftval):
            switch rightValue {
            case let .number(rightval):
                return .success(RuntimeValue.boolean(value: leftval > rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
            }
        // compare the strings
        case let .string(leftval):
            switch rightValue {
            case let .string(rightval):
                return .success(RuntimeValue.boolean(value: leftval > rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
            }
        default:
            return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
        }
    }

    private func evaluateGreaterThanEqual(_ token: Token, leftValue: RuntimeValue, rightValue: RuntimeValue) -> Result<RuntimeValue, RuntimeError> {
        switch leftValue {
        // compare the numbers
        case let .number(leftval):
            switch rightValue {
            case let .number(rightval):
                return .success(RuntimeValue.boolean(value: leftval >= rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
            }
        // compare the strings
        case let .string(leftval):
            switch rightValue {
            case let .string(rightval):
                return .success(RuntimeValue.boolean(value: leftval >= rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
            }
        default:
            return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
        }
    }

    private func evaluateEquals(_ token: Token, leftValue: RuntimeValue, rightValue: RuntimeValue) -> Result<RuntimeValue, RuntimeError> {
        switch leftValue {
        // compare the numbers
        case let .number(leftval):
            switch rightValue {
            case let .number(rightval):
                return .success(RuntimeValue.boolean(value: leftval == rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
            }
        // compare the strings
        case let .string(leftval):
            switch rightValue {
            case let .string(rightval):
                return .success(RuntimeValue.boolean(value: leftval == rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
            }
        // compare the bools
        case let .boolean(leftval):
            switch rightValue {
            case let .boolean(rightval):
                return .success(RuntimeValue.boolean(value: leftval == rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
            }
        default:
            return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
        }
    }

    private func evaluateNotEquals(_ token: Token, leftValue: RuntimeValue, rightValue: RuntimeValue) -> Result<RuntimeValue, RuntimeError> {
        switch leftValue {
        // compare the numbers
        case let .number(leftval):
            switch rightValue {
            case let .number(rightval):
                return .success(RuntimeValue.boolean(value: leftval != rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
            }
        // compare the strings
        case let .string(leftval):
            switch rightValue {
            case let .string(rightval):
                return .success(RuntimeValue.boolean(value: leftval != rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
            }
        // compare the bools
        case let .boolean(leftval):
            switch rightValue {
            case let .boolean(rightval):
                return .success(RuntimeValue.boolean(value: leftval != rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
            }
        default:
            return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
        }
    }

    private func evaluateAssign(_ tok: Token, expr: Expression, env: Environment) -> Result<RuntimeValue, RuntimeError> {
        switch expr.evaluate(env) {
        case let .success(value):
            do {
                try env.assign(tok, value)
                return .success(RuntimeValue.none)
            } catch {
                return .failure(RuntimeError.undefinedVariable(tok, message: "\(error)"))
            }
        case let .failure(err):
            return .failure(err)
        }
    }

    private func evaluateUnary(_ unary: Unary, expr: Expression, env: Environment) -> Result<RuntimeValue, RuntimeError> {
        let runtimeValue: RuntimeValue
        switch expr.evaluate(env) {
        case let .success(workingval):
            runtimeValue = workingval
        case let .failure(err):
            return .failure(err)
        }

        switch unary {
        case let .minus(token):
            switch runtimeValue {
            case .boolean(_), .string(_), .none:
                return .failure(RuntimeError.typeMismatch(token, message: "not allowed to 'minus' these types"))
            case let .number(value):
                return .success(RuntimeValue.number(value: -value))
            }
        case let .not(token):
            switch runtimeValue {
            case .number(_), .string(_), .none:
                return .failure(RuntimeError.typeMismatch(token, message: "not allowed to 'minus' these types"))
            case let .boolean(value):
                return .success(RuntimeValue.boolean(value: !value))
            }
        }
    }

    private func evaluateGrouping(_ expr: Expression, env: Environment) -> Result<RuntimeValue, RuntimeError> {
        return expr.evaluate(env)
    }

    private func evaluateVariable(_ token: Token, env: Environment) -> Result<RuntimeValue, RuntimeError> {
        do {
            return .success(try env.get(token))
        } catch {
            return .failure(RuntimeError.undefinedVariable(token, message: "\(error)"))
        }
    }

    private func evaluateLiteral(_ literal: Literal, env _: Environment) -> Result<RuntimeValue, RuntimeError> {
        switch literal {
        case let .number(token):
            switch token.literal {
            case .none:
                return .failure(RuntimeError.typeMismatch(token, message: "type not a number"))
            case .string:
                return .failure(RuntimeError.typeMismatch(token, message: "type not a number"))
            case let .number(value: value):
                return .success(RuntimeValue.number(value: value))
            }
        case let .string(token):
            switch token.literal {
            case .none:
                return .failure(RuntimeError.typeMismatch(token, message: "type not a string"))
            case let .string(value: value):
                return .success(RuntimeValue.string(value: value))
            case .number:
                return .failure(RuntimeError.typeMismatch(token, message: "type not a string"))
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
    func execute(_ env: Environment) -> Result<Int, RuntimeError>
}

extension Statement: RuntimeEvaluation {
    public func execute(_ env: Environment) -> Result<Int, RuntimeError> {
        switch self {
        case let .printStatement(expr):
            let result = expr.evaluate(env) // _ is a RuntimeValue
            switch result {
            case let .success(runtimevalue):
                print(runtimevalue)
            case let .failure(err):
                print("ERROR: \(err)")
                return .failure(err)
            }
        case let .variable(token, expr):
            let value = expr.evaluate(env)
            switch value {
            case let .success(val):
                env.define(token.lexeme, value: val)
                return .success(0)
            case let .failure(err):
                return .failure(err)
            }

        default:
            return .failure(RuntimeError.notImplemented)
        }
        return .success(0)
    }
}

public class Interpretter {
    private var environment = Environment()
    private func pass() {}
    public func interpretStatements(_ statements: [Statement]) {
        for statement in statements {
            switch statement.execute(environment) {
            case let .failure(err):
                print("INTERPRETTER HALTING: \(err)")
                return
            case .success:
                pass()
            }
        }
    }

    // interpret just an expression
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

public final class Environment {
    var values: [String: RuntimeValue] = [:]

    public func define(_ name: String, value: RuntimeValue) {
        // by not checking to see if the name already exists,
        // we support "overwriting it" in the program flow for Lox
        values[name] = value
    }

    public func get(_ name: Token) throws -> RuntimeValue {
        if let something = values[name.lexeme] {
            return something
        }
        throw RuntimeError.undefinedVariable(name, message: "Undefined variable '\(name.lexeme)'")
    }

    public func assign(_ name: Token, _ val: RuntimeValue) throws {
        guard let _ = values[name.lexeme] else {
            throw RuntimeError.undefinedVariable(name, message: "Undefined variable '\(name.lexeme)'")
        }
        values[name.lexeme] = val
    }
}
