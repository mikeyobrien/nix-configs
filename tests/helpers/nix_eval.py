#!/usr/bin/env python3
# ABOUTME: Python helper for evaluating Nix configurations in tests
# ABOUTME: Provides utilities for testing NixOS modules and configurations

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Union

# Get the project root
HELPER_DIR = Path(__file__).parent.absolute()
PROJECT_ROOT = HELPER_DIR.parent.parent


def get_absolute_path(path: Union[str, Path]) -> Path:
    """Convert a path to absolute, resolving relative to project root."""
    path = Path(path)
    if not path.is_absolute():
        path = PROJECT_ROOT / path
    return path


def nix_eval(expr: str, raw: bool = False) -> Any:
    """Evaluate a Nix expression and return the result."""
    cmd = ["nix-instantiate", "--eval", "--strict"]
    if not raw:
        cmd.append("--json")
    cmd.extend(["-E", expr])
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        if raw:
            return result.stdout.strip()
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Nix evaluation failed: {e.stderr}", file=sys.stderr)
        return None
    except json.JSONDecodeError as e:
        print(f"Failed to parse JSON output: {e}", file=sys.stderr)
        return None


def eval_config_attr(attr: str, module_path: Union[str, Path], extra_modules: List[str] = None) -> Any:
    """Evaluate a specific attribute from a NixOS configuration."""
    module_path = get_absolute_path(module_path)
    extra_modules = extra_modules or []
    
    extra_modules_str = " ".join(extra_modules)
    
    expr = f"""
    let
      evalConfig = import {HELPER_DIR}/eval-config.nix {{
        modules = [ {module_path} {extra_modules_str} ];
      }};
    in evalConfig.{attr}
    """
    
    return nix_eval(expr)


def check_module_evaluates(module_path: Union[str, Path]) -> bool:
    """Check if a NixOS module evaluates without errors."""
    module_path = get_absolute_path(module_path)
    
    expr = f"""
    let
      evalConfig = import {HELPER_DIR}/eval-config.nix {{
        modules = [ {module_path} ];
      }};
    in evalConfig.config.networking.hostName or null
    """
    
    result = nix_eval(expr, raw=True)
    return result is not None


def get_system_packages(module_path: Union[str, Path]) -> List[str]:
    """Get a list of system packages from a configuration."""
    module_path = get_absolute_path(module_path)
    
    expr = f"""
    let
      evalConfig = import {HELPER_DIR}/eval-config.nix {{
        modules = [ {module_path} ];
      }};
      pkgNames = map (p: p.pname or p.name or "unknown") 
                     evalConfig.config.environment.systemPackages;
    in pkgNames
    """
    
    result = nix_eval(expr)
    if result is None:
        return []
    
    # Sort and deduplicate
    return sorted(set(result))


def check_service_enabled(service: str, module_path: Union[str, Path]) -> bool:
    """Check if a service is enabled in the configuration."""
    enabled = eval_config_attr(f"config.services.{service}.enable", module_path)
    return enabled is True


def get_firewall_tcp_ports(module_path: Union[str, Path]) -> List[int]:
    """Get the list of allowed TCP ports from firewall configuration."""
    ports = eval_config_attr("config.networking.firewall.allowedTCPPorts", module_path)
    return ports or []


def get_firewall_udp_ports(module_path: Union[str, Path]) -> List[int]:
    """Get the list of allowed UDP ports from firewall configuration."""
    ports = eval_config_attr("config.networking.firewall.allowedUDPPorts", module_path)
    return ports or []


def check_firewall_enabled(module_path: Union[str, Path]) -> bool:
    """Check if the firewall is enabled."""
    enabled = eval_config_attr("config.networking.firewall.enable", module_path)
    return enabled is True


def get_kernel_sysctl(param: str, module_path: Union[str, Path]) -> Any:
    """Get a kernel sysctl parameter value."""
    return eval_config_attr(f'config.boot.kernel.sysctl."{param}"', module_path)


def main():
    """CLI interface for testing."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Nix evaluation helper for tests")
    parser.add_argument("action", choices=[
        "check-module",
        "get-packages",
        "check-service",
        "get-attr",
        "get-tcp-ports",
        "get-udp-ports"
    ])
    parser.add_argument("module", help="Path to NixOS module")
    parser.add_argument("--service", help="Service name for check-service")
    parser.add_argument("--attr", help="Attribute path for get-attr")
    
    args = parser.parse_args()
    
    if args.action == "check-module":
        result = check_module_evaluates(args.module)
        print("true" if result else "false")
        sys.exit(0 if result else 1)
    
    elif args.action == "get-packages":
        packages = get_system_packages(args.module)
        for pkg in packages:
            print(pkg)
    
    elif args.action == "check-service":
        if not args.service:
            parser.error("--service required for check-service")
        result = check_service_enabled(args.service, args.module)
        print("true" if result else "false")
        sys.exit(0 if result else 1)
    
    elif args.action == "get-attr":
        if not args.attr:
            parser.error("--attr required for get-attr")
        result = eval_config_attr(args.attr, args.module)
        if isinstance(result, (dict, list)):
            print(json.dumps(result))
        else:
            print(result)
    
    elif args.action == "get-tcp-ports":
        ports = get_firewall_tcp_ports(args.module)
        for port in ports:
            print(port)
    
    elif args.action == "get-udp-ports":
        ports = get_firewall_udp_ports(args.module)
        for port in ports:
            print(port)


if __name__ == "__main__":
    main()