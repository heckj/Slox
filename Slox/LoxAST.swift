//
//  LoxAST.swift
//  Slox
//
//  Created by Joseph Heck on 3/6/21.
//

import Foundation

// source material translated from Java in https://craftinginterpreters.com/representing-code.html

/*
 LOX grammar
 expression     → literal
                | unary
                | binary
                | grouping ;

 literal        → NUMBER | STRING | "true" | "false" | "nil" ;
 grouping       → "(" expression ")" ;
 unary          → ( "-" | "!" ) expression ;
 binary         → expression operator expression ;
 operator       → "==" | "!=" | "<" | "<=" | ">" | ">="
                | "+"  | "-"  | "*" | "/" ;
 */

// AST Classes ??? Maybe - translating the Java examples of abstract and final classes with a visitor
// pattern into recursive enumerations in Swift, which smell like they're built for exactly
// this kind of structure.
// NOTE(heckj): I'm not sure if it makes sense to have Token as an associated value for the
// enumeration elements or not. It's needed for NUMBER and STRING, but the rest - unclear.

// Also, I suspect that I can interpret the book's use of the visitor pattern to make "addons" and
// abstract implementations to the Java AST classes using a protocol when we get there... not 100%
// sure though. Or maybe it's just adding an extension using Swift's extension mechanism. The book
// does this with a printing-the-AST/tokens thing

enum GrammarError: Error {
    case invalidOperatorToken(Token)
    case invalidUnaryToken(Token)
}

indirect enum Expression: CustomStringConvertible {
    var description: String {
        switch self {
        case let .literal(exp):
            return "\(exp)"
        case let .unary(type, exp):
            return "( \(type) \(exp) )"
        case let .binary(lhs, op, rhs):
            return "( \(op) \(lhs) \(rhs) )"
        case let .grouping(exp):
            return "(group \(exp))"
        }
    }

    case literal(LiteralExpression)
    case unary(UnaryType, Expression)
    case binary(Expression, OperatorExpression, Expression)
    case grouping(Expression)
}

indirect enum LiteralExpression: CustomStringConvertible {
    var description: String {
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

indirect enum UnaryType: CustomStringConvertible {
    var description: String {
        switch self {
        case .minus:
            return "-"
        case .not:
            return "!"
        }
    }

    case minus(Token)
    case not(Token)

    static func fromToken(_ t: Token) throws -> UnaryType {
        switch t.type {
        case .MINUS:
            return UnaryType.minus(t)
        case .BANG:
            return UnaryType.not(t)
        default:
            Lox.error(0, message: "Invalid operator token")
            throw GrammarError.invalidUnaryToken(t)
        }
    }
}

indirect enum OperatorExpression: CustomStringConvertible {
    var description: String {
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

    static func fromToken(_ t: Token) throws -> OperatorExpression {
        switch t.type {
        case .EQUAL: return OperatorExpression.Equals(t)
        case .MINUS:
            return OperatorExpression.Subtract(t)
        case .PLUS:
            return OperatorExpression.Add(t)
        case .SLASH:
            return OperatorExpression.Divide(t)
        case .STAR:
            return OperatorExpression.Multiply(t)
        case .BANG_EQUAL:
            return OperatorExpression.NotEquals(t)
        case .EQUAL_EQUAL:
            return OperatorExpression.Equals(t)
        case .GREATER:
            return OperatorExpression.GreaterThan(t)
        case .GREATER_EQUAL:
            return OperatorExpression.GreaterThanOrEqual(t)
        case .LESS:
            return OperatorExpression.LessThan(t)
        case .LESS_EQUAL:
            return OperatorExpression.LessThanOrEqual(t)
        default:
            Lox.error(0, message: "Invalid operator token")
            throw GrammarError.invalidOperatorToken(t)
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

/*
  public static void main(String[] args) {
      Expr expression = new Expr.Binary(
          new Expr.Unary(
              new Token(TokenType.MINUS, "-", null, 1),
              new Expr.Literal(123)),
          new Token(TokenType.STAR, "*", null, 1),
          new Expr.Grouping(
              new Expr.Literal(45.67)));

      System.out.println(new AstPrinter().print(expression));
    }

 --- GENERATING:

  (* (- 123) (group 45.67))
 */
