#!/usr/bin/env python3
# ABOUTME: Simple sanity testing CLI tool for k3s cluster validation
# ABOUTME: Uses only Python standard library for zero dependencies

import argparse
import json
import os
import socket
import subprocess
import sys
import time
import urllib.request
import urllib.error
from typing import Tuple, Optional

# ANSI color codes
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
NC = '\033[0m'  # No Color

# Test result symbols
PASS = f"{GREEN}✓{NC}"
FAIL = f"{RED}✗{NC}"
INFO = f"{BLUE}ℹ{NC}"
WARN = f"{YELLOW}⚠{NC}"


def print_result(success: bool, message: str) -> None:
    """Print a test result with appropriate symbol and color."""
    symbol = PASS if success else FAIL
    print(f"{symbol} {message}")


def print_info(message: str) -> None:
    """Print an informational message."""
    print(f"{INFO} {message}")


def print_warning(message: str) -> None:
    """Print a warning message."""
    print(f"{WARN} {message}")


def check_nix_eval(config_path: str) -> bool:
    """Evaluate a Nix configuration and check for errors."""
    print_info(f"Evaluating Nix configuration: {config_path}")
    
    if not os.path.exists(config_path):
        print_result(False, f"Configuration file not found: {config_path}")
        return False
    
    try:
        # Try to evaluate the Nix expression
        cmd = ['nix-instantiate', '--eval', '--strict', '--json', config_path]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        
        if result.returncode == 0:
            print_result(True, f"Nix configuration evaluates successfully")
            return True
        else:
            print_result(False, f"Nix evaluation failed")
            if result.stderr:
                print(f"  Error: {result.stderr.strip()}")
            return False
            
    except subprocess.TimeoutExpired:
        print_result(False, "Nix evaluation timed out after 30 seconds")
        return False
    except FileNotFoundError:
        print_result(False, "nix-instantiate not found - is Nix installed?")
        return False
    except Exception as e:
        print_result(False, f"Unexpected error during Nix evaluation: {e}")
        return False


def check_host_connectivity(hostname: str, port: int, timeout: int = 5) -> bool:
    """Test TCP connectivity to a host and port."""
    print_info(f"Checking connectivity to {hostname}:{port}")
    
    try:
        # Create a socket and attempt to connect
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        
        result = sock.connect_ex((hostname, port))
        sock.close()
        
        if result == 0:
            print_result(True, f"Successfully connected to {hostname}:{port}")
            return True
        else:
            print_result(False, f"Failed to connect to {hostname}:{port}")
            return False
            
    except socket.gaierror:
        print_result(False, f"Failed to resolve hostname: {hostname}")
        return False
    except socket.timeout:
        print_result(False, f"Connection timed out after {timeout} seconds")
        return False
    except Exception as e:
        print_result(False, f"Connection error: {e}")
        return False


def check_k3s_api(host: str, port: int = 6443) -> bool:
    """Validate k3s API server response."""
    print_info(f"Checking k3s API at https://{host}:{port}")
    
    url = f"https://{host}:{port}/version"
    
    try:
        # Create a custom opener that ignores SSL certificate verification
        # (for testing purposes only - k3s uses self-signed certs by default)
        import ssl
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=10, context=ctx) as response:
            if response.status == 200:
                data = json.loads(response.read().decode('utf-8'))
                version = data.get('gitVersion', 'unknown')
                print_result(True, f"k3s API is responding (version: {version})")
                return True
            else:
                print_result(False, f"k3s API returned status code: {response.status}")
                return False
                
    except urllib.error.HTTPError as e:
        if e.code == 401:
            # 401 Unauthorized is actually expected without auth token
            print_result(True, "k3s API is responding (authentication required)")
            return True
        else:
            print_result(False, f"k3s API HTTP error: {e.code} {e.reason}")
            return False
    except urllib.error.URLError as e:
        print_result(False, f"Failed to connect to k3s API: {e.reason}")
        return False
    except json.JSONDecodeError:
        print_result(False, "Failed to parse k3s API response")
        return False
    except Exception as e:
        print_result(False, f"Unexpected error checking k3s API: {e}")
        return False


