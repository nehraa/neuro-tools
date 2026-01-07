# Neuro-Tools: Development Tooling Design

## Overview

Neuro-Tools provides build system integration, testing frameworks, CI/CD configuration, and developer utilities.

## Components

### 1. Build System (`build/`)

**Bazel Rules**:
- Multi-language support (Rust, C++, Python, Zig)
- Reproducible hermetic builds
- Remote caching and execution

**Key Files**:
- `bazel/rust_rules.bzl`: Rust compilation rules
- `bazel/zig_rules.bzl`: Zig compilation rules
- `bazel/capnproto_rules.bzl`: Cap'n Proto schema compilation

### 2. Testing Framework (`testing/`)

**Property-Based Testing** (`testing/property_tests.rs`):
- QuickCheck integration
- Arbitrary data generators
- Property specifications

**Fuzzing** (`testing/fuzzing/`):
- libFuzzer harness
- Corpus minimization
- Crash reporting

**Integration Tests** (`testing/integration/`):
- End-to-end scenarios
- Multi-component coordination
- Performance benchmarks

### 3. Debugging Tools (`debugging/`)

**GDB Scripts** (`debugging/gdb_scripts/`):
- Kernel debugging macros
- Symbol table helpers
- Task introspection

**Profiling** (`debugging/profilers/`):
- `perf` integration
- Flamegraph generation
- CPU/memory profiling

**eBPF Tracing** (`debugging/ebpf_tracing/`):
- Real-time syscall tracing
- Performance hotspot detection
- Memory leak detection

### 4. CI/CD (`ci/`)

**GitHub Actions** (`ci/github-actions/`):
- Build workflow
- Test matrix (x86-64, ARM64, RISC-V)
- Performance regression detection

**GitLab CI** (`ci/gitlab-ci/`):
- Alternative CI platform
- Cache strategy
- Artifact management

### 5. Scripts (`scripts/`)

**Build Helpers**:
- `clone-all.sh`: Clone all repos
- `build-image.sh`: Create bootable ISO
- `test-all.sh`: Run all tests

**Deployment**:
- `deploy-service.sh`: Deploy single service
- `update-system.sh`: Apply system updates
- `health-check.sh`: Monitor service health

## Key Utilities

### neuro-sync: Dependency Synchronizer

```python
#!/usr/bin/env python3
"""
Synchronize MODULE.yaml dependencies across repositories
"""
import yaml
import subprocess
import argparse

def update_dependencies(repo_path: str):
    with open(f"{repo_path}/MODULE.yaml") as f:
        config = yaml.safe_load(f)
    
    for dep in config.get("dependencies", []):
        dep_repo = dep["repo"]
        dep_version = dep["version"]
        
        # Fetch latest commit for tag
        result = subprocess.run(
            ["git", "ls-remote", f"git@github.com:nehraa/{dep_repo}.git", 
             f"refs/tags/{dep_version}"],
            capture_output=True, text=True
        )
        
        if result.returncode == 0:
            latest_commit = result.stdout.split()[0]
            dep["commit"] = latest_commit
    
    with open(f"{repo_path}/MODULE.yaml", "w") as f:
        yaml.dump(config, f)
    
    print(f"Updated {repo_path}/MODULE.yaml")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("repo", help="Repository path")
    parser.add_argument("--all", action="store_true", help="Update all repos")
    args = parser.parse_args()
    
    if args.all:
        repos = ["neuro-kernel", "neuro-services", "neuro-compat", "neuro-ai"]
        for repo in repos:
            update_dependencies(repo)
    else:
        update_dependencies(args.repo)
```

### Cross-Repo Test Coordinator

```bash
#!/bin/bash
# Build all repos in dependency order, then run integration tests

set -euo pipefail

echo "Building in dependency order..."

echo "1. Building kernel..."
cd neuro-kernel && bazel build //... && cd ..

echo "2. Building services..."
cd neuro-services && bazel build //... && cd ..

echo "3. Building compat..."
cd neuro-compat && bazel build //... && cd ..

echo "4. Building AI..."
cd neuro-ai && bazel build //... && cd ..

echo "5. Running integration tests..."
bazel test //integration_tests:all

echo "✅ All builds and tests passed"
```

## MODULE.yaml

```yaml
module:
  name: "neuro_tools"
  version: "0.1.0"
  
  components:
    build: []
    testing: ["quickcheck", "libfuzzer"]
    debugging: ["gdb", "perf", "ebpf"]
    ci: ["github-actions", "gitlab-ci"]
    scripts: []
  
  external_tools:
    - bazel: "6.0"
    - nix: "2.18"
    - docker: "24.0"
    - qemu: "8.0"
```

