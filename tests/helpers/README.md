# Test Helpers

This directory contains helper functions and utilities for testing Nix configurations using Python.

## Files

### nix_eval.py

Python-based Nix evaluation helper that provides reliable cross-platform testing capabilities.

Available functions:
- `check_module_evaluates(module_path)` - Check if a module evaluates without errors
- `get_system_packages(module_path)` - Get list of system packages from a configuration
- `check_service_enabled(service, module_path)` - Check if a service is enabled

Command-line usage:
```bash
./nix_eval.py check-module path/to/module.nix
./nix_eval.py get-packages path/to/module.nix
./nix_eval.py check-service sshd path/to/module.nix
```

### eval-config.nix

Minimal NixOS configuration builder for testing modules. Provides a base configuration that can be extended.

Usage:
```nix
import ./eval-config.nix {
  modules = [ ./my-module.nix ];
  system = "x86_64-linux";  # optional, defaults to x86_64-linux
}
```

## Python Test Framework

The test framework is built around Python for better reliability and cross-platform compatibility.

### framework.py

Base testing framework providing:

#### NixTestCase Class
- `check_module_evaluates(module_path)` - Test module evaluation
- `get_system_packages(module_path)` - Get package list
- `check_service_enabled(service, module_path)` - Test service configuration
- `run_nix_eval(expression)` - Run arbitrary Nix evaluations
- Assertion methods: `assert_true`, `assert_false`, `assert_equals`, `assert_contains`

#### TestRunner Class
- Discovers and runs Python test files (`test_*.py`)
- Provides colored output and timing
- Generates comprehensive test reports

## Usage Example

```python
#!/usr/bin/env python3
import sys
from pathlib import Path

# Import the test framework
sys.path.insert(0, str(Path(__file__).parent.parent))
from framework import NixTestCase

class TestMyModule(NixTestCase):
    def __init__(self):
        super().__init__("My Module Tests")

def test_module_evaluates():
    """Test that the module evaluates successfully"""
    test = TestMyModule()
    result = test.check_module_evaluates("path/to/module.nix")
    test.assert_true(result, "Module should evaluate")

def test_ssh_enabled():
    """Test that SSH service is enabled"""
    test = TestMyModule()
    ssh_enabled = test.check_service_enabled("sshd", "path/to/module.nix")
    test.assert_true(ssh_enabled, "SSH should be enabled")

def test_packages_included():
    """Test that required packages are included"""
    test = TestMyModule()
    packages = test.get_system_packages("path/to/module.nix")
    test.assert_contains("vim", packages, "vim should be included")

if __name__ == "__main__":
    # Run tests when executed directly
    import importlib
    current_module = sys.modules[__name__]
    test_functions = [getattr(current_module, name) for name in dir(current_module) 
                     if name.startswith('test_') and callable(getattr(current_module, name))]
    
    for test_func in test_functions:
        try:
            test_func()
            print(f"✅ {test_func.__name__} PASSED")
        except Exception as e:
            print(f"❌ {test_func.__name__} FAILED: {e}")
```

## Running Tests

### Individual Test Files
```bash
# Run a specific test file
python3 tests/unit/test_base_vm.py

# Or make it executable and run directly
./tests/unit/test_base_vm.py
```

### All Tests
```bash
# Run all tests using the Python test runner
python3 tests/run_all.py

# With verbose output
python3 tests/run_all.py --verbose
```

## Best Practices

1. Use Python test files (`test_*.py`) for new tests
2. Inherit from `NixTestCase` for Nix-specific testing capabilities
3. Use descriptive test function names starting with `test_`
4. Include docstrings for test functions
5. Use assertion methods with clear messages
6. Handle evaluation errors gracefully with try/catch blocks
7. Test both positive and negative cases
8. Keep tests focused and atomic

## Migration from Shell

The framework has been migrated from shell scripts to Python for:
- Better error handling and reporting
- Cross-platform compatibility
- More reliable Nix evaluation
- Improved test discovery and execution
- Cleaner assertion syntax