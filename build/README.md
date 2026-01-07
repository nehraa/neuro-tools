# Neuro-OS Build System

This directory contains Bazel build rules for the Neuro-OS project.

## Overview

The build system provides hermetic, reproducible builds for multiple languages:

- **Rust**: High-performance systems programming
- **Zig**: Low-level systems programming with safety
- **Cap'n Proto**: Schema-based serialization and RPC

## Structure

```
build/
└── bazel/
    ├── rust_rules.bzl       # Rust compilation rules
    ├── zig_rules.bzl        # Zig compilation rules
    └── capnproto_rules.bzl  # Cap'n Proto schema compilation
```

## Usage

### Rust Rules

```starlark
load("//build/bazel:rust_rules.bzl", "rust_binary", "rust_library", "rust_test")

rust_library(
    name = "mylib",
    srcs = ["src/lib.rs"],
    edition = "2021",
)

rust_binary(
    name = "myapp",
    srcs = ["src/main.rs"],
    deps = [":mylib"],
    edition = "2021",
)

rust_test(
    name = "mytest",
    srcs = ["tests/test.rs"],
    deps = [":mylib"],
)
```

### Zig Rules

```starlark
load("//build/bazel:zig_rules.bzl", "zig_binary", "zig_library")

zig_library(
    name = "ziglib",
    main = "src/lib.zig",
    srcs = glob(["src/**/*.zig"]),
    optimize = "ReleaseSafe",
)

zig_binary(
    name = "zigapp",
    main = "src/main.zig",
    deps = [":ziglib"],
    optimize = "ReleaseFast",
)
```

### Cap'n Proto Rules

```starlark
load("//build/bazel:capnproto_rules.bzl", "capnp_cc_library", "capnp_rust_library")

capnp_cc_library(
    name = "schema_cc",
    srcs = ["schema.capnp"],
)

capnp_rust_library(
    name = "schema_rust",
    srcs = ["schema.capnp"],
)
```

## Features

### Hermetic Builds

All builds are hermetic and reproducible:
- Dependencies are explicitly declared
- Build inputs are content-addressed
- No reliance on system packages
- Consistent results across machines

### Remote Caching

Bazel supports remote caching for faster builds:

```bash
bazel build --remote_cache=grpc://cache.example.com:9092 //...
```

### Cross-Compilation

Easily build for multiple targets:

```bash
bazel build --platforms=//platforms:riscv64 //...
bazel build --platforms=//platforms:aarch64 //...
```

### Testing

Run all tests:

```bash
bazel test //...
```

Run specific tests:

```bash
bazel test //kernel:unit_tests
bazel test //services:integration_tests
```

## Best Practices

1. **Declare all dependencies**: Every external dependency should be declared
2. **Use visibility**: Control which targets can depend on your code
3. **Write hermetic tests**: Tests should not depend on system state
4. **Cache aggressively**: Use remote caching for CI/CD
5. **Keep BUILD files simple**: Complex logic belongs in .bzl files

## Integration with Other Tools

### Cargo Integration

For Rust projects that use Cargo, we provide bridge rules:

```starlark
load("//build/bazel:cargo_bridge.bzl", "cargo_workspace")

cargo_workspace(
    name = "cargo_deps",
    manifests = ["Cargo.toml"],
)
```

### Nix Integration

Bazel can use Nix for dependency management:

```starlark
load("@rules_nixpkgs//nixpkgs:nixpkgs.bzl", "nixpkgs_package")

nixpkgs_package(
    name = "rustc",
    repository = "@nixpkgs",
)
```

## Troubleshooting

### Build Failures

1. Clean the build cache: `bazel clean --expunge`
2. Check dependency declarations
3. Verify toolchain configuration
4. Enable verbose output: `bazel build -s //...`

### Slow Builds

1. Enable remote caching
2. Use `--jobs` to control parallelism
3. Profile builds: `bazel build --profile=profile.json //...`
4. Analyze with: `bazel analyze-profile profile.json`

## Documentation

- [Bazel Documentation](https://bazel.build/)
- [Rust Rules](https://bazelbuild.github.io/rules_rust/)
- [Zig Rules](https://github.com/ziglang/zig-bazel)
- [Cap'n Proto](https://capnproto.org/)

## Contributing

When adding new build rules:

1. Follow existing patterns in `*_rules.bzl` files
2. Add comprehensive documentation
3. Include usage examples
4. Write tests for the rules
5. Update this README
