//
//  LoxResolver.swift
//
//  Created by Joseph Heck on 4/3/21.
//

import Foundation

// Chapter 11: Resolving and Binding
// next: https://craftinginterpreters.com/resolving-and-binding.html#invalid-return-errors

public class Resolver {
    private var interpretter: Interpretter
    private var scopes: [[String: Bool]] = []

    init(interpretter: Interpretter) {
        self.interpretter = interpretter
    }

    func resolve(_ stmt: Statement) throws {
        switch stmt {
        case let .block(stmts):
            beginScope()
            resolve(stmts)
            endScope()
        case let .variable(tok, expr):
            try declare(tok) // declare(stmt.name)
            switch expr {
            case .empty:
                return
            default:
                expr.resolve(self)
            }
        case let .function(_, params, statements):
            beginScope()
            for token in params {
                try declare(token)
                define(token)
            }
            resolve(statements)
            endScope()
        case let .expressionStatement(expr):
            try resolve(expr)
        case let .ifStatement(condition, thenStatement, elseStatement):
            try resolve(condition)
            try resolve(thenStatement)
            if let stmt = elseStatement {
                try resolve(stmt)
            }
        case let .printStatement(expr):
            try resolve(expr)
        case let .returnStatement(_, expr):
            if let returnExpr = expr {
                try resolve(returnExpr)
            }
        case let .whileStatement(expr, stmt):
            try resolve(expr)
            try resolve(stmt)
        }
    }

    func resolve(_ expr: Expression) throws {
        switch expr {
        case let .variable(tok):
            if !scopes.isEmpty, scopes.last?[tok.lexeme] == false {
                throw RuntimeError.duplicateVariable(tok, message: "Can't read local variable in its own initializer.")
            }
            resolveLocal(expr, tok)
        case let .assign(tok, expr):
            try resolve(expr)
            resolveLocal(expr, tok)
        case let .binary(lhs, _, rhs):
            try resolve(lhs)
            try resolve(rhs)
        case let .call(callee, _, args):
            try resolve(callee)
            for arg in args {
                try resolve(arg)
            }
        case let .grouping(expr):
            try resolve(expr)
        case let .logical(lhs, _, rhs):
            try resolve(lhs)
            try resolve(rhs)
        case let .unary(_, expr):
            try resolve(expr)
        case .literal(_), .empty:
            return
        }
    }

    func resolveLocal(_ expr: Expression, _ name: Token) {
        // scopes.enumerated() // (index, element)
        for (idx, _) in scopes.enumerated().reversed() {
            if scopes[idx].keys.contains(name.lexeme) {
                interpretter.resolve(expr, idx)
            }
        }
    }

    func beginScope() {
        scopes.append([:])
    }

    func endScope() {
        _ = scopes.popLast()
    }

    private func declare(_ tok: Token) throws {
        if scopes.isEmpty { return }
        if var scope = scopes.last {
            if scope.keys.contains(tok.lexeme) {
                throw RuntimeError.duplicateVariable(tok, message: "Variable with this name already declared in this scope")
            }
            scope[tok.lexeme] = false
        }
    }

    private func define(_ tok: Token) {
        if scopes.isEmpty { return }
        if var scope = scopes.last {
            scope[tok.lexeme] = true
        }
    }

    func resolve(_ statements: [Statement]) {
        for statement in statements {
            statement.resolve(self)
        }
    }
}

extension Statement {
    func resolve(_: Resolver) {}
}

extension Expression {
    func resolve(_: Resolver) {}
}
