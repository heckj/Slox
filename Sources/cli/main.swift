//
//  main.swift
//  Slox
//
//  Created by Joseph Heck on 3/2/21.
//

import Foundation
import Slox

print("SLOX!")
let passed_args: [String] = Array(CommandLine.arguments[1...]) // first argument is the CLI command line name
try Lox.main(args: passed_args)
