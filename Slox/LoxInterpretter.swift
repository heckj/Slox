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

    public var truthy: Bool {
        switch self {
        case .none:
            return false
        case let .string(value: value):
            return value.count > 0
        case let .number(value: value):
            return value != 0
        case let .boolean(value: value):
            return value
        }
    }
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
                // No enclosing environment, so we can't assign the variable - it was
                // never defined, so we bail out here.
                throw RuntimeError.undefinedVariable(name, message: "Undefined variable '\(name.lexeme)'")
            }
        }
        values[name.lexeme] = val
    }
}

// Other versions of this, which I think end up being far more readable
// and understandable, don't do this within a massive switch, but break up
// the whole thing into sub-functions (private func...) for each kind of
// statement. Expressions each get "evaluated" - with a function named akin
// to the type of expression - e.g. evaluateUnary(unary: Unary) -> RuntimeValue
// Two other versions of this in swift that are worth looking at for comparsions:
// - https://github1s.com/danielctull/lox
// - https://github1s.com/hashemi/slox

public class Interpretter {
    private var environment = Environment()
    private func pass() {}

    public func interpretStatements(_ statements: [Statement]) throws {
        for statement in statements {
            try execute(statement)
        }
    }

    private func execute(_ statement: Statement) throws {
        switch statement {
        case let .ifStatement(condition, thenBranch, elseBranch):
            try executeIf(condition, thenStmt: thenBranch, elseStmt: elseBranch)
        case let .printStatement(expr):
            try executePrint(expr)
        case let .variable(token, expr):
            try executeVariable(token, expr)
        case let .block(statements):
            try executeBlock(statements, Environment(enclosing: environment))
        case let .expressionStatement(expr):
            try executeExpression(expr)
        }
    }

    private func executeIf(_ condition: Expression, thenStmt: Statement, elseStmt: Statement?) throws {
        switch condition.evaluate(environment) {
        case let .success(value):
            if value.truthy {
                try execute(thenStmt)
            } else {
                if let elseStatement = elseStmt {
                    try execute(elseStatement)
                }
            }
        case let .failure(err):
            throw err
        }
    }

    private func executeExpression(_ expr: Expression) throws {
        switch expr.evaluate(environment) {
        case .success:
            pass()
        case let .failure(err):
            throw err
        }
    }

    private func executePrint(_ expr: Expression) throws {
        switch expr.evaluate(environment) {
        case let .success(runtimevalue):
            print(runtimevalue)
        case let .failure(err):
            throw err
        }
    }

    private func executeVariable(_ token: Token, _ expr: Expression) throws {
        switch expr.evaluate(environment) {
        case let .success(val):
            environment.define(token.lexeme, value: val)
        case let .failure(err):
            throw err
        }
    }

    private func executeBlock(_ statements: [Statement], _ env: Environment) throws {
        let previous = environment
        defer {
            self.environment = previous
        }
        environment = env
        try interpretStatements(statements)
    }
}
