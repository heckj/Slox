//
//  Lox.swift
//  Slox
//
//  Created by Joseph Heck on 3/2/21.
//

import Darwin
import Foundation

// translated through https://craftinginterpreters.com/scanning.html#longer-lexemes (Section 4.6)

extension Character {
    var isIdentifier: Bool {
        return isLetter || self == "_"
    }
}

enum TokenType {
    // single-character tokens
    case LEFT_PAREN, RIGHT_PAREN
    case LEFT_BRACE, RIGHT_BRACE
    case COMMA
    case DOT
    case MINUS
    case PLUS
    case SEMICOLON
    case SLASH
    case STAR

    // one or two-character tokens
    case BANG, BANG_EQUAL
    case EQUAL, EQUAL_EQUAL
    case GREATER, GREATER_EQUAL
    case LESS, LESS_EQUAL

    // Literals
    case IDENTIFIER, STRING, NUMBER

    // Keywords
    case AND, CLASS, ELSE, FALSE, FUN, FOR, IF, NIL
    case OR, PRINT, RETURN, SUPER, THIS, TRUE, VAR, WHILE

    case EOF
}

let reservedWords: [String: TokenType] = ["and": TokenType.AND,
                                          "class": TokenType.CLASS,
                                          "else": TokenType.ELSE,
                                          "false": TokenType.FALSE,
                                          "for": TokenType.FOR,
                                          "fun": TokenType.FUN,
                                          "if": TokenType.IF,
                                          "nil": TokenType.NIL,
                                          "or": TokenType.OR,
                                          "print": TokenType.PRINT,
                                          "return": TokenType.RETURN,
                                          "super": TokenType.SUPER,
                                          "this": TokenType.THIS,
                                          "true": TokenType.TRUE,
                                          "var": TokenType.VAR,
                                          "while": TokenType.WHILE]
enum LiteralType {
    // The rough equivalent of a Union for swift - a literal is one of these kinds of things,
    // but I didn't want to store each option in the Token class directly, nor make the Token class
    // into an enumeration itself.
    case string(value: String)
    case number(value: Double)
    case none
}

final class Token: CustomStringConvertible {
    let type: TokenType
    let lexeme: String
    let literal: LiteralType
    let line: Int
    var description: String {
        switch literal {
        case let .number(value):
            return "\(type) \(lexeme) \(value)"
        case let .string(value):
            return "\(type) \(lexeme) \(value)"
        case .none:
            return "\(type) \(lexeme)"
        }
    }

    init(type: TokenType, lexeme: String, literal: String, line: Int) {
        self.type = type
        self.lexeme = lexeme
        self.literal = LiteralType.string(value: literal)
        self.line = line
    }

    init(type: TokenType, lexeme: String, literal: Double, line: Int) {
        self.type = type
        self.lexeme = lexeme
        self.literal = LiteralType.number(value: literal)
        self.line = line
    }

    init(type: TokenType, lexeme: String, line: Int) {
        self.type = type
        self.lexeme = lexeme
        literal = LiteralType.none
        self.line = line
    }
}

final class Scanner {
    var source: String
    var tokens: [Token] = []

    private var start: String.Index
    private var current: String.Index
    private var line: Int = 1

    init(_ source: String) {
        self.source = source
        start = source.startIndex
        current = start
    }

    func scanTokens() -> [Token] {
        while !isAtEnd() {
            start = current
            scanToken()
        }

        tokens.append(Token(type: .EOF, lexeme: "", line: line))
        return tokens
    }

    private func isAtEnd() -> Bool {
        return current >= source.endIndex
    }

    private func advance() -> Character {
        let nextIndexPosition = source.index(after: current)
        current = nextIndexPosition
        let char: Character = source[current]
        return char
    }

    private func peek() -> Character {
        // single character "look ahead" function
        if isAtEnd() {
            return "\0" // unicode NUL character
        }
        return source[current]
    }

    private func peekNext() -> Character {
        // double character "look ahead" function
        let nextIndex: String.Index = source.index(after: current)
        if isAtEnd() || (nextIndex >= source.endIndex) {
            return "\0" // unicode NUL character
        }
        return source[nextIndex]
    }

    private func string() {
        // increment the cursor to find the bounds of the string
        while peek() != "\"", !isAtEnd() {
            if peek() == "\n" { line += 1 }
            _ = advance()
        }
        if isAtEnd() {
            Lox.error(line, message: "Unterminated string.")
            return
        }

        // The closing " character
        _ = advance()
        let value = source[source.index(after: start) ... source.index(before: current)]
        addToken(TokenType.STRING, literal: String(value))
    }

    private func number() {
        // increment the cursor to find the bounds of the number
        while peek().isNumber {
            _ = advance()
        }
        if (peek() == ".") && peekNext().isNumber {
            // Consume the '.'
            _ = advance()
            while peek().isNumber {
                _ = advance()
            }
        }
        guard let value = Double(source[start ... current]) else {
            Lox.error(line, message: "Unexpected error parsing a number from \(source[start ... current]).")
            return
        }
        addToken(TokenType.NUMBER, literal: value)
    }

    private func identifier() {
        // increment the cursor to find the bounds of the identifier
        while peek().isIdentifier {
            _ = advance()
        }
        let text = source[start ... current]
        if let type = reservedWords[String(text)] {
            addToken(type)
        }
        addToken(.IDENTIFIER)
    }

