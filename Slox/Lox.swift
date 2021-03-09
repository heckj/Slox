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
//        for token in tokenlist {
//            print(token)
//        }
        print("Scanner generated tokens: \(tokenlist)")
        let parser = Parser(tokenlist)
        let statements = parser.parse()
        print("generated \(statements.count) statements")
        if hadError {
            return
        }
        interpretter.interpretStatements(statements)
    }

    public static func error(_ line: Int, message: String) {
        report(line: line, example: "", message: message)
    }

    public static func runtimeError(_ err: LoxRuntimeError) {
        switch err {
        case .notImplemented:
            print("RuntimeError: Not Implemented")
        case let .oops(token):
            print("RuntimeError with \(token) at line \(token.line)")
        }
        hadRuntimeError = true
    }

    static func report(line: Int, example: String, message: String) {
        print("[\(line)] Error \(example): \(message)")
        hadError = true
    }
}
