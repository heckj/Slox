@testable import Slox
import XCTest

public struct LoxExample {
    let source: String
    let tokens: Int
    let statements: Int
}

public struct LOXSource {

    public static var allExamples = [
        LoxExample(source: printSource, tokens: 4, statements: 1),
        LoxExample(source: printComment, tokens: 4, statements: 1),
        LoxExample(source: basicVariable, tokens: 9, statements: 2),
        LoxExample(source: basicExpression, tokens: 11, statements: 1),
        LoxExample(source: assignmentStatement, tokens: 13, statements: 2),
        LoxExample(source: assignmentGroupedStatement, tokens: 15, statements: 2),
        LoxExample(source: unaryComparison, tokens: 14, statements: 2),
        LoxExample(source: comparisonPrint, tokens: 20, statements: 3),
        LoxExample(source: logicalComparison, tokens: 31, statements: 4)
    ]

    public static var printSource = "print 42;"

    public static var printComment = """
print "Hello World";
// The basics as you'd expect.
"""
    public static var basicVariable = """
var foo = 32;
print foo;
"""
    public static var basicExpression = "1+2*3/4-5;"
    public static var assignmentStatement = """
var foo = 1+2/3;
print foo;
"""
    public static var assignmentGroupedStatement = """
var foo = (1+2)/3;
print foo;
"""
    public static var unaryComparison = """
var maybe = !(3>4);
print maybe;
"""

    public static var comparisonPrint = """
var foo = 1;
print foo;
if (foo > 3) {
    print "many"
};
"""

    public static var logicalComparison = """
var foo = 1;
var bar = 5;
print foo;
if (foo > 3) AND (bar == 5) {
    print "many"
};
"""
}
