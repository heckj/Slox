//
//  LoxResolver.swift
//
//  Created by Joseph Heck on 4/3/21.
//

import Foundation

// Chapter 11: Resolving and Binding
// next: https://craftinginterpreters.com/resolving-and-binding.html#invalid-return-errors

public class Resolver {
    var interpretter: Interpretter
    var scopes: [[String: Bool]] = []
    var omgVerbose = false
    var omgIndent = 0

    init(_ interpretter: Interpretter) {
        self.interpretter = interpretter
    }

    private func indentPrint(_ something: String) {
        if omgIndent > 0 {
            for _ in 0 ... omgIndent {
                print(" ", terminator: "")
            }
        }
        print(something)
    }

    func resolve(_ stmt: Statement) throws {
        if omgVerbose { indentPrint("resolving statement: \(stmt)") }
        switch stmt {
        case let .block(stmts):
            beginScope()
            try resolve(stmts)
            endScope()
        case let .variable(tok, expr):
            try declare(tok) // declare(stmt.name)
            switch expr {
            case .empty:
                define(tok)
                return
            default:
                try resolve(expr)
                define(tok)
            }
        case let .function(_, params, statements):
            beginScope()
            for token in params {
                try declare(token)
                define(token)
            }
            try resolve(statements)
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
        if omgVerbose { indentPrint("resolving expression: \(expr)") }
        switch expr {
        case let .variable(tok, _):
            if !scopes.isEmpty, scopes.last?[tok.lexeme] == false {
                if omgVerbose { indentPrint("Attempting to look up \(tok.lexeme) from \(scopes)") }
                throw RuntimeError.readingVarInInitialization(tok, message: "Can't read local variable in its own initializer.")
            }
            resolveLocal(expr, tok)
        case let .assign(tok, expr, _):
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
        if omgVerbose {
            indentPrint("resolveLocal \(expr) \(name)")
            indentPrint("scopes currently: \(scopes)")
        }
        
        for (idx, scope) in scopes.reversed().enumerated() {
            if omgVerbose { indentPrint("checking scope level \(idx) for \(name.lexeme)") }
            if scope.keys.contains(name.lexeme) {
                if omgVerbose { indentPrint("resolving \(expr) through interpreter at distance \(idx).") }
                interpretter.resolve(expr, idx)
            }
        }
    }

    func beginScope() {
        omgIndent += 1
        scopes.append([:])
    }

    func endScope() {
        _ = scopes.popLast()
        omgIndent -= 1
    }

    private func declare(_ tok: Token) throws {
        if scopes.isEmpty {
            if omgVerbose { indentPrint("declare(EMPTY) \(tok)") }
            return
        }
        if omgVerbose { indentPrint("declare(scope) \(tok)") }

        if scopes[scopes.count - 1].keys.contains(tok.lexeme) {
            throw RuntimeError.duplicateVariable(tok, message: "Variable with this name already declared in this scope")
        }

        scopes[scopes.count - 1][tok.lexeme] = false
        if omgVerbose { indentPrint(String(describing: scopes)) }
    }

    private func define(_ tok: Token) {
        if scopes.isEmpty {
            if omgVerbose { indentPrint("define(EMPTY) \(tok)") }
            return
        }
        if omgVerbose { indentPrint("define(scope) \(tok)") }

        scopes[scopes.count - 1][tok.lexeme] = true
    }

    func resolve(_ statements: [Statement]) throws {
        for statement in statements {
            try resolve(statement)
        }
    }
}
