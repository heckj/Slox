//
//  LoxResolver.swift
//
//  Created by Joseph Heck on 4/3/21.
//

import Foundation

public class Resolver {
    private var interpretter: Interpretter
    private var scopes: [[String:Bool]] = []
    
    init(interpretter: Interpretter) {
        self.interpretter = interpretter
    }
    
    func resolve(_ stmt: Statement) {
        switch stmt {
        case let .block(stmts):
            beginScope()
            resolve(stmts)
            endScope()
        case let .variable(tok, expr):
            declare(tok) // declare(stmt.name)
            switch expr {
            case .empty:
                return
            default:
                expr.resolve(self)
            }
        case let .function(_, params, statements):
            beginScope()
            for token in params {
                declare(token)
                define(token)
            }
            resolve(statements)
            endScope()
        case let .expressionStatement(expr):
            resolve(expr)
        case let .ifStatement(condition, thenStatement, elseStatement):
            resolve(condition)
            resolve(thenStatement)
            if let stmt = elseStatement {
                resolve(stmt)
            }
        case let .printStatement(expr):
            resolve(expr)
        case let .returnStatement(_, expr):
            if let returnExpr = expr {
                resolve(returnExpr)
            }
        case let .whileStatement(expr, stmt):
            resolve(expr)
            resolve(stmt)
        }
        
        
    }
    
    func resolve(_ expr: Expression) {
        switch expr {
        case let .variable(tok):
            if !scopes.isEmpty && scopes.last?[tok.lexeme] == false {
                Lox.report(line: 0, example: tok.lexeme, message: "Can't read local variable in its own initializer.")
            }
            resolveLocal(expr, tok)
        case let .assign(tok, expr):
            resolve(expr)
            resolveLocal(expr, tok)
        case let .binary(lhs, _, rhs):
            resolve(lhs)
            resolve(rhs)
        case let .call(callee, _, args):
            resolve(callee)
            for arg in args {
                resolve(arg)
            }
        case let .grouping(expr):
            resolve(expr)
        case let .logical(lhs, _, rhs):
            resolve(lhs)
            resolve(rhs)
        case let .unary(_, expr):
            resolve(expr)
        case .literal(_), .empty:
            return
        }
        
        
    }
    
    func resolveLocal(_ expr: Expression, _ name: Token) {
        //scopes.enumerated() // (index, element)
        for (idx, scope) in scopes.enumerated().reversed() {
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
    
    private func declare(_ tok: Token) {
        if scopes.isEmpty { return }
        if var scope = scopes.last {
            scope[tok.lexeme] = false
        }
        //if scopes.last?.keys.contains(tok.lexeme) {
            // error - tok, "Variable with this name already declared in this scope"
            
        //}
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
    func resolve(_ resolver: Resolver) {
        
    }
}
extension Expression {
    func resolve(_ resolver: Resolver) {
        
    }
}
