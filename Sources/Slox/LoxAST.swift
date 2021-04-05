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
 Updated grammar, statements, identifiers, and state, Chapter 8
 Updated grammer, control flow, Chapter 9

  program        → statement* EOF ;

  declaration    → funDecl
                 | varDecl
                 | statement ;
  funDecl        → "fun" function ;
  function       → IDENTIFIER "(" parameters? ")" block ;
  parameters     → IDENTIFIER ( "," IDENTIFIER )* ;

  statement      → exprStmt
                 | forStmt
                 | ifStmt
                 | printStmt
                 | returnStmt
                 | whileStmt
                 | block ;

  forStmt        → "for" "(" ( varDecl | exprStmt | ";" )
                   expression? ";"
                   expression? ")" statement ;
  ifStmt         → "if" "(" expression ")" statement
                 ( "else" statement )? ;
  exprStmt       → expression ";" ;
  printStmt      → "print" expression ";" ;
  returnStmt     → "return" expression? ";" ;
  whileStmt      → "while" "(" expression ")" statement ;
  block          → "{" declaration* "}" ;

  expression     → assignment ;
  assignment     → IDENTIFIER "=" assignment
                 | logic_or ;
  logic_or       → logic_and ( "or" logic_and )* ;
  logic_and      → equality ( "and" equality )* ;
  equality       → comparison ( ( "!=" | "==" ) comparison )* ;
  comparison     → term ( ( ">" | ">=" | "<" | "<=" ) term )* ;
  term           → factor ( ( "-" | "+" ) factor )* ;
  factor         → unary ( ( "/" | "*" ) unary )* ;
  unary          → ( "!" | "-" ) unary | call ;
  call           → primary ( "(" arguments? ")" )* ;
  arguments      → expression ( "," expression )* ;
  primary        → "true" | "false" | "nil"
                 | NUMBER | STRING
                 | "(" expression ")"
                 | IDENTIFIER ;
  */

public indirect enum Statement {
    case expressionStatement(Expression)
    case function(Token, [Token], [Statement])
    case printStatement(Expression)
    case returnStatement(Token, Expression?)
    case variable(Token, Expression)
    case block([Statement])
    case ifStatement(Expression, Statement, Statement?)
    case whileStatement(Expression, Statement)
}

public indirect enum Expression: Hashable {
    case literal(Literal)
    case logical(Expression, LogicalOperator, Expression)
    case unary(Unary, Expression)
    case binary(Expression, Operator, Expression)
    case call(Expression, Token, [Expression])
    case grouping(Expression)
    case variable(Token, UUID)
    case assign(Token, Expression, UUID)
    case empty
}

// NOTE(heckj): the whole slipping in a UUID for the variable and assign
// expressions is a hack. Following Chapter 11, I added a variable
// resolution mechanism that tracks declaration and assignment, and is used
// to capture a side-field hash table of expression -> distance back up the
// enclosing environments. However, the expression doesn't actually end up
// being properly hashable with the addition of data to perturb the hash value,
// and since it's only used on `variable` and `assign`, I've only shimmed in
// a UUID to those two values. The java source relied on classes and Java
// object ID's for hashing, which isn't replicated with the swift Struct/Enum
// setup that I've created here. In hindsight, encoding that distance value
// into the explicit expression, and making the internals a struct, would
// make quite a bit more sense (and appears to be what Hashemi did in his
// implementation).

public indirect enum Unary: Hashable {
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

public indirect enum LogicalOperator: Hashable {
    case And(Token)
    case Or(Token)

    static func fromToken(_ t: Token) throws -> LogicalOperator {
        switch t.type {
        case .AND:
            return LogicalOperator.And(t)
        case .OR:
            return LogicalOperator.Or(t)
        default:
            Lox.error(0, message: "Invalid operator token")
            throw ParserError.invalidOperatorToken(t)
        }
    }
}

public indirect enum Operator: Hashable {
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

public indirect enum Literal: Hashable {
    case number(Double) // double rather than token?
    case string(String) // string rather than token?
    case trueToken
    case falseToken
    case nilToken
}

// translated example code, with every AST node having a copy of the token that generated it...
// The more direct example allowed for a Token to be inserted for Operator from the Java code,
// but it's not clear how the underlying data in the AST is used, so I'm hesitant to separate that.
// Otherwise, I think a lot of the tokens could be horribly redundant, and you end up mapping tokens
// into an AST that just includes them.

let expression = Expression.binary(
    Expression.unary(
        .minus(Token(type: .MINUS, lexeme: "-", literal: "-", line: 1)),
        Expression.literal(.number(123))
    ),
    .Multiply(Token(type: .STAR, lexeme: "*", line: 1)),
    Expression.grouping(
        Expression.literal(
            .number(45.67)
        )
    )
)

// prints: ( * ( - NUMBER 123 123.0 ) (group NUMBER 45.67 45.67) )
// ( * ( - 123 ) (group 45.67) ) // using just the lexeme in the token
