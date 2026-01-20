# ABOUTME: NixTest framework implementation for pure Nix unit testing
# ABOUTME: Provides assertion functions and test runner for testing Nix configurations

let
  # Assertion functions
  assertEquals = expected: actual: name:
    if expected == actual
    then { inherit name; result = "PASS"; }
    else builtins.throw "FAIL: ${name}\n  Expected: ${builtins.toString expected}\n  Actual: ${builtins.toString actual}";

  assertTrue = actual: name:
    if actual
    then { inherit name; result = "PASS"; }
    else builtins.throw "FAIL: ${name}\n  Expected: true\n  Actual: false";

  assertFalse = actual: name:
    if !actual
    then { inherit name; result = "PASS"; }
    else builtins.throw "FAIL: ${name}\n  Expected: false\n  Actual: true";

  assertContains = item: list: name:
    if builtins.elem item list
    then { inherit name; result = "PASS"; }
    else builtins.throw "FAIL: ${name}\n  Expected '${builtins.toString item}' to be in list\n  List: [${builtins.concatStringsSep ", " (map builtins.toString list)}]";

  # Test configuration evaluator
  evalTestConfig = modulePath: extraModules: 
    let
      eval-config = import ./helpers/eval-config.nix;
    in
    eval-config {
      modules = [ modulePath ] ++ extraModules;
    };

  # Helper functions for common test patterns
  checkModuleEvaluates = modulePath:
    let
      eval = evalTestConfig modulePath [];
    in
    builtins.isAttrs eval.config && eval.config ? system;

  getSystemPackages = modulePath:
    let
      eval = evalTestConfig modulePath [];
    in
    map (pkg: pkg.pname or pkg.name or "unknown") eval.config.environment.systemPackages;

  checkServiceEnabled = service: modulePath:
    let
      eval = evalTestConfig modulePath [];
    in
    eval.config.systemd.services.${service}.enable or false;

  checkConfigOption = optionPath: modulePath:
    let
      lib = (import <nixpkgs> {}).lib;
      eval = evalTestConfig modulePath [];
      getValue = path: config:
        if builtins.length path == 0
        then config
        else if builtins.hasAttr (builtins.head path) config
        then getValue (builtins.tail path) config.${builtins.head path}
        else null;
    in
    getValue (lib.splitString "." optionPath) eval.config;

  # Test runner that executes all tests in a test file
  runTests = tests:
    let
      results = map (test: 
        if test ? name && test ? actual && test ? expected
        then 
          if test.actual == test.expected
          then { inherit (test) name; result = "PASS"; }
          else builtins.throw "FAIL: ${test.name}\n  Expected: ${builtins.toString test.expected}\n  Actual: ${builtins.toString test.actual}"
        else builtins.throw "Invalid test format: ${builtins.toString test}"
      ) tests;
      
      passCount = builtins.length (builtins.filter (r: r.result == "PASS") results);
      totalCount = builtins.length results;
    in
    {
      inherit results passCount totalCount;
      success = passCount == totalCount;
      summary = "Tests: ${builtins.toString passCount}/${builtins.toString totalCount} passed";
    };

  # Discover and run all test files in a directory
  discoverTests = testDir:
    let
      lib = (import <nixpkgs> {}).lib;
      testFiles = builtins.attrNames (lib.filterAttrs (name: type: 
        type == "regular" && lib.hasSuffix "_test.nix" name
      ) (builtins.readDir testDir));
    in
    map (file: {
      name = file;
      tests = import (testDir + "/${file}");
    }) testFiles;

in
{
  inherit 
    assertEquals assertTrue assertFalse assertContains
    evalTestConfig checkModuleEvaluates getSystemPackages 
    checkServiceEnabled checkConfigOption
    runTests discoverTests;

  # Simple test format for NixTest compatibility
  test = { name, actual, expected }: { inherit name actual expected; };
}