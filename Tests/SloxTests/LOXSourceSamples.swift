@testable import Slox
import XCTest

public struct LoxExample {
    internal init(source: String, tokens: Int, statements: Int, errors: Int = 0) {
        self.source = source
        self.tokens = tokens
        self.statements = statements
        self.errors = errors
    }

    let source: String
    let tokens: Int
    let statements: Int
    let errors: Int
}

public enum LOXSource {
    public static var printSource = LoxExample(
        source: "print 42;",
        tokens: 4, statements: 1
    )

    public static var printComment = LoxExample(
        source: """
        print "Hello World";
        // The basics as you'd expect.
        """,
        tokens: 4, statements: 1
    )

    public static var basicVariable = LoxExample(
        source: """
        var foo = 32;
        print foo;
        """,
        tokens: 9, statements: 2
    )

    public static var basicExpression = LoxExample(
        source: "1+2*3/4-5;",
        tokens: 11, statements: 1
    )

    public static var assignmentStatement = LoxExample(
        source: """
        var foo = 1+2/3;
        print foo;
        """, tokens: 13, statements: 2
    )

    public static var assignmentGroupedStatement = LoxExample(
        source: """
        var foo = (1+2)/3;
        print foo;
        """, tokens: 15, statements: 2
    )

    public static var unaryComparison = LoxExample(
        source: """
        var maybe = !(3>4);
        print maybe;
        """, tokens: 14, statements: 2
    )

    public static var comparisonPrint = LoxExample(
        source: """
        var foo = 1;
        print foo;
        if (foo > 3) {
            print "many";
        }
        """, tokens: 20, statements: 3
    )

    public static var logicalComparison = LoxExample(
        source: """
        var foo = 1;
        var bar = 5;
        print foo;
        if ((foo > 3) AND (bar == 5)) {
            print "many";
        }
        """, tokens: 33, statements: 4
    )

    public static var chap8_1 = LoxExample(
        source: """
        var beverage = "espresso";
        print beverage;
        """, tokens: 9, statements: 2
    )

    public static var chap8_2 = LoxExample(
        source: """
        print "one";
        print true;
        print 2 + 1;
        """, tokens: 12, statements: 3
    )

    public static var chap8_3 = LoxExample(
        source: """
        var monday = true;
        if (monday) print "Ugh, already?";
        """, tokens: 13, statements: 2
    )

    public static var chap8_4 = LoxExample(
        source: """
        var monday = true;
        if (monday) var beverage = "espresso";
        """, // NOTE: invalid
        tokens: 15, statements: 1, errors: 1
    )

    public static var chap8_5 = LoxExample(
        source: """
        var a = "before";
        print a;
        var a = "after";
        print a;
        """, tokens: 17, statements: 4
    )

    public static var chap8_6 = LoxExample(
        source: """
        // runtime error
        print a;
        var a = "too late";
        """, tokens: 9, statements: 2
    )

    public static var chap8_7 = LoxExample(
        source: """
        var a;
        print a; // nil
        """, tokens: 7, statements: 2
    )

    public static var chap8_8 = LoxExample(
        source: """
        var a = 1;
        var b = 2;
        print a + b;
        """, tokens: 16, statements: 3
    )

    public static var chap8_9 = LoxExample(
        source: """
        a = 3; // OK
        (a) = 3; // parse ERROR
        """, tokens: 11, statements: 2, errors: 1
    )

    public static var chap8_10 = LoxExample(
        source: """
        var a = 1;
        print a = 2; // 2
        """, tokens: 11, statements: 2
    )

    public static var chap8_11 = LoxExample(
        source: """
        {
          var a = "in block";
        }
        print a; // Error: no more 'a' variable
        """, tokens: 11, statements: 2
    )

    public static var chap8_12 = LoxExample(
        source: """
        // shadowing
        var volume = 11;
        volume = 0;
        {
           var volume = 3*4*5;
            print volume; // 60
        }
        print volume; // 0
        """, tokens: 27, statements: 4
    )

    public static var chap8_13 = LoxExample(
        source: """
        // parent-pointer tree
        var global = "outside";
        {
            var local = "inside";
            print global + local;
        }
        """, tokens: 18, statements: 2
    )

    public static var chap8_14 = LoxExample(
        source: """
        // local variables
        var a = "global a";
        var b = "global b";
        var c = "global c";
        {
          var a = "outer a";
          var b = "outer b";
          {
            var a = "inner a";
            print a;
            print b;
            print c;
          }
          print a;
          print b;
          print c;
        }
        print a;
        print b;
        print c;
        """, tokens: 62, statements: 7
    )

    public static var chap9_1 = LoxExample(
        source: """
        print "hi" or 2; // hi
        print nil or "yes"; // "yes"
        """, tokens: 11, statements: 2
    )

