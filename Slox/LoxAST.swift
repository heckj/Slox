//
//  LoxAST.swift
//  Slox
//
//  Created by Joseph Heck on 3/6/21.
//

import Foundation

// source material translated from Java in https://craftinginterpreters.com/representing-code.html
// grammar syntax for statements: https://craftinginterpreters.com/statements-and-state.html

/*
 Original grammar, chapter 5:
 Updated grammar, incorporating precedence, Chapter 6
 Updated grammar, identifiers, Chapter 8

  statement      → exprStmt
                 | printStmt
                 | block ;

  block          → "{" declaration* "}" ;

  expression     → assignment ;
  assignment     → IDENTIFIER "=" assignment
                 | equality ;
  equality       → comparison ( ( "!=" | "==" ) comparison )* ;
  comparison     → term ( ( ">" | ">=" | "<" | "<=" ) term )* ;
  term           → factor ( ( "-" | "+" ) factor )* ;
  factor         → unary ( ( "/" | "*" ) unary )* ;
  unary          → ( "!" | "-" ) unary
                 | primary ;
  primary        → "true" | "false" | "nil"
                 | NUMBER | STRING
                 | "(" expression ")"
                 | IDENTIFIER ;
  */

// public indirect enum Program {
//
// }
public indirect enum Statement {
    case expressionStatement(Expression)
    case printStatement(Expression)
    case variable(Token, Expression)
    case block([Statement])
}

public indirect enum Expression: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .literal(exp):
            return "\(exp)"
        case let .unary(unaryexp, exp):
            return "( \(unaryexp) \(exp) )"
        case let .binary(lhs, op, rhs):
            return "( \(op) \(lhs) \(rhs) )"
        case let .grouping(exp):
            return "(group \(exp))"
        case let .variable(tok):
            return "var(\(tok.lexeme))"
        case let .assign(tok, exp):
            return "\(tok.lexeme) = \(exp)"
        }
    }

    case literal(Literal)
    case unary(Unary, Expression)
    case binary(Expression, Operator, Expression)
    case grouping(Expression)
    case variable(Token)
    case assign(Token, Expression)
}

public indirect enum Literal: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .number(value):
            return "\(value.lexeme)"
        case let .string(value):
            return "\(value.lexeme)"
        case .trueToken:
            return "true"
        case .falseToken:
            return "false"
        case .nilToken:
            return "nil"
        }
    }

    case number(Token) // double rather than token?
    case string(Token) // string rather than token?
    case trueToken(Token)
    case falseToken(Token)
    case nilToken(Token)
}

public indirect enum Unary: CustomStringConvertible {
    public var description: String {
        switch self {
        case .minus:
            return "-"
        case .not:
            return "!"
        }
    }

    case minus(Token)
    case not(Token)

    static func fromToken(_ t: Token) throws -> Unary {
        switch t.type {
        case .MINUS:
            return Unary.minus(t)
        case .BANG:
            return Unary.not(t)
        default:
            Lox.error(0, message: "Invalid operator token")
            throw ParserError.invalidUnaryToken(t)
        }
    }
}

public indirect enum Operator: CustomStringConvertible {
    public var description: String {
        switch self {
        case .Equals:
            return "="
        case .NotEquals:
            return "!="
        case .LessThan:
            return "<"
        case .LessThanOrEqual:
            return "<="
        case .GreaterThan:
            return ">"
        case .GreaterThanOrEqual:
            return ">="
        case .Add:
            return "+"
        case .Subtract:
            return "-"
        case .Multiply:
            return "*"
        case .Divide:
            return "/"
        }
    }

    case Equals(Token)
    case NotEquals(Token)
    case LessThan(Token)
    case LessThanOrEqual(Token)
    case GreaterThan(Token)
    case GreaterThanOrEqual(Token)
    case Add(Token)
    case Subtract(Token)
    case Multiply(Token)
    case Divide(Token)

    static func fromToken(_ t: Token) throws -> Operator {
        switch t.type {
        case .EQUAL: return Operator.Equals(t)
        case .MINUS:
            return Operator.Subtract(t)
        case .PLUS:
            return Operator.Add(t)
        case .SLASH:
            return Operator.Divide(t)
        case .STAR:
            return Operator.Multiply(t)
        case .BANG_EQUAL:
            return Operator.NotEquals(t)
        case .EQUAL_EQUAL:
            return Operator.Equals(t)
        case .GREATER:
            return Operator.GreaterThan(t)
        case .GREATER_EQUAL:
            return Operator.GreaterThanOrEqual(t)
        case .LESS:
            return Operator.LessThan(t)
        case .LESS_EQUAL:
            return Operator.LessThanOrEqual(t)
        default:
            Lox.error(0, message: "Invalid operator token")
            throw ParserError.invalidOperatorToken(t)
        }
    }
}

extension Expression {
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

// translated example code, with every AST node having a copy of the token that generated it...
// The more direct example allowed for a Token to be inserted for Operator from the Java code,
// but it's not clear how the underlying data in the AST is used, so I'm hesitant to separate that.
// Otherwise, I think a lot of the tokens could be horribly redundant, and you end up mapping tokens
// into an AST that just includes them.

let expression = Expression.binary(
    Expression.unary(
        .minus(Token(type: .MINUS, lexeme: "-", literal: "-", line: 1)),
        Expression.literal(.number(Token(type: .NUMBER, lexeme: "123", literal: 123, line: 1)))
    ),
    .Multiply(Token(type: .STAR, lexeme: "*", line: 1)),
    Expression.grouping(
        Expression.literal(
            .number(
                Token(type: .NUMBER, lexeme: "45.67", literal: 45.67, line: 1)
            )
        )
    )
)

// prints: ( * ( - NUMBER 123 123.0 ) (group NUMBER 45.67 45.67) )
// ( * ( - 123 ) (group 45.67) ) // using just the lexeme in the token
