"""
Bazel rules for Rust compilation in the Neuro-OS ecosystem.

This module provides hermetic, reproducible Rust builds with support for:
- Cross-compilation to multiple targets (x86-64, ARM64, RISC-V)
- Dependency management with Cargo
- Static and dynamic library generation
- Binary compilation with custom flags
- Integration with Bazel's remote caching and execution

Usage:
    load("//build/bazel:rust_rules.bzl", "rust_binary", "rust_library", "rust_test")
    
    rust_binary(
        name = "my_app",
        srcs = ["src/main.rs"],
        deps = ["//lib:mylib"],
        edition = "2021",
    )
"""

def _rust_toolchain_impl(ctx):
    """
    Configure the Rust toolchain for hermetic builds.
    
    This includes setting up the appropriate rustc, cargo, and standard library
    for the target platform. Supports cross-compilation by allowing multiple
    toolchain configurations.
    
    Args:
        ctx: The rule context from Bazel
        
    Returns:
        A list of providers including the RustToolchainInfo
    """
    toolchain_info = platform_common.ToolchainInfo(
        rustc = ctx.attr.rustc,
        cargo = ctx.attr.cargo,
        rust_lib = ctx.attr.rust_lib,
        target_triple = ctx.attr.target_triple,
    )
    return [toolchain_info]

rust_toolchain = rule(
    implementation = _rust_toolchain_impl,
    attrs = {
        "rustc": attr.label(
            executable = True,
            cfg = "exec",
            doc = "The rustc compiler executable",
        ),
        "cargo": attr.label(
            executable = True,
            cfg = "exec",
            doc = "The cargo build tool executable",
        ),
        "rust_lib": attr.label(
            allow_files = True,
            doc = "The Rust standard library",
        ),
        "target_triple": attr.string(
            doc = "The target triple (e.g., x86_64-unknown-linux-gnu)",
        ),
    },
    doc = "Defines a Rust toolchain for hermetic builds",
)

def _rust_library_impl(ctx):
    """
    Compile Rust source files into a library (rlib or dylib).
    
    This rule handles:
    - Dependency resolution and linking
    - Compilation flags and optimization levels
    - Generation of both static and dynamic libraries
    - Hermetic build environment
    
    Args:
        ctx: The rule context from Bazel
        
    Returns:
        DefaultInfo provider with compiled library outputs
    """
    # Get the Rust toolchain
    toolchain = ctx.toolchains["@rules_rust//rust:toolchain_type"]
    
    # Prepare source files
    srcs = ctx.files.srcs
    
    # Determine output file
    output_file = ctx.actions.declare_file(
        ctx.label.name + (".so" if ctx.attr.crate_type == "dylib" else ".rlib")
    )
    
    # Build command arguments
    args = ctx.actions.args()
    args.add("--crate-name", ctx.label.name)
    args.add("--crate-type", ctx.attr.crate_type)
    args.add("--edition", ctx.attr.edition)
    args.add("--out-dir", output_file.dirname)
    
    # Add optimization flags
    if ctx.attr.opt_level:
        args.add("-C", "opt-level=" + ctx.attr.opt_level)
    
    # Add dependencies
    for dep in ctx.attr.deps:
        args.add("--extern", dep.label.name + "=" + dep.files.to_list()[0].path)
    
    # Add source files
    args.add_all(srcs)
    
    # Execute rustc
    ctx.actions.run(
        outputs = [output_file],
        inputs = srcs + [dep.files.to_list()[0] for dep in ctx.attr.deps],
        executable = toolchain.rustc,
        arguments = [args],
        mnemonic = "RustCompile",
        progress_message = "Compiling Rust library %s" % ctx.label.name,
    )
    
    return [DefaultInfo(files = depset([output_file]))]

rust_library = rule(
    implementation = _rust_library_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".rs"],
            doc = "Rust source files to compile",
        ),
        "deps": attr.label_list(
            doc = "Dependencies for this library",
        ),
        "crate_type": attr.string(
            default = "rlib",
            values = ["rlib", "dylib", "staticlib"],
            doc = "The type of library to produce",
        ),
        "edition": attr.string(
            default = "2021",
            values = ["2015", "2018", "2021"],
            doc = "Rust edition to use",
        ),
        "opt_level": attr.string(
            default = "2",
            values = ["0", "1", "2", "3", "s", "z"],
            doc = "Optimization level",
        ),
    },
    toolchains = ["@rules_rust//rust:toolchain_type"],
    doc = "Compiles Rust sources into a library",
)

