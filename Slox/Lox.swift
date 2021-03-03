//
//  Lox.swift
//  Slox
//
//  Created by Joseph Heck on 3/2/21.
//

import Foundation
import Darwin

class Lox {
    public static func main(args: [String]) throws {
        if (args.count > 1) {
            print("Usage: slox [script]")
            exit(64)
        } else if (args.count == 1) {
            try runFile(args[0])
        } else {
            try runPrompt()
        }
    }
    
    // https://craftinginterpreters.com/scanning.html
    
    static func runFile(_ path: String) throws {
//        byte[] bytes = Files.readAllBytes(Paths.get(path));
//        run(new String(bytes, Charset.defaultCharset()));
        let contents = try String(contentsOfFile: path, encoding: .utf8)
        run(contents)
    }

    static func runPrompt() throws {
        //        InputStreamReader input = new InputStreamReader(System.in);
        //        BufferedReader reader = new BufferedReader(input);
        //
        //        for (;;) {
        //          System.out.print("> ");
        //          String line = reader.readLine();
        //          if (line == null) break;
        //          run(line);
        //        }
        while(true) {
            print("> ")
            if let interactiveString = readLine(strippingNewline: true) {
                run(interactiveString)
            }
        }
    }
    
    static func run(_ source: String) {
        let scanner = Scanner(string: source)
//            List<Token> tokens = scanner.scanTokens();
//
//            // For now, just print the tokens.
//            for (Token token : tokens) {
//              System.out.println(token);
//            }
    }
}
