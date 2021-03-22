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
        case let .whileStatement(condition, body):
            try executeWhile(condition, body)
        }
    }

    private func executeWhile(_ cond: Expression, _ body: Statement) throws {
        switch evaluate(cond) {
        case .success:
            try execute(body)
        case .failure:
            return
        }
    }

    private func executeIf(_ condition: Expression, thenStmt: Statement, elseStmt: Statement?) throws {
        switch evaluate(condition) {
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
        switch evaluate(expr) {
        case .success:
            pass()
        case let .failure(err):
            throw err
        }
    }

    private func executePrint(_ expr: Expression) throws {
        switch evaluate(expr) {
        case let .success(runtimevalue):
            print(runtimevalue)
        case let .failure(err):
            throw err
        }
    }

    private func executeVariable(_ token: Token, _ expr: Expression) throws {
        switch evaluate(expr) {
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

    // MARK: Evaluate Expressions...

    public func evaluate(_ expr: Expression) -> Result<RuntimeValue, RuntimeError> {
        switch expr {
        case let .literal(literal):
            return evaluateLiteral(literal)

        case let .assign(tok, expr):
            return evaluateAssign(tok, expr: expr)

        case let .unary(unary, expr):
            return evaluateUnary(unary, expr: expr)

        case let .binary(lhs, op, rhs):
            return evaluateBinary(lhs, op, rhs)

        case let .grouping(expr):
            return evaluateGrouping(expr)
        case let .variable(token):
            return evaluateVariable(token)
        case let .logical(lhs, op, rhs):
            return evaluateLogical(lhs, op, rhs)
        case let .call(callee, paren, arguments):
            return evaluateCall(callee, paren, arguments)
        }
    }

    private func evaluateCall(_ callee: Expression, _: Token, _ arguments: [Expression]) -> Result<RuntimeValue, RuntimeError> {
        let calleeResult = evaluate(callee)
        let calleeResultValue: RuntimeValue

        switch calleeResult {
        case let .success(val):
            calleeResultValue = val
        case let .failure(err):
            return .failure(err)
        }

        _ = arguments.map { expr in
            evaluate(expr)
        }
        guard case let RuntimeValue.callable(function) = calleeResultValue else {
            return .failure(.notCallable(callee: calleeResultValue))
        }

        guard arguments.count == function.arity else {
            return .failure(.incorrectArgumentCount(expected: function.arity, actual: arguments.count))
        }

        return .failure(.notImplemented)
//        return function.call(this//intepretter, arguments)
    }

    private func evaluateLogical(_ lhs: Expression, _ op: LogicalOperator, _ rhs: Expression) -> Result<RuntimeValue, RuntimeError> {
        let left: RuntimeValue
        switch evaluate(lhs) {
        case let .success(val):
            left = val
        case let .failure(err):
            return .failure(err)
        }

        switch (op, left.truthy) {
        case (.Or, true):
            return .success(left)
        case (.And, false):
            return .success(left)
        default:
            return evaluate(rhs)
        }
    }

    private func evaluateBinary(_ expr_l: Expression, _ expr_op: Operator, _ expr_r: Expression) -> Result<RuntimeValue, RuntimeError> {
        let leftValue: RuntimeValue
        let rightValue: RuntimeValue
        // check left and right result, if either failed - propagate it
        switch evaluate(expr_l) {
        case let .success(resolvedExpression):
            leftValue = resolvedExpression
        case let .failure(err):
            return .failure(err)
        }

        switch evaluate(expr_r) {
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
                return .success(RuntimeValue.number(leftval - rightval))
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
                return .success(RuntimeValue.number(leftval * rightval))
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
                return .success(RuntimeValue.number(leftval / rightval))
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
                return .success(RuntimeValue.number(leftval + rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't add these types from others"))
            }
        // concatenate the strings
        case let .string(leftval):
            switch rightValue {
            case let .string(rightval):
                return .success(RuntimeValue.string(leftval + rightval))
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
                return .success(RuntimeValue.boolean(leftval < rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
            }
        // compare the strings
        case let .string(leftval):
            switch rightValue {
            case let .string(rightval):
                return .success(RuntimeValue.boolean(leftval < rightval))
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
                return .success(RuntimeValue.boolean(leftval <= rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
            }
        // compare the strings
        case let .string(leftval):
            switch rightValue {
            case let .string(rightval):
                return .success(RuntimeValue.boolean(leftval <= rightval))
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
                return .success(RuntimeValue.boolean(leftval > rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
            }
        // compare the strings
        case let .string(leftval):
            switch rightValue {
            case let .string(rightval):
                return .success(RuntimeValue.boolean(leftval > rightval))
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
                return .success(RuntimeValue.boolean(leftval >= rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
            }
        // compare the strings
        case let .string(leftval):
            switch rightValue {
            case let .string(rightval):
                return .success(RuntimeValue.boolean(leftval >= rightval))
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
                return .success(RuntimeValue.boolean(leftval == rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
            }
        // compare the strings
        case let .string(leftval):
            switch rightValue {
            case let .string(rightval):
                return .success(RuntimeValue.boolean(leftval == rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
            }
        // compare the bools
        case let .boolean(leftval):
            switch rightValue {
            case let .boolean(rightval):
                return .success(RuntimeValue.boolean(leftval == rightval))
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
                return .success(RuntimeValue.boolean(leftval != rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
            }
        // compare the strings
        case let .string(leftval):
            switch rightValue {
            case let .string(rightval):
                return .success(RuntimeValue.boolean(leftval != rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
            }
        // compare the bools
        case let .boolean(leftval):
            switch rightValue {
            case let .boolean(rightval):
                return .success(RuntimeValue.boolean(leftval != rightval))
            default:
                return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
            }
        default:
            return .failure(RuntimeError.typeMismatch(token, message: "can't compare these types"))
        }
    }

    private func evaluateAssign(_ tok: Token, expr: Expression) -> Result<RuntimeValue, RuntimeError> {
        switch evaluate(expr) {
        case let .success(value):
            do {
                try environment.assign(tok, value)
                return .success(RuntimeValue.none)
            } catch {
                return .failure(RuntimeError.undefinedVariable(tok, message: "\(error)"))
            }
        case let .failure(err):
            return .failure(err)
        }
    }

    private func evaluateUnary(_ unary: Unary, expr: Expression) -> Result<RuntimeValue, RuntimeError> {
        let runtimeValue: RuntimeValue
        switch evaluate(expr) {
        case let .success(workingval):
            runtimeValue = workingval
        case let .failure(err):
            return .failure(err)
        }

        switch unary {
        case let .minus(token):
            switch runtimeValue {
            case .boolean(_), .string(_), .callable(_), .none:
                return .failure(RuntimeError.typeMismatch(token, message: "not allowed to 'minus' these types"))
            case let .number(value):
                return .success(RuntimeValue.number(-value))
            }
        case let .not(token):
            switch runtimeValue {
            case .number(_), .string(_), .callable(_), .none:
                return .failure(RuntimeError.typeMismatch(token, message: "not allowed to 'minus' these types"))
            case let .boolean(value):
                return .success(RuntimeValue.boolean(!value))
            }
        }
    }

    private func evaluateGrouping(_ expr: Expression) -> Result<RuntimeValue, RuntimeError> {
        return evaluate(expr)
    }

    private func evaluateVariable(_ token: Token) -> Result<RuntimeValue, RuntimeError> {
        do {
            return .success(try environment.get(token))
        } catch {
            return .failure(RuntimeError.undefinedVariable(token, message: "\(error)"))
        }
    }

    private func evaluateLiteral(_ literal: Literal) -> Result<RuntimeValue, RuntimeError> {
        switch literal {
        case let .number(doubleValue):
            return .success(RuntimeValue.number(doubleValue))
        case let .string(stringValue):
            return .success(RuntimeValue.string(stringValue))
        case .trueToken:
            return .success(RuntimeValue.boolean(true))
        case .falseToken:
            return .success(RuntimeValue.boolean(false))
        case .nilToken:
            return .success(RuntimeValue.none)
        }
    }
}
