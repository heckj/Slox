//
//  LoxInterpretter.swift
//  Slox
//
//  Created by Joseph Heck on 3/7/21.
//

// Other versions of this in swift that are worth looking at for comparsions:
// * [alexito4/slox](https://github.com/alexito4/slox)
// * [eirikvaa/slox](https://github.com/eirikvaa/slox)
// * [danielctull/slox](https://github.com/danielctull/lox)
// * [hashemi/bslox](https://github.com/hashemi/bslox) (bytecode)
// * [hashemi/slox](https://github.com/hashemi/slox)

// Chapter 7: https://craftinginterpreters.com/evaluating-expressions.html
// Chapter 8: https://craftinginterpreters.com/statements-and-state.html
// Chapter 9: https://craftinginterpreters.com/control-flow.html
// Chapter 10: https://craftinginterpreters.com/functions.html
// Chapter 11: https://craftinginterpreters.com/resolving-and-binding.html (PENDING)

import Foundation

public enum RuntimeError: Error {
    // Interpreter Errors
    case notImplemented
    case typeMismatch(_ token: Token, message: String = "")
    case undefinedVariable(_ token: Token, message: String = "")
    case notCallable(callee: RuntimeValue)
    case incorrectArgumentCount(expected: Int, actual: Int)
    case unexpectedNullValue
    // Resolver Errors
    case readingVarInInitialization(_ token: Token, message: String = "")
    case duplicateVariable(_ token: Token, message: String = "")
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

// MARK: Internal Interpretter Data Structures

public final class Environment: CustomStringConvertible {
    var stack: [Scope]

    // internal wrapper class around the dictionary in
    // order to get reference semantics, which ends up being
    // important for the resolver.
    final class Scope: CustomStringConvertible {
        private var values: [String:RuntimeValue] = [:]
        subscript(index: String) -> RuntimeValue? {
            get {
                return values[index]
            }
            set(newValue) {
                values[index] = newValue
            }
        }
        var description: String {
            var strBuild = "["
            for (name, value) in values {
                strBuild += name
                strBuild += ":"
                strBuild += String(describing: value)
            }
            strBuild += "]"
            return strBuild
        }
        var count: Int {
            return values.count
        }
    }
    
    init(enclosing: Environment? = nil) {
        if let enclosing = enclosing {
            var newStack = enclosing.stack
            newStack.append(Scope())
            self.stack = newStack
            // why not self.stack = enclosing.stack.append(Scope())?
        } else {
            self.stack = [Scope()]
        }
    }

    public var description: String {
        return stack.map { $0.description }.joined()
    }

    public func define(_ name: String, value: RuntimeValue) {
        // by not checking to see if the name already exists,
        // we support "overwriting it" in the program flow for Lox
        stack[stack.count - 1][name] = value
    }

    public func testGet(_ name: String) -> RuntimeValue? {
        // Look/recurse through any sets of enclosing environments to see
        // if the variable is defined there.
        for (_,scope) in stack.reversed().enumerated() {
            if let foundValue = scope[name] {
                return foundValue
            }
        }
        return nil
    }
    
    public func testCount() -> Int {
        return stack.map { $0.count }.reduce(0) { $0 + $1 }
    }

    public func getAt(_ distance: Int, _ name: Token) throws -> RuntimeValue {
        if let foundValue = stack[stack.count - 1 - distance][name.lexeme] {
            return foundValue
        }
        // might need to move this throw into the code accessing it
        // if we want to pass back an optional RuntimeValue...
        throw RuntimeError.undefinedVariable(name, message: "Undefined variable '\(name.lexeme)'")
    }

//    public func assign(_ name: String, _ val: RuntimeValue) throws {
//        // Look/recurse through any sets of enclosing environments to see
//        // if the variable is defined there, starting with the last
//        // scope and working forward in the stack.
//        for (_,scope) in stack.reversed().enumerated() {
//            if let _ = scope[name] {
//                scope[name] = val
//                return
//            }
//        }
//        // No enclosing environment, so we can't assign the variable - it was
//        // never defined, so we bail out here.
//        throw RuntimeError.undefinedVariable(name, message: "Undefined variable '\(name)'")
//    }

    public func assignAt(_ distance: Int, _ name: Token, _ val: RuntimeValue) throws {
        guard stack[stack.count - 1 - distance][name.lexeme] != nil else {
            throw RuntimeError.undefinedVariable(name, message: "Undefined variable '\(name.lexeme)'")
        }
        stack[stack.count - 1 - distance][name.lexeme] = val
    }
}

public struct Callable {
    public let name: String
    let arity: Int
    let call: (Interpretter, [RuntimeValue]) throws -> RuntimeValue
}

private struct Return: Error {
    let value: RuntimeValue
}

// MARK: Interpretter

public class Interpretter {
    let globals: Environment
    var environment: Environment
    var locals: [Expression: Int] = [:] // side table looking up expressions with distance
    var tickerTape: [String]?
    var omgVerbose = false // turns on incredible verbose debugging output
    var omgIndent = 0

