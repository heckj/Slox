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
                pass()
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

func pass() {
    // does nothing to allow ignoring a case statement - there's probably a better
    // way of handling this...
}

extension Statement {
    func resolve(_ resolver: Resolver) {
        
    }
}
extension Expression {
    func resolve(_ resolver: Resolver) {
        
    }
}