    public static var chap9_2 = LoxExample(
        source: """
        //for loop
        for (var i = 0; i < 10; i = i + 1) print i;
        """, tokens: 21, statements: 1
    )

    public static var chap9_3 = LoxExample(
        source: """
        // lox fibonacci
        var a = 0;
        var temp;
        for (var b = 1; a < 10000; b = temp + b) {
          print a;
          temp = a;
          a = b;
        }
        """, tokens: 39, statements: 3
    )

    public static var chap10_1 = LoxExample(
        source: """
        fun add(a, b, c) {
            print a + b + c;
        }
        add(1,2,3,4); // too many
        add(1,2); // too few
        """, tokens: 37, statements: 3
    ) // runtime error, but not a parsing error

    // error on function with no name
    public static var chap10_2 = LoxExample(
        source: """
        fun add(a,b) {
            print a + b;
        }
        """, tokens: 15, statements: 1
    )

    public static var chap10_3 = LoxExample(
        source: """
        fun count(n) {
             if (n > 1) count (n - 1);
             print n;
        }
        count(3);
        """, tokens: 29, statements: 2
    )

    public static var chap10_4 = LoxExample(
        source: """
        fun add(a, b) {
             print a + b;
        }
        print add; // <fn add>
        """, tokens: 18, statements: 2
    )

    public static var chap10_5 = LoxExample(
        source: """
        fun sayHi(first, last) {
          print "Hi, " + first + " " + last + "!";
        }
        sayHi("Dear", "Reader");
        """, tokens: 28, statements: 2
    )

    public static var chap10_6 = LoxExample(
        source: """
        fun procedure() {
          print "don't return anything";
        }
        var result = procedure();
        print result; // ?
        """, tokens: 20, statements: 3
    )

    public static var chap10_7 = LoxExample(
        source: """
        fun count(n) {
          while (n < 100) {
            if (n == 3) return n;
            print n;
            n = n + 1;
          }
        }
        count(1);
        """, tokens: 39, statements: 2
    )

    public static var chap10_8 = LoxExample(
        source: """
        fun fib(n) {
          if (n <= 1) return n;
          return fib(n - 2) + fib(n - 1);
        }
        for (var i = 0; i < 20; i = i + 1) {
          print fib(i);
        }
        """, tokens: 57, statements: 2
    )

    public static var chap10_9 = LoxExample(
        source: """
        fun makeCounter() {
          var i = 0;
          fun count() {
            i = i + 1;
            print i;
          }
          return count;
        }
        var counter = makeCounter();
        counter(); // "1".
        counter(); // "2".
        """, tokens: 45, statements: 4
    )

    public static var chap11_1a = LoxExample(
        source: """
         var a = "outer";
         {
           var a = a;
         }
        """,
        tokens: 13, statements: 2
    ) // Resolver Error - shadowing outer scope

    public static var chap11_1b = LoxExample(
        source: """
         {
             var a = "outer";
             {
               var a = a;
             }
         }
        """,
        // with the outer 'block', this adds 2 tokens, and collapses to a single statement
        tokens: 15, statements: 1
    ) // Resolver Error - shadowing outer scope

    public static var chap11_2 = LoxExample(
        source: """
        fun bad() {
             var a = "first";
             var a = "second";
        }
        """,
        tokens: 17, statements: 1
    ) // Resolver Error - duplicate def'n of var

    public static var chap11_3 = LoxExample(
        source: """
        return "at top level";
        """,
        tokens: 4, statements: 1
    ) // Resolver Error - invalid return

    public static var chap11_4 = LoxExample(
        source: """
        for (var i = 0; i < 20; i = i + 1) {
          print (i);
        }
        """,
        tokens: 25, statements: 1
    )

    public static var chap12_1 = LoxExample(
        source: """
        class DevonshireCream {
          serveOn() {
            return "Scones";
          }
        }
        print DevonshireCream; // Prints "DevonshireCream".
        """,
        tokens: 16, statements: 2)

    public static var chap12_2 = LoxExample(
        source: """
        class Bagel {}
        var bagel = Bagel();
        print bagel; // Prints "Bagel instance".
        """,
        tokens: 15, statements: 3)

    public static var allExamples = [
        printSource, printComment, basicVariable, basicExpression, assignmentStatement,
        assignmentGroupedStatement, unaryComparison, comparisonPrint, logicalComparison,
        chap8_1, chap8_2, chap8_3, chap8_4, chap8_5, chap8_6, chap8_7, chap8_8, chap8_9,
        chap8_10, chap8_11, chap8_12, chap8_13, chap8_14,
        chap9_1, chap9_2, chap9_3,
        chap10_1, chap10_2, chap10_3, chap10_4, chap10_5, chap10_6, chap10_7, chap10_8, chap10_9,
        chap11_1a, chap11_1b, chap11_2, chap11_4,
        chap12_1, chap12_2
    ]
}
