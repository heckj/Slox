//
//  Callable.swift
//  Slox
//
//  Created by Joseph Heck on 3/21/21.
//

import Foundation

public struct Callable {
    public let description: String
    let arity: Int
    let call: (Interpretter, [RuntimeValue]) throws -> RuntimeValue
}
