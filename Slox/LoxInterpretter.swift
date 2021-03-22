//
//  LoxInterpretter.swift
//  Slox
//
//  Created by Joseph Heck on 3/7/21.
//

// Chapter 7: https://craftinginterpreters.com/evaluating-expressions.html
// Chapter 8: https://craftinginterpreters.com/statements-and-state.html
// Chapter 9: https://craftinginterpreters.com/control-flow.html
// Chapter 10: https://craftinginterpreters.com/functions.html
// pending: https://craftinginterpreters.com/functions.html#native-functions

import Foundation

public enum RuntimeError: Error {
    case notImplemented
    case typeMismatch(_ token: Token, message: String = "")
    case undefinedVariable(_ token: Token, message: String = "")
    case notCallable(callee: RuntimeValue)
    case incorrectArgumentCount(expected: Int, actual: Int)
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
        case let .callable(value):
            return value.description
        }
    }

    case string(_ value: String)
    case number(_ value: Double)
    case boolean(_ value: Bool)
    case callable(_ value: Callable)
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
        default:
            return true
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
    private let globals = Environment()
    private var environment: Environment

    init() {
        globals.define("clock",
                       value: .callable(
                           Callable(description: "clock",
                                    arity: 0,
                                    call: {
                                        (_, _) -> RuntimeValue in
                                        RuntimeValue.number(Date().timeIntervalSince1970)
                                    })
                       ))
        environment = globals
    }

    private func pass() {}

    private struct Return: Error {
        let value: RuntimeValue
    }

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
            try executeBlock(statements, using: Environment(enclosing: environment))
        case let .expressionStatement(expr):
            try executeExpression(expr)
        case let .whileStatement(condition, body):
            try executeWhile(condition, body)
        case let .function(name, params, body):
            try evaluateFunction(name, params, body)
        }
    }

    private func evaluateFunction(_ name: Token, _ params: [Token], _ body: [Statement]) throws {
        let localenv = Environment(enclosing: globals)

        let function = Callable(description: name.lexeme, arity: params.count) { (_: Interpretter, arguments: [RuntimeValue]) -> RuntimeValue in

            for (parameter, argument) in zip(params, arguments) {
                localenv.define(parameter.lexeme, value: argument)
            }
            do {
                try self.executeBlock(body, using: localenv)
            } catch let returnError as Return {
                return returnError.value
            }

            return .none
        }
        environment.define(name.lexeme, value: RuntimeValue.callable(function))
    }

    private func executeWhile(_ cond: Expression, _ body: Statement) throws {
        let val = try evaluate(cond)
        if val.truthy {
            try execute(body)
        }
    }

    private func executeIf(_ condition: Expression, thenStmt: Statement, elseStmt: Statement?) throws {
        let value = try evaluate(condition)
        if value.truthy {
            try execute(thenStmt)
        } else {
            if let elseStatement = elseStmt {
                try execute(elseStatement)
            }
        }
    }

    private func executeExpression(_ expr: Expression) throws {
        _ = try evaluate(expr)
    }

    private func executePrint(_ expr: Expression) throws {
        let runtimevalue = try evaluate(expr)
        print(runtimevalue)
    }

    private func executeVariable(_ token: Token, _ expr: Expression) throws {
        let val = try evaluate(expr)
        environment.define(token.lexeme, value: val)
    }

    private func executeBlock(_ statements: [Statement], using: Environment) throws {
        let previous = environment
        defer {
            self.environment = previous
        }
        environment = using
        try interpretStatements(statements)
    }

    // MARK: Evaluate Expressions...

    public func evaluate(_ expr: Expression) throws -> RuntimeValue {
        switch expr {
        case let .literal(literal):
            return evaluateLiteral(literal)

        case let .assign(tok, expr):
            return try evaluateAssign(tok, expr: expr)

        case let .unary(unary, expr):
            return try evaluateUnary(unary, expr: expr)

        case let .binary(lhs, op, rhs):
            return try evaluateBinary(lhs, op, rhs)

        case let .grouping(expr):
            return try evaluateGrouping(expr)
        case let .variable(token):
            return try evaluateVariable(token)
        case let .logical(lhs, op, rhs):
            return try evaluateLogical(lhs, op, rhs)
        case let .call(callee, paren, arguments):
            return try evaluateCall(callee, paren, arguments)
        }
    }

    private func evaluateCall(_ callee: Expression, _: Token, _ arguments: [Expression]) throws -> RuntimeValue {
        let calleeResultValue: RuntimeValue = try evaluate(callee)

        let argumentValues = try arguments.map { expr -> RuntimeValue in
            try evaluate(expr)
        }

        guard case let RuntimeValue.callable(function) = calleeResultValue else {
            throw RuntimeError.notCallable(callee: calleeResultValue)
        }

        guard arguments.count == function.arity else {
            throw RuntimeError.incorrectArgumentCount(expected: function.arity, actual: arguments.count)
        }

//        throw RuntimeError.notImplemented
        return try function.call(self, argumentValues)
    }

    private func evaluateLogical(_ lhs: Expression, _ op: LogicalOperator, _ rhs: Expression) throws -> RuntimeValue {
        let left: RuntimeValue = try evaluate(lhs)
        switch (op, left.truthy) {
        case (.Or, true):
            return left
        case (.And, false):
            return left
        default:
            return try evaluate(rhs)
        }
    }

    private func evaluateBinary(_ lhs: Expression, _ expr_op: Operator, _ rhs: Expression) throws -> RuntimeValue {
        let leftValue: RuntimeValue = try evaluate(lhs)
        let rightValue: RuntimeValue = try evaluate(rhs)

        switch expr_op {
        case let .Subtract(token):
            return try evaluateSubtract(token, leftValue: leftValue, rightValue: rightValue)

        case let .Multiply(token):
            return try evaluateMultiply(token, leftValue: leftValue, rightValue: rightValue)

        case let .Divide(token):
            return try evaluateDivide(token, leftValue: leftValue, rightValue: rightValue)

        case let .Add(token):
            return try evaluateAdd(token, leftValue: leftValue, rightValue: rightValue)

        case let .LessThan(token):
            return try evaluateLessThan(token, leftValue: leftValue, rightValue: rightValue)

        case let .LessThanOrEqual(token):
            return try evaluateLessThanEqual(token, leftValue: leftValue, rightValue: rightValue)

        case let .GreaterThan(token):
            return try evaluateGreaterThan(token, leftValue: leftValue, rightValue: rightValue)

        case let .GreaterThanOrEqual(token):
            return try evaluateGreaterThanEqual(token, leftValue: leftValue, rightValue: rightValue)

        case let .Equals(token):
            return try evaluateEquals(token, leftValue: leftValue, rightValue: rightValue)

        case let .NotEquals(token):
            return try evaluateNotEquals(token, leftValue: leftValue, rightValue: rightValue)
        }
    }

    // Binary operation evaluations

    private func evaluateSubtract(_ token: Token, leftValue: RuntimeValue, rightValue: RuntimeValue) throws -> RuntimeValue {
        switch leftValue {
        case let .number(leftval):
            switch rightValue {
            case let .number(rightval):
                return RuntimeValue.number(leftval - rightval)
            default:
                throw RuntimeError.typeMismatch(token, message: "can't subtract these types from others")
            }
        default:
            throw RuntimeError.typeMismatch(token, message: "not allowed to 'subtract' these types")
        }
    }

    private func evaluateMultiply(_ token: Token, leftValue: RuntimeValue, rightValue: RuntimeValue) throws -> RuntimeValue {
        switch leftValue {
        case let .number(leftval):
            switch rightValue {
            case let .number(rightval):
                return RuntimeValue.number(leftval * rightval)
            default:
                throw RuntimeError.typeMismatch(token, message: "can't subtract these types from others")
            }
        default:
            throw RuntimeError.typeMismatch(token, message: "not allowed to 'subtract' these types")
        }
    }

    private func evaluateDivide(_ token: Token, leftValue: RuntimeValue, rightValue: RuntimeValue) throws -> RuntimeValue {
        switch leftValue {
        case let .number(leftval):
            switch rightValue {
            case let .number(rightval):
                return RuntimeValue.number(leftval / rightval)
            default:
                throw RuntimeError.typeMismatch(token, message: "can't subtract these types from others")
            }
        default:
            throw RuntimeError.typeMismatch(token, message: "not allowed to 'subtract' these types")
        }
    }

    private func evaluateAdd(_ token: Token, leftValue: RuntimeValue, rightValue: RuntimeValue) throws -> RuntimeValue {
        switch leftValue {
        // add the numbers
        case let .number(leftval):
            switch rightValue {
            case let .number(rightval):
                return RuntimeValue.number(leftval + rightval)
            default:
                throw RuntimeError.typeMismatch(token, message: "can't add these types from others")
            }
        // concatenate the strings
        case let .string(leftval):
            switch rightValue {
            case let .string(rightval):
                return RuntimeValue.string(leftval + rightval)
            default:
                throw RuntimeError.typeMismatch(token, message: "can't add these types from others")
            }
        default:
            throw RuntimeError.typeMismatch(token, message: "can't add these types")
        }
    }

    private func evaluateLessThan(_ token: Token, leftValue: RuntimeValue, rightValue: RuntimeValue) throws -> RuntimeValue {
        switch leftValue {
        // compare the numbers
        case let .number(leftval):
            switch rightValue {
            case let .number(rightval):
                return RuntimeValue.boolean(leftval < rightval)
            default:
                throw RuntimeError.typeMismatch(token, message: "can't compare these types")
            }
        // compare the strings
        case let .string(leftval):
            switch rightValue {
            case let .string(rightval):
                return RuntimeValue.boolean(leftval < rightval)
            default:
                throw RuntimeError.typeMismatch(token, message: "can't compare these types")
            }
        default:
            throw RuntimeError.typeMismatch(token, message: "can't compare these types")
        }
    }

    private func evaluateLessThanEqual(_ token: Token, leftValue: RuntimeValue, rightValue: RuntimeValue) throws -> RuntimeValue {
        switch leftValue {
        // compare the numbers
        case let .number(leftval):
            switch rightValue {
            case let .number(rightval):
                return RuntimeValue.boolean(leftval <= rightval)
            default:
                throw RuntimeError.typeMismatch(token, message: "can't compare these types")
            }
        // compare the strings
        case let .string(leftval):
            switch rightValue {
            case let .string(rightval):
                return RuntimeValue.boolean(leftval <= rightval)
            default:
                throw RuntimeError.typeMismatch(token, message: "can't compare these types")
            }
        default:
            throw RuntimeError.typeMismatch(token, message: "can't compare these types")
        }
    }

    private func evaluateGreaterThan(_ token: Token, leftValue: RuntimeValue, rightValue: RuntimeValue) throws -> RuntimeValue {
        switch leftValue {
        // compare the numbers
        case let .number(leftval):
            switch rightValue {
            case let .number(rightval):
                return RuntimeValue.boolean(leftval > rightval)
            default:
                throw RuntimeError.typeMismatch(token, message: "can't compare these types")
            }
        // compare the strings
        case let .string(leftval):
            switch rightValue {
            case let .string(rightval):
                return RuntimeValue.boolean(leftval > rightval)
            default:
                throw RuntimeError.typeMismatch(token, message: "can't compare these types")
            }
        default:
            throw RuntimeError.typeMismatch(token, message: "can't compare these types")
        }
    }

    private func evaluateGreaterThanEqual(_ token: Token, leftValue: RuntimeValue, rightValue: RuntimeValue) throws -> RuntimeValue {
        switch leftValue {
        // compare the numbers
        case let .number(leftval):
            switch rightValue {
            case let .number(rightval):
                return RuntimeValue.boolean(leftval >= rightval)
            default:
                throw RuntimeError.typeMismatch(token, message: "can't compare these types")
            }
        // compare the strings
        case let .string(leftval):
            switch rightValue {
            case let .string(rightval):
                return RuntimeValue.boolean(leftval >= rightval)
            default:
                throw RuntimeError.typeMismatch(token, message: "can't compare these types")
            }
        default:
            throw RuntimeError.typeMismatch(token, message: "can't compare these types")
        }
    }

    private func evaluateEquals(_ token: Token, leftValue: RuntimeValue, rightValue: RuntimeValue) throws -> RuntimeValue {
        switch leftValue {
        // compare the numbers
        case let .number(leftval):
            switch rightValue {
            case let .number(rightval):
                return RuntimeValue.boolean(leftval == rightval)
            default:
                throw RuntimeError.typeMismatch(token, message: "can't compare these types")
            }
        // compare the strings
        case let .string(leftval):
            switch rightValue {
            case let .string(rightval):
                return RuntimeValue.boolean(leftval == rightval)
            default:
                throw RuntimeError.typeMismatch(token, message: "can't compare these types")
            }
        // compare the bools
        case let .boolean(leftval):
            switch rightValue {
            case let .boolean(rightval):
                return RuntimeValue.boolean(leftval == rightval)
            default:
                throw RuntimeError.typeMismatch(token, message: "can't compare these types")
            }
        default:
            throw RuntimeError.typeMismatch(token, message: "can't compare these types")
        }
    }

    private func evaluateNotEquals(_ token: Token, leftValue: RuntimeValue, rightValue: RuntimeValue) throws -> RuntimeValue {
        switch leftValue {
        // compare the numbers
        case let .number(leftval):
            switch rightValue {
            case let .number(rightval):
                return RuntimeValue.boolean(leftval != rightval)
            default:
                throw RuntimeError.typeMismatch(token, message: "can't compare these types")
            }
        // compare the strings
        case let .string(leftval):
            switch rightValue {
            case let .string(rightval):
                return RuntimeValue.boolean(leftval != rightval)
            default:
                throw RuntimeError.typeMismatch(token, message: "can't compare these types")
            }
        // compare the bools
        case let .boolean(leftval):
            switch rightValue {
            case let .boolean(rightval):
                return RuntimeValue.boolean(leftval != rightval)
            default:
                throw RuntimeError.typeMismatch(token, message: "can't compare these types")
            }
        default:
            throw RuntimeError.typeMismatch(token, message: "can't compare these types")
        }
    }

    private func evaluateAssign(_ tok: Token, expr: Expression) throws -> RuntimeValue {
        do {
            try environment.assign(tok, evaluate(expr))
            return RuntimeValue.none
        } catch {
            throw RuntimeError.undefinedVariable(tok, message: "\(error)")
        }
    }

    private func evaluateUnary(_ unary: Unary, expr: Expression) throws -> RuntimeValue {
        let runtimeValue = try evaluate(expr)

        switch unary {
        case let .minus(token):
            switch runtimeValue {
            case .boolean(_), .string(_), .callable(_), .none:
                throw RuntimeError.typeMismatch(token, message: "not allowed to 'minus' these types")
            case let .number(value):
                return RuntimeValue.number(-value)
            }
        case let .not(token):
            switch runtimeValue {
            case .number(_), .string(_), .callable(_), .none:
                throw RuntimeError.typeMismatch(token, message: "not allowed to 'minus' these types")
            case let .boolean(value):
                return RuntimeValue.boolean(!value)
            }
        }
    }

    private func evaluateGrouping(_ expr: Expression) throws -> RuntimeValue {
        return try evaluate(expr)
    }

    private func evaluateVariable(_ token: Token) throws -> RuntimeValue {
        do {
            return try environment.get(token)
        } catch {
            throw RuntimeError.undefinedVariable(token, message: "\(error)")
        }
    }

    private func evaluateLiteral(_ literal: Literal) -> RuntimeValue {
        switch literal {
        case let .number(doubleValue):
            return RuntimeValue.number(doubleValue)
        case let .string(stringValue):
            return RuntimeValue.string(stringValue)
        case .trueToken:
            return RuntimeValue.boolean(true)
        case .falseToken:
            return RuntimeValue.boolean(false)
        case .nilToken:
            return RuntimeValue.none
        }
    }
}