def _rust_binary_impl(ctx):
    """
    Compile Rust source files into an executable binary.
    
    This rule produces a standalone executable with:
    - Full dependency linking
    - Optimization and stripping options
    - Support for custom compilation flags
    - Hermetic build environment
    
    Args:
        ctx: The rule context from Bazel
        
    Returns:
        DefaultInfo provider with the compiled binary
    """
    # Get the Rust toolchain
    toolchain = ctx.toolchains["@rules_rust//rust:toolchain_type"]
    
    # Prepare source files
    srcs = ctx.files.srcs
    
    # Determine output binary
    output_file = ctx.actions.declare_file(ctx.label.name)
    
    # Build command arguments
    args = ctx.actions.args()
    args.add("--crate-name", ctx.label.name)
    args.add("--crate-type", "bin")
    args.add("--edition", ctx.attr.edition)
    args.add("-o", output_file.path)
    
    # Add optimization flags
    if ctx.attr.opt_level:
        args.add("-C", "opt-level=" + ctx.attr.opt_level)
    
    # Add link-time optimization if requested
    if ctx.attr.lto:
        args.add("-C", "lto=fat")
    
    # Add panic behavior
    args.add("-C", "panic=" + ctx.attr.panic)
    
    # Add dependencies
    for dep in ctx.attr.deps:
        args.add("--extern", dep.label.name + "=" + dep.files.to_list()[0].path)
    
    # Add source files
    args.add_all(srcs)
    
    # Execute rustc
    ctx.actions.run(
        outputs = [output_file],
        inputs = srcs + [dep.files.to_list()[0] for dep in ctx.attr.deps],
        executable = toolchain.rustc,
        arguments = [args],
        mnemonic = "RustCompile",
        progress_message = "Compiling Rust binary %s" % ctx.label.name,
    )
    
    return [DefaultInfo(
        files = depset([output_file]),
        executable = output_file,
    )]

rust_binary = rule(
    implementation = _rust_binary_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".rs"],
            mandatory = True,
            doc = "Rust source files to compile",
        ),
        "deps": attr.label_list(
            doc = "Dependencies for this binary",
        ),
        "edition": attr.string(
            default = "2021",
            values = ["2015", "2018", "2021"],
            doc = "Rust edition to use",
        ),
        "opt_level": attr.string(
            default = "2",
            values = ["0", "1", "2", "3", "s", "z"],
            doc = "Optimization level",
        ),
        "lto": attr.bool(
            default = False,
            doc = "Enable link-time optimization",
        ),
        "panic": attr.string(
            default = "unwind",
            values = ["unwind", "abort"],
            doc = "Panic strategy",
        ),
    },
    executable = True,
    toolchains = ["@rules_rust//rust:toolchain_type"],
    doc = "Compiles Rust sources into an executable binary",
)

def _rust_test_impl(ctx):
    """
    Compile and configure Rust test targets.
    
    This rule creates test executables with:
    - Automatic test discovery from #[test] annotations
    - Integration with Bazel's test infrastructure
    - Support for property-based testing frameworks
    - Test filtering and parallel execution
    
    Args:
        ctx: The rule context from Bazel
        
    Returns:
        DefaultInfo provider with test executable
    """
    # Get the Rust toolchain
    toolchain = ctx.toolchains["@rules_rust//rust:toolchain_type"]
    
    # Prepare source files
    srcs = ctx.files.srcs
    
    # Determine output test binary
    output_file = ctx.actions.declare_file(ctx.label.name)
    
    # Build command arguments
    args = ctx.actions.args()
    args.add("--crate-name", ctx.label.name)
    args.add("--test")
    args.add("--edition", ctx.attr.edition)
    args.add("-o", output_file.path)
    
    # Add dependencies
    for dep in ctx.attr.deps:
        args.add("--extern", dep.label.name + "=" + dep.files.to_list()[0].path)
    
    # Add source files
    args.add_all(srcs)
    
    # Execute rustc
    ctx.actions.run(
        outputs = [output_file],
        inputs = srcs + [dep.files.to_list()[0] for dep in ctx.attr.deps],
        executable = toolchain.rustc,
        arguments = [args],
        mnemonic = "RustTest",
        progress_message = "Compiling Rust test %s" % ctx.label.name,
    )
    
    return [DefaultInfo(
        files = depset([output_file]),
        executable = output_file,
    )]

rust_test = rule(
    implementation = _rust_test_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".rs"],
            mandatory = True,
            doc = "Rust test source files",
        ),
        "deps": attr.label_list(
            doc = "Dependencies for this test",
        ),
        "edition": attr.string(
            default = "2021",
            values = ["2015", "2018", "2021"],
            doc = "Rust edition to use",
        ),
    },
    test = True,
    toolchains = ["@rules_rust//rust:toolchain_type"],
    doc = "Compiles and runs Rust tests",
)