    private func indentPrint(_ something: String) {
        if (omgIndent > 0) {
            for _ in 0 ... omgIndent {
                print(" ", terminator: "")
            }
        }
        print(something)
    }

    init(collectOutput: Bool = false) {
        globals = Environment()
        globals.define("clock",
                       value: .callable(
                           Callable(name: "clock",
                                    arity: 0,
                                    call: {
                                        (_, _) -> RuntimeValue in
                                        RuntimeValue.number(Date().timeIntervalSince1970)
                                    })
                       ))
        environment = globals
        if collectOutput {
            tickerTape = []
        }
    }

    public func interpretStatements(_ statements: [Statement]) throws {
        if omgVerbose { indentPrint("=== EXECUTING \(statements.count) STATEMENTS ===") }
        if omgVerbose { indentPrint("=== ENV[\(environment)]") }
        if omgVerbose { omgIndent += 1 }
        for statement in statements {
            // if omgVerbose { indentPrint ("<EXEC STMT> \(statement)") }
            try execute(statement)
        }
        if omgVerbose { omgIndent -= 1 }
        if omgVerbose { indentPrint("=== END BLOCK ===") }
    }

    private func execute(_ statement: Statement) throws {
        switch statement {
        case let .ifStatement(condition, thenBranch, elseBranch):
            try executeIf(condition, thenStmt: thenBranch, elseStmt: elseBranch)
        case let .printStatement(expr):
            try executePrint(expr)
        case let .variable(token, expr):
            try executeVariableAssignment(token, expr)
        case let .block(statements):
            try executeBlock(statements, using: Environment(enclosing: environment))
        case let .expressionStatement(expr):
            try executeExpression(expr)
        case let .whileStatement(condition, body):
            try executeWhile(condition, body)
        case let .function(name, params, body):
            try executeFunction(name, params, body)
        case let .returnStatement(keyword, optExpr):
            try executeReturn(keyword, optExpr)
        }
    }

    private func executeIf(_ condition: Expression, thenStmt: Statement, elseStmt: Statement?) throws {
        if omgVerbose { indentPrint("executeIf(\(condition),\(thenStmt),\(String(describing: elseStmt))") }
        if omgVerbose { indentPrint("> IF \(condition)") }
        let value = try evaluate(condition)
        if omgVerbose { omgIndent += 1 }
        defer {
            if omgVerbose { omgIndent -= 1 }
        }
        if value.truthy {
            if omgVerbose { indentPrint("> TRUE") }
            try execute(thenStmt)
        } else {
            if omgVerbose { indentPrint("> FALSE") }
            if let elseStatement = elseStmt {
                try execute(elseStatement)
            }
        }
    }

    private func executePrint(_ expr: Expression) throws {
        if omgVerbose { indentPrint("executePrint(\(expr)") }
        if omgVerbose { indentPrint("> EVALUATE \(expr) TO PRINT") }
        let runtimevalue = try evaluate(expr)
        if omgVerbose { indentPrint("> PRINT \(runtimevalue)") }
        if tickerTape != nil {
            tickerTape?.append(String(describing: runtimevalue))
        } else {
            print(runtimevalue)
        }
    }

    private func executeVariableAssignment(_ token: Token, _ expr: Expression) throws {
        if omgVerbose { indentPrint("> DEFINE VAR \(token)") }

        let val = try evaluate(expr)
        if let distance = locals[expr] {
            try environment.assignAt(distance, token, val)
        }
        // environment.define(token.lexeme, value: val)
    }

    private func executeBlock(_ statements: [Statement], using: Environment) throws {
        // if omgVerbose { indentPrint("executeBlock(\(statements), using: \(using)") }
        // if omgVerbose { indentPrint("> BLOCK w/ \(environment)") }
        let previous = environment
        defer {
            if omgVerbose { indentPrint("> REVERTING ENV TO \(previous)") }
            self.environment = previous
        }
        if omgVerbose { indentPrint("> SETTING ENV TO \(using)") }
        environment = using
        try interpretStatements(statements)
        // if omgVerbose { indentPrint("> BLOCK COMPLETE w/ \(environment)") }
    }

    private func executeExpression(_ expr: Expression) throws {
        // if omgVerbose { indentPrint("executeExpression(\(expr))") }
        if omgVerbose { indentPrint("> <EVALUATING: \(expr) >"); omgIndent += 1 }
        defer {
            if omgVerbose { omgIndent -= 1 }
        }
        let result = try evaluate(expr)
        if omgVerbose { indentPrint("> <RESULT: \(result) >") }
    }

