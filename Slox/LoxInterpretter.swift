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

public final class Environment {
    var values: [String: RuntimeValue] = [:]
    var enclosing: Environment?

    init(enclosing: Environment? = nil) {
        self.enclosing = enclosing
    }

    public func define(_ name: String, value: RuntimeValue) {
        // by not checking to see if the name already exists,
        // we support "overwriting it" in the program flow for Lox
        values[name] = value
    }

    public func get(_ name: Token) throws -> RuntimeValue {
        if let something = values[name.lexeme] {
            return something
        }
        // Look/recurse through any sets of enclosing environments to see
        // if the variable is defined there.
        if let something = try enclosing?.get(name) {
            return something
        }
        throw RuntimeError.undefinedVariable(name, message: "Undefined variable '\(name.lexeme)'")
    }

    public func assign(_ name: Token, _ val: RuntimeValue) throws {
        guard let _ = values[name.lexeme] else {
            // Wasn't able to find the value within this level of environment,
            // so before pitching an error, we'll try any enclosing environments.
            if enclosing != nil {
                try enclosing?.assign(name, val)
                return
            } else {
                throw RuntimeError.undefinedVariable(name, message: "Undefined variable '\(name.lexeme)'")
            }
        }
        values[name.lexeme] = val
    }
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
