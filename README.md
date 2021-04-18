# Slox

A swift port/variation following on the content from Bob Nystrom's
[Crafting Interpreters](https://craftinginterpreters.com/contents.html)

This is a hobby project to go through the book and do some learning, so don't _count_ on anything here.

## Compile, Test, and Code Coverage

You can open Package.swift in Xcode and run tests there and inspect code coverage.
If you want to run do this all from the command line (or a CI pipeline), then I've made a script to make this easier.

    ./codecov-report.sh 

Runs the tests with `--enable-code-coverage`, and using `xcrun` to determine a location (macOS only currently) for the binary and uses `llvm-cov` and `lcov` to generate an HTML report in the directory `coverage`.

To set up CLI tooling (`lcov`) for the report generation:

    brew install lcov

## Run the tests on Linux

    docker run -it --rm --platform linux/amd64 -v "$PWD:$PWD" -w "$PWD" -e QEMU_CPU=max swift:5.3 swift test