    private func executeWhile(_ cond: Expression, _ body: Statement) throws {
        if omgVerbose { indentPrint("executeWhile(\(cond),\(body))") }
        // if omgVerbose { indentPrint("> WHILE LOOP"); omgIndent += 1 }
        defer {
            if omgVerbose { omgIndent -= 1 }
        }
        while try evaluate(cond).truthy {
            try execute(body)
        }
    }

    private func executeFunction(_ name: Token, _ params: [Token], _ body: [Statement]) throws {
        if omgVerbose { indentPrint("executeFunction(\(name),\(params),\(body)") }
        // if omgVerbose { indentPrint("> FUNCTION CALL \(name) w/ \(params)"); omgIndent += 2 }
        defer {
            if omgVerbose { omgIndent -= 2 }
        }

        let function = Callable(name: name.lexeme, arity: params.count) { (_: Interpretter, arguments: [RuntimeValue]) -> RuntimeValue in
            let closureEnv = Environment(enclosing: self.globals)
            // pair up the parameter names (variables) and arguments (values) and write them
            // into the environment created for executing this function.
            // if self.omgVerbose { self.indentPrint("> SETTING UP FUNCTION over \(closureEnv) with args \(arguments)") }
            for (parameter, argument) in zip(params, arguments) {
                // if self.omgVerbose { self.indentPrint("> ENV ADDING: \(parameter.lexeme) : \(argument)") }
                closureEnv.define(parameter.lexeme, value: argument)
            }
            do {
                // if self.omgVerbose { self.indentPrint("> UPDATED FUNCTION CALL ENV of \(closureEnv)") }
                try self.executeBlock(body, using: closureEnv)
            } catch let returnError as Return {
                return returnError.value
            }
            return .none
        }
        environment.define(name.lexeme, value: RuntimeValue.callable(function))
    }

    private func executeReturn(_: Token, _ expr: Expression?) throws {
        // if omgVerbose { indentPrint("executeReturn(\(token),\(String(describing: expr)))") }
        if let expr = expr {
            let value = try evaluate(expr)
            if omgVerbose { indentPrint("> RETURN \(value)") }
            throw Return(value: value)
        } else {
            if omgVerbose { indentPrint("> RETURN \(RuntimeValue.none)") }
            throw Return(value: RuntimeValue.none)
        }
    }

    func resolve(_ expr: Expression, _ depth: Int) {
        if omgVerbose { indentPrint("> resolving \(expr) against \(locals)") }
        locals[expr] = depth
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
            return try evaluateVariable(expr, token)
        case .empty:
            return RuntimeValue.none
        case let .logical(lhs, op, rhs):
            return try evaluateLogical(lhs, op, rhs)
        case let .call(callee, paren, arguments):
            return try evaluateCall(callee, paren, arguments)
        }
    }

    private func evaluateCall(_ callee: Expression, _ token: Token, _ arguments: [Expression]) throws -> RuntimeValue {
        if omgVerbose { indentPrint("evaluateCall(\(callee),\(token),\(arguments)") }
        // if omgVerbose { indentPrint("> <FUNCTION CALL: \(callee) w/ args \(arguments)>"); omgIndent += 1 }
        defer {
            if omgVerbose { omgIndent -= 1 }
        }

        let calleeResultValue: RuntimeValue = try evaluate(callee)
        if omgVerbose { indentPrint("> DETERMINING ARGUMENT VALUES FOR FUNCTION CALL w/ \(environment)") }
        let argumentValues = try arguments.map { expr -> RuntimeValue in
            try evaluate(expr)
        }
        if omgVerbose { indentPrint("> FUNCTION ARGUMENT VALUES: \(argumentValues)") }
//        if omgVerbose { indentPrint ("> VERIFY FUNCTION IS CALLABLE") }
        guard case let RuntimeValue.callable(function) = calleeResultValue else {
            throw RuntimeError.notCallable(callee: calleeResultValue)
        }

//        if omgVerbose { indentPrint ("> VERIFY FUNCTION ARITY") }
        guard arguments.count == function.arity else {
            throw RuntimeError.incorrectArgumentCount(expected: function.arity, actual: arguments.count)
        }

        // if omgVerbose { indentPrint("> call w/ \(environment)") }
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
            let valueToAssign = try evaluate(expr)
            try environment.assignAt(0, tok, valueToAssign)
            if omgVerbose { indentPrint("> <ENV UPDATED TO \(environment) >") }
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

    private func evaluateVariable(_ expr: Expression, _ token: Token) throws -> RuntimeValue {
        do {
            // if omgVerbose { indentPrint ("> <ENV GET \(token) <- \(value) >") }
            return try lookupVariable(expr, token)
        } catch {
            throw RuntimeError.undefinedVariable(token, message: "\(error)")
        }
    }

    private func lookupVariable(_ expr: Expression, _ name: Token) throws -> RuntimeValue {
        if let distance = locals[expr] {
            return try environment.getAt(distance, name)
        }
        return try globals.getAt(0, name)
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
