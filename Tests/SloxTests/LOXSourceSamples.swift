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
    public static var allExamples = [
        LoxExample(source: printSource, tokens: 4, statements: 1),
        LoxExample(source: printComment, tokens: 4, statements: 1),
        LoxExample(source: basicVariable, tokens: 9, statements: 2),
        LoxExample(source: basicExpression, tokens: 11, statements: 1),
        LoxExample(source: assignmentStatement, tokens: 13, statements: 2),
        LoxExample(source: assignmentGroupedStatement, tokens: 15, statements: 2),
        LoxExample(source: unaryComparison, tokens: 14, statements: 2),
        LoxExample(source: comparisonPrint, tokens: 20, statements: 3),
        LoxExample(source: logicalComparison, tokens: 33, statements: 4),
        LoxExample(source: chap8_1, tokens: 9, statements: 2),
        LoxExample(source: chap8_2, tokens: 12, statements: 3),
        LoxExample(source: chap8_3, tokens: 13, statements: 2),
        LoxExample(source: chap8_4, tokens: 15, statements: 1, errors: 1),

        LoxExample(source: chap8_5, tokens: 17, statements: 4),
        LoxExample(source: chap8_6, tokens: 9, statements: 2),
        
        LoxExample(source: chap8_7, tokens: 7, statements: 2),

        LoxExample(source: chap8_8, tokens: 16, statements: 3),
        LoxExample(source: chap8_9, tokens: 11, statements: 2, errors: 1),
        LoxExample(source: chap8_10, tokens: 11, statements: 2),
        LoxExample(source: chap8_11, tokens: 11, statements: 2),

        LoxExample(source: chap8_12, tokens: 27, statements: 4),
        LoxExample(source: chap8_13, tokens: 18, statements: 2),
        LoxExample(source: chap8_14, tokens: 62, statements: 7),
        
        LoxExample(source: chap9_1, tokens: 11, statements: 2),
        LoxExample(source: chap9_2, tokens: 21, statements: 1),
        LoxExample(source: chap9_3, tokens: 39, statements: 3),
        
        LoxExample(source: chap10_1, tokens: 37, statements: 3), // runtime error, but not a parsing error
        LoxExample(source: chap10_2, tokens: 15, statements: 1),
        LoxExample(source: chap10_3, tokens: 29, statements: 2),
        LoxExample(source: chap10_4, tokens: 18, statements: 2),
        LoxExample(source: chap10_5, tokens: 28, statements: 2),
        LoxExample(source: chap10_6, tokens: 20, statements: 3),
        LoxExample(source: chap10_7, tokens: 39, statements: 2),
//        LoxExample(source: chap10_8, tokens: 31, statements: 3),
//        LoxExample(source: chap10_9, tokens: 31, statements: 4)
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
        print "many";
    }
    """

    public static var logicalComparison = """
    var foo = 1;
    var bar = 5;
    print foo;
    if ((foo > 3) AND (bar == 5)) {
        print "many";
    }
    """

    public static var chap8_1 = """
    var beverage = "espresso";
    print beverage;
    """

    public static var chap8_2 = """
    print "one";
    print true;
    print 2 + 1;
    """

    public static var chap8_3 = """
    var monday = true;
    if (monday) print "Ugh, already?";
    """
    public static var chap8_4 = """
    var monday = true;
    if (monday) var beverage = "espresso";
    """ // NOTE: invalid

    public static var chap8_5 = """
    var a = "before";
    print a;
    var a = "after";
    print a;
    """

    public static var chap8_6 = """
    // runtime error
    print a;
    var a = "too late";
    """

    public static var chap8_7 = """
    var a;
    print a; // nil
    """

    public static var chap8_8 = """
    var a = 1;
    var b = 2;
    print a + b;
    """

    public static var chap8_9 = """
    a = 3; // OK
    (a) = 3; // parse ERROR
    """

    public static var chap8_10 = """
    var a = 1;
    print a = 2; // 2
    """

    public static var chap8_11 = """
    {
      var a = "in block";
    }
    print a; // Error: no more 'a' variable
    """

    public static var chap8_12 = """
    // shadowing
    var volume = 11;
    volume = 0;
    {
       var volume = 3*4*5;
        print volume; // 60
    }
    print volume; // 0
    """

    public static var chap8_13 = """
    // parent-pointer tree
    var global = "outside";
    {
        var local = "inside";
        print global + local;
    }
    """

    public static var chap8_14 = """
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
    """

    public static var chap9_1 = """
    print "hi" or 2; // hi
    print nil or "yes"; // "yes"
    """

    public static var chap9_2 = """
    //for loop
    for (var i = 0; i < 10; i = i + 1) print i;
    """

    public static var chap9_3 = """
    // lox fibonacci
    var a = 0;
    var temp;
    for (var b = 1; a < 10000; b = temp + b) {
      print a;
      temp = a;
      a = b;
    }
    """

    public static var chap10_1 = """
    fun add(a, b, c) {
        print a + b + c;
    }
    add(1,2,3,4); // too many
    add(1,2); // too few
    """

    // error on function with no name
    public static var chap10_2 = """
    fun add(a,b) {
        print a + b;
    }
    """

    public static var chap10_3 = """
    fun count(n) {
         if (n > 1) count (n - 1);
         print n;
    }
    count(3);
    """

    public static var chap10_4 = """
    fun add(a, b) {
         print a + b;
    }
    print add; // <fn add>

    """

    public static var chap10_5 = """
    fun sayHi(first, last) {
      print "Hi, " + first + " " + last + "!";
    }
    sayHi("Dear", "Reader");

    """

    public static var chap10_6 = """
    fun procedure() {
      print "don't return anything";
    }
    var result = procedure();
    print result; // ?
    """

    public static var chap10_7 = """
    fun count(n) {
      while (n < 100) {
        if (n == 3) return n; // <--
        print n;
        n = n + 1;
      }
    }
    count(1);
    """

    public static var chap10_8 = """
    fun fib(n) {
      if (n <= 1) return n;
      return fib(n - 2) + fib(n - 1);
    }
    for (var i = 0; i < 20; i = i + 1) {
      print fib(i);
    }
    """

    public static var chap10_9 = """
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
    """
}
