# ABOUTME: NixTest runner that discovers and executes all test files in the test directory
# ABOUTME: Provides comprehensive test execution and reporting for Nix configurations

let
  nixtest = import ./nixtest.nix;
  lib = (import <nixpkgs> {}).lib;

  # Test suite definitions
  testSuites = {
    unit = {
      name = "Unit Tests";
      dir = ./unit;
      pattern = "*_test.nix";
    };
    integration = {
      name = "Integration Tests";
      dir = ./integration;
      pattern = "*_test.nix";
    };
    validation = {
      name = "Validation Tests";
      dir = ./validation;
      pattern = "*_test.nix";
    };
  };

  # Function to discover test files in a directory
  discoverTestFiles = dir: pattern:
    let
      dirContents = builtins.readDir dir;
      testFiles = lib.filterAttrs (name: type:
        type == "regular" && lib.hasSuffix "_test.nix" name
      ) dirContents;
    in
    lib.mapAttrsToList (name: type: {
      inherit name;
      path = dir + "/${name}";
    }) testFiles;

  # Function to run a single test file
  runTestFile = testFile:
    let
      tests = import testFile.path;
      results = nixtest.runTests tests;
    in
    {
      inherit (testFile) name;
      inherit (results) passCount totalCount success;
      tests = results.results;
      summary = "${testFile.name}: ${builtins.toString results.passCount}/${builtins.toString results.totalCount} passed";
    };

  # Function to run all tests in a suite
  runTestSuite = suiteName: suite:
    let
      testFiles = discoverTestFiles suite.dir suite.pattern;
      results = map runTestFile testFiles;
      totalTests = builtins.foldl' (acc: r: acc + r.totalCount) 0 results;
      passedTests = builtins.foldl' (acc: r: acc + r.passCount) 0 results;
      allPassed = builtins.all (r: r.success) results;
    in
    {
      name = suite.name;
      inherit results totalTests passedTests allPassed;
      summary = "${suite.name}: ${builtins.toString passedTests}/${builtins.toString totalTests} passed";
    };

  # Run all test suites
  allResults = lib.mapAttrs runTestSuite testSuites;

  # Calculate overall statistics
  overallStats = 
    let
      suiteResults = lib.attrValues allResults;
      totalTests = builtins.foldl' (acc: suite: acc + suite.totalTests) 0 suiteResults;
      passedTests = builtins.foldl' (acc: suite: acc + suite.passedTests) 0 suiteResults;
      allPassed = builtins.all (suite: suite.allPassed) suiteResults;
    in
    {
      inherit totalTests passedTests allPassed;
      summary = "Overall: ${builtins.toString passedTests}/${builtins.toString totalTests} tests passed";
    };

  # Generate test report
  generateReport = 
    let
      suiteReports = lib.mapAttrsToList (suiteName: suite: ''
        ## ${suite.name}
        ${suite.summary}
        
        ${lib.concatMapStrings (result: ''
          ### ${result.name}
          ${result.summary}
          
        '') suite.results}
      '') allResults;
      
      report = ''
        # Test Results Report
        
        ${overallStats.summary}
        
        ${lib.concatStrings suiteReports}
        
        ## Summary
        - Total test suites: ${builtins.toString (builtins.length (lib.attrNames allResults))}
        - Total tests: ${builtins.toString overallStats.totalTests}
        - Passed: ${builtins.toString overallStats.passedTests}
        - Failed: ${builtins.toString (overallStats.totalTests - overallStats.passedTests)}
        - Success: ${if overallStats.allPassed then "✅ All tests passed!" else "❌ Some tests failed"}
      '';
    in
    report;

in
{
  # Main test results
  inherit allResults overallStats;
  
  # Individual test suite results
  inherit (allResults) unit integration validation;
  
  # Test report
  report = generateReport;
  
  # Simple success indicator
  success = overallStats.allPassed;
  
  # Summary for quick reference
  summary = overallStats.summary;
}