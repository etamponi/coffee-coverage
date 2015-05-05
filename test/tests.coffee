path = require 'path'
assert = require 'assert'
{expect} = require 'chai'
coffeeCoverage = require("../src/index")

dummyJsFile = path.resolve __dirname, "../testFixtures/testWithConfig/dummy.js"
testDir = path.resolve __dirname, "../testFixtures/testWithConfig"

extensions = ['.coffee', '.litcoffee', '.coffee.md', '._coffee']
loadedModules = [
    '../testFixtures/testWithExcludes/a/foo.coffee',
    '../testFixtures/testWithExcludes/b/bar.coffee'
]
handlers = {}

{COVERAGE_VAR, log} = require './testConfig'

describe "Coverage tests", ->
    before ->
        for ext in extensions
            handlers[ext] = require.extensions[ext]

    afterEach ->
        # Undo the `register` command
        for ext in extensions
            require.extensions[ext] = handlers[ext]

        # Remove modules we loaded so we can reload them for the next test.
        for mod in loadedModules
            p = path.resolve mod
            if !p of require.cache then console.log "Argh!"
            delete require.cache[path.resolve(__dirname, mod)]

        # Clear coverage
        delete global[COVERAGE_VAR]

    it "should exclude directories specified from the project root when dynamically instrumenting code", ->
        coffeeCoverage.register(
            path: "relative"
            basePath: path.resolve __dirname, '../testFixtures/testWithExcludes'
            exclude: ["/b"]
            coverageVar: COVERAGE_VAR
            log: log
        )

        require '../testFixtures/testWithExcludes/a/foo.coffee'
        require '../testFixtures/testWithExcludes/b/bar.coffee'

        expect(global[COVERAGE_VAR], "Code should have been instrumented").to.exist
        expect(global[COVERAGE_VAR]['a/foo.coffee'], "Should instrument a/foo.coffee").to.exist
        expect(global[COVERAGE_VAR]['b/bar.coffee'], "Should not instrument b/bar.coffee").to.not.exist

    it "should exclude directories when dynamically instrumenting code", ->

        coffeeCoverage.register(
            path: "relative"
            basePath: path.resolve __dirname, '../testFixtures/testWithExcludes'
            exclude: ["b"]
            coverageVar: COVERAGE_VAR
            log: log
        )

        require '../testFixtures/testWithExcludes/a/foo.coffee'
        require '../testFixtures/testWithExcludes/b/bar.coffee'

        expect(global[COVERAGE_VAR], "Code should have been instrumented").to.exist
        expect(global[COVERAGE_VAR]['a/foo.coffee'], "Should instrument a/foo.coffee").to.exist
        expect(global[COVERAGE_VAR]['b/bar.coffee'], "Should not instrument b/bar.coffee").to.not.exist

    it "should handle nested recursion correctly", ->
        # From https://github.com/benbria/coffee-coverage/pull/37
        instrumentor = new coffeeCoverage.CoverageInstrumentor({
            coverageVar: COVERAGE_VAR
            log: log
        })
        source = """
            z = 0
            for i in [0...2]
                for j in [0...5]
                    z++

            return z
        """

        code = instrumentor.instrumentCoffee("example.coffee", source).js

        global[COVERAGE_VAR] = {"example.coffee": {}}
        z = eval code
        expect(z).to.equal 10

    it "should work with debug logging", ->
        instrumentor = new coffeeCoverage.CoverageInstrumentor({
            coverageVar: COVERAGE_VAR
            log: {
                debug: ->
                info: ->
                warn: ->
                error: ->
            }
            instrumentor: 'istanbul'
        })
        source = """
            z = 0
            for i in [0...2]
                for j in [0...5]
                    z++

            return z
        """

        code = instrumentor.instrumentCoffee("example.coffee", source).js

    it "should correctly compile an 'if' without an explicit return", ->
        instrumentor = new coffeeCoverage.CoverageInstrumentor({
            coverageVar: COVERAGE_VAR
            instrumentor: 'istanbul'
        })
        source = """
            f = (x) ->
                if x?.foo then 1

            return f({})
        """
        result = instrumentor.instrumentCoffee("example.coffee", source)
        eval result.init
        z = eval result.js
        expect(z).to.not.exist

    it "should correctly compile list comprehensions", ->
        instrumentor = new coffeeCoverage.CoverageInstrumentor({
            coverageVar: COVERAGE_VAR
            log: log
            instrumentor: 'istanbul'
        })
        source = """
            a = [1,2,3,4]
            inc = (x) -> x + 1
            a = (inc x for x in a)
            return a
        """
        result = instrumentor.instrumentCoffee("example.coffee", source)
        eval result.init
        z = eval result.js
        expect(z).to.eql [2,3,4,5]

    it "should throw an error if input can't be compiled", ->
        instrumentor = new coffeeCoverage.CoverageInstrumentor({
            coverageVar: COVERAGE_VAR
            log: log
        })
        source = """
            waka { waka
        """

        expect( ->
            instrumentor.instrumentCoffee("example.coffee", source).js
        ).to.throw(/^Could not parse example.coffee.*/)

    it "should throw an error if an invalid instrumentor is specified", ->
        expect( ->
            instrumentor = new coffeeCoverage.CoverageInstrumentor({
                coverageVar: COVERAGE_VAR
                log: log
                instrumentor: 'foo'
            })
        ).to.throw()