def check_ssh_access(host: str, port: int = 22, user: str = None) -> bool:
    """Verify SSH connectivity to a host."""
    ssh_target = f"{user}@{host}" if user else host
    print_info(f"Checking SSH access to {ssh_target}")
    
    try:
        # Use ssh with BatchMode to avoid interactive prompts
        cmd = [
            'ssh',
            '-o', 'BatchMode=yes',
            '-o', 'ConnectTimeout=5',
            '-o', 'StrictHostKeyChecking=no',
            '-p', str(port),
            ssh_target,
            'echo', 'SSH_TEST_SUCCESS'
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        
        if result.returncode == 0 and 'SSH_TEST_SUCCESS' in result.stdout:
            print_result(True, f"SSH access to {ssh_target} is working")
            return True
        else:
            print_result(False, f"SSH access to {ssh_target} failed")
            if result.stderr:
                print(f"  Error: {result.stderr.strip()}")
            return False
            
    except subprocess.TimeoutExpired:
        print_result(False, "SSH connection timed out")
        return False
    except FileNotFoundError:
        print_result(False, "ssh command not found")
        return False
    except Exception as e:
        print_result(False, f"Unexpected error during SSH check: {e}")
        return False


def main():
    """Main entry point for the sanity testing tool."""
    parser = argparse.ArgumentParser(
        description='Sanity testing tool for k3s HA cluster',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Run all tests
  %(prog)s --all

  # Test Nix configuration
  %(prog)s --nix-eval ./hosts/orchard/configuration.nix

  # Test host connectivity
  %(prog)s --check-host 10.10.11.100 --port 22

  # Test k3s API
  %(prog)s --k3s-api 10.10.11.39

  # Test SSH access
  %(prog)s --ssh-host 10.10.11.100 --ssh-user mobrienv
"""
    )
    
    parser.add_argument('--all', action='store_true',
                        help='Run all sanity checks')
    parser.add_argument('--nix-eval', metavar='PATH',
                        help='Evaluate a Nix configuration file')
    parser.add_argument('--check-host', metavar='HOST',
                        help='Check connectivity to a host')
    parser.add_argument('--port', type=int, default=22,
                        help='Port to use for host connectivity check (default: 22)')
    parser.add_argument('--k3s-api', metavar='HOST',
                        help='Check k3s API server')
    parser.add_argument('--k3s-port', type=int, default=6443,
                        help='k3s API port (default: 6443)')
    parser.add_argument('--ssh-host', metavar='HOST',
                        help='Check SSH access to a host')
    parser.add_argument('--ssh-user', metavar='USER',
                        help='SSH username')
    parser.add_argument('--ssh-port', type=int, default=22,
                        help='SSH port (default: 22)')
    
    args = parser.parse_args()
    
    # Track test results
    tests_run = 0
    tests_passed = 0
    
    # Header
    print(f"{BLUE}=== K3s Cluster Sanity Tests ==={NC}")
    print()
    
    # If no specific tests requested, show help
    if not any([args.all, args.nix_eval, args.check_host, args.k3s_api, args.ssh_host]):
        parser.print_help()
        return 0
    
    # Run requested tests
    if args.nix_eval or args.all:
        tests_run += 1
        if check_nix_eval(args.nix_eval or './flake.nix'):
            tests_passed += 1
        print()
    
    if args.check_host:
        tests_run += 1
        if check_host_connectivity(args.check_host, args.port):
            tests_passed += 1
        print()
    
    if args.k3s_api:
        tests_run += 1
        if check_k3s_api(args.k3s_api, args.k3s_port):
            tests_passed += 1
        print()
    
    if args.ssh_host:
        tests_run += 1
        if check_ssh_access(args.ssh_host, args.ssh_port, args.ssh_user):
            tests_passed += 1
        print()
    
    # Summary
    print(f"{BLUE}=== Test Summary ==={NC}")
    print(f"Tests run: {tests_run}")
    print(f"Passed: {GREEN}{tests_passed}{NC}")
    print(f"Failed: {RED}{tests_run - tests_passed}{NC}")
    
    # Exit code based on results
    return 0 if tests_passed == tests_run else 1


if __name__ == '__main__':
    sys.exit(main())