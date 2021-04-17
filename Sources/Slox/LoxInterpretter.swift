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
        case let .klass(value):
            return value.description
        }
    }

    case string(_ value: String)
    case number(_ value: Double)
    case boolean(_ value: Bool)
    case callable(_ value: Callable)
    case klass(_ value: Klass)
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
    var values: [String: RuntimeValue] = [:]
    var enclosing: Environment?

    init(enclosing: Environment? = nil) {
        self.enclosing = enclosing
    }

    public var description: String {
        var strBuild = "["
        for (name, value) in values {
            strBuild += name
            strBuild += ":"
            strBuild += String(describing: value)
        }
        if let enclosedContent = enclosing {
            strBuild += enclosedContent.description
        }
        strBuild += "]"
        return strBuild
    }

    public func define(_ name: String, value: RuntimeValue) {
        // by not checking to see if the name already exists,
        // we support "overwriting it" in the program flow for Lox
        values[name] = value
    }

    public func ancestor(_ distance: Int) -> Environment? {
        var localenv: Environment? = self
        for _ in 0 ..< distance {
            localenv = localenv?.enclosing
        }
        return localenv
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
        print("Attempting to get variable from any level of ancestor.")
        throw RuntimeError.undefinedVariable(name, message: "Undefined variable '\(name.lexeme)'")
    }

    public func getAt(_ distance: Int, _ name: Token) throws -> RuntimeValue {
        if let env = ancestor(distance) {
            if let something = env.values[name.lexeme] {
                return something
            }
        }
        // extra verbose output before we through an error
        print("Attempting to get variable \(name.lexeme) from ancestor at distance: \(distance)")
        print(" .. ENV at distance: \(String(describing: ancestor(distance)))")
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
                // extra verbose output before we through an error
                print("No enclosing environment, so we can't assign the variable: \(name.lexeme)")
                throw RuntimeError.undefinedVariable(name, message: "Undefined variable '\(name.lexeme)'")
            }
        }
        values[name.lexeme] = val
    }

    public func assignAt(_ distance: Int, _ name: Token, _ val: RuntimeValue) throws {
        ancestor(distance)?.values[name.lexeme] = val
    }
}

public struct Callable {
    public let name: String
    let arity: Int
    let call: (Interpretter, [RuntimeValue]) throws -> RuntimeValue
}

public struct Klass {
    let name: String
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
        if omgIndent > 0 {
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
        case let .klass(name, statements):
            try executeKlass(name, statements)
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
        if omgVerbose { indentPrint("> DEFINE VAR \(token) to \(expr)") }

        let val = try evaluate(expr)
        if let distance = locals[expr] {
            if omgVerbose { indentPrint("Assigning \(token.lexeme) to value \(expr) at distance \(distance)") }
            try environment.assignAt(distance, token, val)
            if omgVerbose { indentPrint("updated environment: \(environment)") }
        } else {
            environment.define(token.lexeme, value: val)
            if omgVerbose { indentPrint("updated environment: \(environment)") }
        }
        if omgVerbose { indentPrint("> FINISHING DEFINE VAR \(token) from \(expr)") }
         
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

    private func executeKlass(_ name: Token, _ statements: [Statement]) throws {
        environment.define(name.lexeme, value: .none)
        let klass = Klass(name: name.lexeme)
        try environment.assign(name, RuntimeValue.klass(klass))
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
        if omgVerbose { indentPrint("> updated locals to: \(locals)") }
    }

    // MARK: Evaluate Expressions...

    public func evaluate(_ expr: Expression) throws -> RuntimeValue {
        switch expr {
        case let .literal(literal):
            return evaluateLiteral(literal)
        case let .assign(tok, expr, _):
            return try evaluateAssign(tok, expr: expr)
        case let .unary(unary, expr):
            return try evaluateUnary(unary, expr: expr)
        case let .binary(lhs, op, rhs):
            return try evaluateBinary(lhs, op, rhs)
        case let .grouping(expr):
            return try evaluateGrouping(expr)
        case let .variable(token, _):
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
            try environment.assign(tok, valueToAssign)
            if omgVerbose { indentPrint("> <ENV UPDATED TO \(environment) >") }
            return RuntimeValue.none
        } catch {
            print("Attempting to assign the variable \(tok.lexeme), but it couldn't find one to assign...")
            throw RuntimeError.undefinedVariable(tok, message: "\(error)")
        }
    }

    private func evaluateUnary(_ unary: Unary, expr: Expression) throws -> RuntimeValue {
        let runtimeValue = try evaluate(expr)

        switch unary {
        case let .minus(token):
            switch runtimeValue {
            case .boolean(_), .string(_), .callable(_), .klass(_), .none:
                throw RuntimeError.typeMismatch(token, message: "not allowed to 'minus' these types")
            case let .number(value):
                return RuntimeValue.number(-value)
            }
        case let .not(token):
            switch runtimeValue {
            case .number(_), .string(_), .callable(_), .klass(_), .none:
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
            print("Attempting to look up the variable \(token.lexeme), but it couldn't be found...")
            throw RuntimeError.undefinedVariable(token, message: "\(error)")
        }
    }

    private func lookupVariable(_ expr: Expression, _ name: Token) throws -> RuntimeValue {
        if omgVerbose { indentPrint("Looking up variables for \(expr)")}
        if let distance = locals[expr] {
            if omgVerbose { indentPrint("Found in locals hash at distance: \(distance), resolving from environment: \(environment)")}
            return try environment.getAt(distance, name)
        }
        if omgVerbose { indentPrint("Not found in locals, resolving from the global environment")}
        return try globals.get(name)
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
