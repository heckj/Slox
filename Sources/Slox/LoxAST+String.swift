//
//  Statement.swift
//  Slox
//
//  Created by Joseph Heck on 3/22/21.
//

import Foundation

extension Expression: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .literal(expr):
            return "\(expr)"
        case let .unary(unaryexpr, expr):
            return "( \(unaryexpr) \(expr) )"
        case let .binary(lhs, op, rhs):
            return "( \(lhs) \(op) \(rhs) )"
        case let .grouping(expr):
            return "(group \(expr))"
        case let .variable(tok, id):
            _ = id.uuidString.prefix(8)
            // if you need to see the "ID" for each variable from the resolver:
//            return "var(\(tok.lexeme):\(id.uuidString.prefix(8)))"
            return "var(\(tok.lexeme))"
        case let .assign(tok, expr, _):
            return "\(tok.lexeme) = \(expr)"
        case let .logical(lhs, op, rhs):
            return "\(lhs) \(op) \(rhs)"
        case let .call(callee, paren, arguments):
            return "\(callee) \(paren) \(arguments)"
        case .empty:
            return "_nil_"
        case let .get(expr, name):
            return "\(expr).GET(\(name))"
        case let .set(obj, name, value):
            return "\(obj).\(name) = \(value)"
        }
    }
}

extension Operator: CustomStringConvertible {
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
}

extension LogicalOperator: CustomStringConvertible {
    public var description: String {
        switch self {
        case .And:
            return "AND"
        case .Or:
            return "OR"
        }
    }
}

extension Unary: CustomStringConvertible {
    public var description: String {
        switch self {
        case .minus:
            return "-"
        case .not:
            return "!"
        }
    }
}

extension Literal: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .number(value):
            return "\(value)"
        case let .string(value):
            return "\(value)"
        case .trueToken:
            return "true"
        case .falseToken:
            return "false"
        case .nilToken:
            return "nil"
        }
    }
}

extension Statement: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .block(statements):
            return "{ \(statements) }"
        case let .expressionStatement(expr):
            return "STMT<\(expr)>"
        case let .function(name, params, _):
            return "FN<\(name):\(params.count)>"
        case let .printStatement(expr):
            return "PRINT(\(expr))"
        case let .variable(ident, expr):
            return "VAR(\(ident)):(\(expr))"
        case let .ifStatement(ifExpr, thenStmt, elseStmt):
            return "IF(\(ifExpr)) THEN {\(thenStmt)} ELSE {\(String(describing: elseStmt))}"
        case let .whileStatement(expr, stmt):
            return "WHILE(\(expr)) {\(stmt)}"
        case let .returnStatement(_, expr):
            if let expr = expr {
                return "RETURN \(expr)"
            }
            return "RETURN none"
        case let .klass(name, statements):
            return "KLASS(\(name))(\(statements))"
        }
    }
}