    private func scanToken() {
        let char: Character = advance()
        switch char {
        case "(": addToken(.LEFT_PAREN)
        case ")": addToken(.RIGHT_PAREN)
        case "{": addToken(.LEFT_BRACE)
        case "}": addToken(.RIGHT_BRACE)
        case ",": addToken(.COMMA)
        case ".": addToken(.DOT)
        case "-": addToken(.MINUS)
        case "+": addToken(.PLUS)
        case ";": addToken(.SEMICOLON)
        case "*": addToken(.STAR)
        case "!": addToken(match("=") ? .BANG_EQUAL : .BANG)
        case "=": addToken(match("=") ? .EQUAL_EQUAL : .EQUAL)
        case "<": addToken(match("=") ? .LESS_EQUAL : .LESS)
        case ">": addToken(match("=") ? .GREATER_EQUAL : .GREATER)
        case "/": if match("/") {
                // represents a comment - ignored content until the end of the line
                while (!peek().isNewline) && !isAtEnd() {
                    _ = advance()
                }
            } else {
                addToken(.SLASH)
            }
        case " ", "\r", "\t": break
        case "\n": line += 1
        case "\"": string()
        default:
            if char.isNumber {
                number()
            } else if char.isLetter {
                identifier()
            } else {
                Lox.error(line, message: "Unexpected character.")
            }
        }
    }

    private func addToken(_ type: TokenType) {
        let text = source[start ... current]
        tokens.append(Token(type: type, lexeme: String(text), line: line))
    }

    private func addToken(_ type: TokenType, literal: String) {
        let text = source[start ... current]
        tokens.append(Token(type: type, lexeme: String(text), literal: literal, line: line))
    }

    private func addToken(_ type: TokenType, literal: Double) {
        let text = source[start ... current]
        tokens.append(Token(type: type, lexeme: String(text), literal: literal, line: line))
    }

    private func match(_ expected: Character) -> Bool {
        if isAtEnd() {
            return false
        }
        if source[current] != expected { return false }
        // it matches, so advance the index position
        current = source.index(after: current)
        return true
    }
}

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

// from TSPL LanguageGuide
// indirect enum ArithmeticExpression {
//    case number(Int)
//    case addition(ArithmeticExpression, ArithmeticExpression)
//    case multiplication(ArithmeticExpression, ArithmeticExpression)
// }

// AST Classes ??? Maybe - translating the Java examples of abstract and final classes with a visitor
// pattern into recursive enumerations in Swift, which smell like they're built for exactly
// this kind of structure.
// NOTE(heckj): I'm not sure if it makes sense to have Token as an associated value for the
// enumeration elements or not. It's needed for NUMBER and STRING, but the rest - unclear.

// Also, I suspect that I can interpret the book's use of the visitor pattern to make "addons" and
// abstract implementations to the Java AST classes using a protocol when we get there... not 100%
// sure though. Or maybe it's just adding an extension using Swift's extension mechanism. The book
// does this with a printing-the-AST/tokens thing

/*
  let x = Expression.binary(Expression.Unary(),Expression.literal(.number(Token("12")))
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

 --- USING ::

  class AstPrinter implements Expr.Visitor<String> {
    String print(Expr expr) {
      return expr.accept(this);
    }
  }
  @Override
    public String visitBinaryExpr(Expr.Binary expr) {
      return parenthesize(expr.operator.lexeme,
                          expr.left, expr.right);
    }

    @Override
    public String visitGroupingExpr(Expr.Grouping expr) {
      return parenthesize("group", expr.expression);
    }

    @Override
    public String visitLiteralExpr(Expr.Literal expr) {
      if (expr.value == null) return "nil";
      return expr.value.toString();
    }

    @Override
    public String visitUnaryExpr(Expr.Unary expr) {
      return parenthesize(expr.operator.lexeme, expr.right);
    }
  private String parenthesize(String name, Expr... exprs) {
      StringBuilder builder = new StringBuilder();

      builder.append("(").append(name);
      for (Expr expr : exprs) {
        builder.append(" ");
        builder.append(expr.accept(this));
      }
      builder.append(")");

      return builder.toString();
    }
  */

indirect enum Expression {
    case literal(LiteralExpression)
    case unary(UnaryType, Expression)
    case binary(Expression, OperatorExpression, Expression)
    case grouping(Expression)
}

indirect enum LiteralExpression {
    case number(Token)
    case string(Token)
    case trueToken(Token)
    case falseToken(Token)
    case nilToken(Token)
}

indirect enum UnaryType {
    case minus(Token)
    case not(Token)
}

indirect enum OperatorExpression {
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
}

let x = Expression.unary(
    .minus(Token(type: .MINUS, lexeme: "-", literal: "-", line: 1)),
    Expression.literal(.number(Token(type: .NUMBER, lexeme: "123", literal: 123, line: 1)))
)
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

public enum Lox {
    static var hadError: Bool = false
    public static func main(args: [String]) throws {
        if args.count > 1 {
            print("Usage: slox [script]")
            exit(64)
        } else if args.count == 1 {
            try runFile(args[0])
        } else {
            try runPrompt()
        }
    }

    static func runFile(_ path: String) throws {
        let contents = try String(contentsOfFile: path, encoding: .utf8)
        run(contents)
        if hadError {
            exit(65)
        }
    }

    static func runPrompt() throws {
        while true {
            print("> ", terminator: "")
            if let interactiveString = readLine(strippingNewline: true) {
                run(interactiveString)
                hadError = false
            }
        }
    }

    static func run(_ source: String) {
        let tokenlist = source.components(separatedBy: .whitespacesAndNewlines)
        for token in tokenlist {
            print(token)
        }
    }

    public static func error(_ line: Int, message: String) {
        report(line: line, example: "", message: message)
    }

    static func report(line: Int, example: String, message: String) {
        print("[\(line)] Error \(example): \(message)")
        hadError = true
    }
}
