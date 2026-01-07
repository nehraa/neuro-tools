# Neuro-Tools

Developer tooling and infrastructure for Neuro-OS - a modern operating system with AI integration.

## Overview

Neuro-Tools provides comprehensive development infrastructure including:

- **Build System**: Bazel rules for multi-language builds (Rust, Zig, Cap'n Proto)
- **Testing Framework**: Property-based testing, fuzzing, and integration tests
- **Debugging Tools**: GDB extensions, profilers, and eBPF tracing
- **CI/CD**: GitHub Actions and GitLab CI configurations
- **Scripts**: Build automation, deployment, and monitoring utilities

## Quick Start

### Clone All Repositories

```bash
./scripts/clone-all.sh --workspace ~/neuro-workspace
```

### Build Everything

```bash
cd ~/neuro-workspace
./neuro-tools/scripts/cross-repo-test.sh
```

### Create Bootable ISO

```bash
./neuro-tools/scripts/build-image.sh
```

### Test in QEMU

```bash
qemu-system-x86_64 -cdrom neuro-os.iso -m 512M
```

## Directory Structure

```
neuro-tools/
├── build/              # Build system (Bazel rules)
│   └── bazel/
│       ├── rust_rules.bzl
│       ├── zig_rules.bzl
│       └── capnproto_rules.bzl
├── testing/            # Testing framework
│   ├── property_tests.rs
│   ├── fuzzing/
│   └── integration/
├── debugging/          # Debugging tools
│   ├── gdb_scripts/
│   ├── profilers/
│   └── ebpf_tracing/
├── ci/                 # CI/CD configurations
│   ├── github-actions/
│   └── gitlab-ci/
├── scripts/            # Automation scripts
│   ├── clone-all.sh
│   ├── build-image.sh
│   ├── test-all.sh
│   ├── deploy-service.sh
│   ├── update-system.sh
│   ├── health-check.sh
│   ├── cross-repo-test.sh
│   └── neuro-sync
└── docs/               # Documentation
    └── design/
```

## Components

### Build System

Multi-language build support with Bazel:

- **Rust**: Systems programming with safety guarantees
- **Zig**: Low-level control with modern features  
- **Cap'n Proto**: High-performance serialization

See [build/README.md](build/README.md) for details.

### Testing Framework

Comprehensive testing infrastructure:

- **Property-Based Tests**: QuickCheck-style invariant testing
- **Fuzzing**: Coverage-guided fuzzing with libFuzzer
- **Integration Tests**: End-to-end system testing

See [testing/README.md](testing/README.md) for details.

### Debugging Tools

Advanced debugging capabilities:

- **GDB Scripts**: Kernel-aware debugging commands
- **Profilers**: CPU and memory profiling with flamegraphs
- **eBPF Tracing**: Real-time system call tracing

See [debugging/README.md](debugging/README.md) for details.

### CI/CD

Automated build and test pipelines:

- **GitHub Actions**: Multi-platform builds, testing, security scanning
- **GitLab CI**: Alternative CI platform with caching strategies

### Scripts

Essential automation scripts:

- `clone-all.sh` - Clone all Neuro-OS repositories
- `build-image.sh` - Create bootable ISO image
- `test-all.sh` - Run comprehensive test suite
- `deploy-service.sh` - Deploy individual services
- `update-system.sh` - Apply system updates
- `health-check.sh` - Monitor service health
- `cross-repo-test.sh` - Cross-repository integration testing
- `neuro-sync` - Dependency synchronization utility

## Usage Examples

### Development Workflow

1. **Clone repositories:**
   ```bash
   ./scripts/clone-all.sh --workspace ~/neuro
   cd ~/neuro
   ```

2. **Make changes:**
   ```bash
   cd neuro-kernel
   # Edit code...
   ```

3. **Run tests:**
   ```bash
   cd ~/neuro/neuro-tools
   ./scripts/test-all.sh --filter integration
   ```

4. **Build and test:**
   ```bash
   ./scripts/cross-repo-test.sh --clean
   ```

### Debugging

**Kernel debugging with GDB:**
```bash
# Terminal 1: Start QEMU
qemu-system-x86_64 -s -S -kernel neuro-kernel

# Terminal 2: Connect GDB
gdb neuro-kernel
(gdb) source debugging/gdb_scripts/kernel_debug.py
(gdb) target remote :1234
(gdb) neuro-tasks
```

**Performance profiling:**
```bash
./debugging/profilers/profile.sh flamegraph ./my_program
```

**System call tracing:**
```bash
sudo python3 debugging/ebpf_tracing/trace_syscalls.py --pid 1234
```

### Deployment

**Deploy a service:**
```bash
./scripts/deploy-service.sh my-service --target prod-server --restart
```

**Update system:**
```bash
./scripts/update-system.sh --target prod-server
```

**Health monitoring:**
```bash
./scripts/health-check.sh --target prod-server --watch
```

## Requirements

### Build Requirements

- **Bazel** 6.0+
- **Rust** 1.70+ (stable)
- **Zig** 0.11+
- **Python** 3.11+
- **GCC/Clang** (for C/C++ components)

### Optional Tools

- **QEMU** 8.0+ (for testing)
- **Docker** 24.0+ (for containerization)
- **Nix** 2.18+ (for reproducible environments)

### Debugging Tools

- **GDB** 12.0+
- **perf** (Linux perf tools)
- **BCC** (BPF Compiler Collection)
- **FlameGraph** (for visualization)

## Installation

### Ubuntu/Debian

```bash
# Install build essentials
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    curl \
    git \
    python3 \
    python3-pip

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install Bazel
wget https://github.com/bazelbuild/bazel/releases/download/6.0.0/bazel-6.0.0-linux-x86_64
chmod +x bazel-6.0.0-linux-x86_64
sudo mv bazel-6.0.0-linux-x86_64 /usr/local/bin/bazel

# Install debugging tools
sudo apt-get install -y \
    gdb \
    linux-tools-generic \
    bpfcc-tools \
    python3-bpfcc
```

### Arch Linux

```bash
sudo pacman -S \
    base-devel \
    rust \
    bazel \
    python \
    gdb \
    perf \
    bpf
```

## Contributing

We welcome contributions! Please see:

1. Check existing issues or create a new one
2. Fork the repository
3. Create a feature branch
4. Make your changes with tests
5. Run `./scripts/test-all.sh` to verify
6. Submit a pull request

### Code Style

- **Rust**: Use `cargo fmt` and `cargo clippy`
- **Python**: Follow PEP 8, use `black` for formatting
- **Shell**: Use ShellCheck for validation
- **Documentation**: Keep READMEs up to date

## Testing

Run the comprehensive test suite:

```bash
./scripts/test-all.sh --verbose
```

Run specific test types:

```bash
# Unit tests only
./scripts/test-all.sh --filter unit

# Integration tests
./scripts/test-all.sh --filter integration

# With parallel execution
./scripts/test-all.sh --parallel 8
```

## Documentation

- [Build System](build/README.md)
- [Testing Framework](testing/README.md)
- [Debugging Tools](debugging/README.md)
- [Design Document](docs/design/DESIGN.md)

## License

See LICENSE file in each repository.

## Support

- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions
- **Email**: neuro-os@example.com

## Related Projects

- [neuro-kernel](https://github.com/nehraa/neuro-kernel) - Neuro-OS kernel
- [neuro-services](https://github.com/nehraa/neuro-services) - System services
- [neuro-compat](https://github.com/nehraa/neuro-compat) - Compatibility layer
- [neuro-ai](https://github.com/nehraa/neuro-ai) - AI integration

## Acknowledgments

Built with modern development tools:

- [Bazel](https://bazel.build/) - Build system
- [Rust](https://www.rust-lang.org/) - Systems programming
- [Zig](https://ziglang.org/) - Low-level programming
- [Cap'n Proto](https://capnproto.org/) - Serialization
- [eBPF](https://ebpf.io/) - Kernel tracing
- [QuickCheck](https://github.com/BurntSushi/quickcheck) - Property testing
