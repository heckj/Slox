//
//  Lox.swift
//  Slox
//
//  Created by Joseph Heck on 3/2/21.
//

import Darwin
import Foundation

public enum Lox {
    static var hadError: Bool = false
    static var hadRuntimeError: Bool = false
    private static let interpretter = Interpretter()

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
        // print(expression)
        while true {
            print("> ", terminator: "")
            if let interactiveString = readLine(strippingNewline: true) {
                run(interactiveString)
                hadError = false
            }
        }
    }

    static func run(_ source: String) {
        let tokenlist = Scanner(source).scanTokens()
        // print("Scanner generated tokens: \(tokenlist)")
        let parser = Parser(tokenlist)
        let statements = parser.parse()
        print("generated \(statements.count) statements")
        if hadError {
            return
        }
        let resolver = Resolver(interpretter: interpretter)

        do {
            resolver.resolve(statements)
            try interpretter.interpretStatements(statements)
        } catch {
            print("INTERPRETTER HALTING: \(error)")
        }
    }

    public static func error(_ line: Int, message: String) {
        report(line: line, example: "", message: message)
    }

    public static func runtimeError(_ err: RuntimeError) {
        switch err {
        case .notImplemented:
            print("RuntimeError: Not Implemented")
        case let .typeMismatch(token, message: message):
            print("Type mismatch with \(token) at line \(token.line): \(message)")
        case let .undefinedVariable(token, message: message):
            print("\(message) at line \(token.line)")
        case .unexpectedNullValue:
            print("RuntimeError: Unexpected null in resolved optional")
        case let .notCallable(callee: callee):
            print("RuntimeError: Attempting to call \(callee), which isn't callable")
        case let .incorrectArgumentCount(expected: expected, actual: actual):
            print("RuntimeError: Incorrect number of arguments in function call. Expected \(expected), received \(actual)")
        case let .duplicateVariable(token, message: message):
            print("ResolverError: \(token): \(message)")
        }
        hadRuntimeError = true
    }

    static func report(line: Int, example: String, message: String) {
        print("[\(line)] Error \(example): \(message)")
        hadError = true
    }
}
