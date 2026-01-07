"""
Bazel rules for Zig compilation in the Neuro-OS ecosystem.

This module provides hermetic, reproducible Zig builds with support for:
- Cross-compilation to multiple architectures (x86-64, ARM64, RISC-V)
- Static and dynamic library generation
- C/C++ interoperability
- Custom build modes (Debug, ReleaseSafe, ReleaseFast, ReleaseSmall)
- Integration with Bazel's remote caching

Usage:
    load("//build/bazel:zig_rules.bzl", "zig_binary", "zig_library", "zig_test")
    
    zig_binary(
        name = "my_app",
        srcs = ["src/main.zig"],
        deps = ["//lib:mylib"],
        optimize = "ReleaseSafe",
    )
"""

def _zig_toolchain_impl(ctx):
    """
    Configure the Zig toolchain for hermetic builds.
    
    Zig provides a self-contained toolchain that includes:
    - The Zig compiler (zig)
    - C/C++ compiler capabilities via LLVM
    - Cross-compilation support out of the box
    - Standard library for the target platform
    
    Args:
        ctx: The rule context from Bazel
        
    Returns:
        A list of providers including the ZigToolchainInfo
    """
    toolchain_info = platform_common.ToolchainInfo(
        zig = ctx.attr.zig,
        zig_lib = ctx.attr.zig_lib,
        target = ctx.attr.target,
    )
    return [toolchain_info]

zig_toolchain = rule(
    implementation = _zig_toolchain_impl,
    attrs = {
        "zig": attr.label(
            executable = True,
            cfg = "exec",
            doc = "The zig compiler executable",
        ),
        "zig_lib": attr.label(
            allow_files = True,
            doc = "The Zig standard library",
        ),
        "target": attr.string(
            doc = "The target triple (e.g., x86_64-linux-gnu)",
        ),
    },
    doc = "Defines a Zig toolchain for hermetic builds",
)

def _zig_library_impl(ctx):
    """
    Compile Zig source files into a library.
    
    This rule handles:
    - Dependency resolution and linking
    - C/C++ header dependencies
    - Static and dynamic library generation
    - Custom build modes and optimization
    - Cross-compilation support
    
    Args:
        ctx: The rule context from Bazel
        
    Returns:
        DefaultInfo provider with compiled library outputs
    """
    # Get the Zig toolchain
    toolchain = ctx.toolchains["//build/bazel:zig_toolchain_type"]
    
    # Prepare source files
    srcs = ctx.files.srcs
    main_src = ctx.file.main
    
    # Determine output file based on library type
    if ctx.attr.linkage == "dynamic":
        output_file = ctx.actions.declare_file("lib" + ctx.label.name + ".so")
    else:
        output_file = ctx.actions.declare_file("lib" + ctx.label.name + ".a")
    
    # Build command arguments
    args = ctx.actions.args()
    args.add("build-lib")
    args.add(main_src.path)
    
    # Set output name
    args.add("-femit-bin=" + output_file.path)
    
    # Set optimization mode
    if ctx.attr.optimize:
        args.add("-O" + ctx.attr.optimize)
    
    # Set target architecture
    if toolchain.target:
        args.add("-target", toolchain.target)
    
    # Add linkage mode
    if ctx.attr.linkage == "dynamic":
        args.add("-dynamic")
    
    # Add include paths for C headers
    for hdr in ctx.files.hdrs:
        args.add("-I", hdr.dirname)
    
    # Add dependencies
    for dep in ctx.attr.deps:
        dep_files = dep.files.to_list()
        if dep_files:
            args.add("-L", dep_files[0].dirname)
            # Extract library name from file path
            lib_name = dep_files[0].basename
            if lib_name.startswith("lib"):
                lib_name = lib_name[3:]
            if lib_name.endswith(".a") or lib_name.endswith(".so"):
                lib_name = lib_name.rsplit(".", 1)[0]
            args.add("-l", lib_name)
    
    # Collect all input files
    inputs = srcs + ctx.files.hdrs
    for dep in ctx.attr.deps:
        inputs.extend(dep.files.to_list())
    
    # Execute zig build-lib
    ctx.actions.run(
        outputs = [output_file],
        inputs = inputs,
        executable = toolchain.zig,
        arguments = [args],
        mnemonic = "ZigCompile",
        progress_message = "Compiling Zig library %s" % ctx.label.name,
    )
    
    return [DefaultInfo(files = depset([output_file]))]

zig_library = rule(
    implementation = _zig_library_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".zig"],
            doc = "Zig source files to compile",
        ),
        "main": attr.label(
            allow_single_file = [".zig"],
            mandatory = True,
            doc = "Main Zig source file (library entry point)",
        ),
        "hdrs": attr.label_list(
            allow_files = [".h", ".hpp"],
            doc = "C/C++ header files",
        ),
        "deps": attr.label_list(
            doc = "Dependencies for this library",
        ),
        "optimize": attr.string(
            default = "Debug",
            values = ["Debug", "ReleaseSafe", "ReleaseFast", "ReleaseSmall"],
            doc = "Build mode and optimization level",
        ),
        "linkage": attr.string(
            default = "static",
            values = ["static", "dynamic"],
            doc = "Library linkage type",
        ),
    },
    toolchains = ["//build/bazel:zig_toolchain_type"],
    doc = "Compiles Zig sources into a library",
)

def _zig_binary_impl(ctx):
    """
    Compile Zig source files into an executable binary.
    
    This rule produces a standalone executable with:
    - Full dependency linking
    - Optimization and build mode selection
    - Cross-compilation support
    - C/C++ interoperability
    - Custom linker flags
    
    Args:
        ctx: The rule context from Bazel
        
    Returns:
        DefaultInfo provider with the compiled binary
    """
    # Get the Zig toolchain
    toolchain = ctx.toolchains["//build/bazel:zig_toolchain_type"]
    
    # Prepare source files
    srcs = ctx.files.srcs
    main_src = ctx.file.main
    
    # Determine output binary
    output_file = ctx.actions.declare_file(ctx.label.name)
    
    # Build command arguments
    args = ctx.actions.args()
    args.add("build-exe")
    args.add(main_src.path)
    
    # Set output name
    args.add("-femit-bin=" + output_file.path)
    
    # Set optimization mode
    if ctx.attr.optimize:
        args.add("-O" + ctx.attr.optimize)
    
    # Set target architecture
    if toolchain.target:
        args.add("-target", toolchain.target)
    
    # Add C library linking if needed
    if ctx.attr.link_libc:
        args.add("-lc")
    
    # Add include paths for C headers
    for hdr in ctx.files.hdrs:
        args.add("-I", hdr.dirname)
    
    # Add dependencies
    for dep in ctx.attr.deps:
        dep_files = dep.files.to_list()
        if dep_files:
            args.add("-L", dep_files[0].dirname)
            # Extract library name from file path
            lib_name = dep_files[0].basename
            if lib_name.startswith("lib"):
                lib_name = lib_name[3:]
            if lib_name.endswith(".a") or lib_name.endswith(".so"):
                lib_name = lib_name.rsplit(".", 1)[0]
            args.add("-l", lib_name)
    
    # Add custom linker flags
    for flag in ctx.attr.linkopts:
        args.add(flag)
    
    # Collect all input files
    inputs = srcs + ctx.files.hdrs
    for dep in ctx.attr.deps:
        inputs.extend(dep.files.to_list())
    
    # Execute zig build-exe
    ctx.actions.run(
        outputs = [output_file],
        inputs = inputs,
        executable = toolchain.zig,
        arguments = [args],
        mnemonic = "ZigCompile",
        progress_message = "Compiling Zig binary %s" % ctx.label.name,
    )
    
    return [DefaultInfo(
        files = depset([output_file]),
        executable = output_file,
    )]

zig_binary = rule(
    implementation = _zig_binary_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".zig"],
            doc = "Zig source files to compile",
        ),
        "main": attr.label(
            allow_single_file = [".zig"],
            mandatory = True,
            doc = "Main Zig source file with pub fn main()",
        ),
        "hdrs": attr.label_list(
            allow_files = [".h", ".hpp"],
            doc = "C/C++ header files",
        ),
        "deps": attr.label_list(
            doc = "Dependencies for this binary",
        ),
        "optimize": attr.string(
            default = "Debug",
            values = ["Debug", "ReleaseSafe", "ReleaseFast", "ReleaseSmall"],
            doc = "Build mode and optimization level",
        ),
        "link_libc": attr.bool(
            default = False,
            doc = "Link against the C standard library",
        ),
        "linkopts": attr.string_list(
            doc = "Additional linker flags",
        ),
    },
    executable = True,
    toolchains = ["//build/bazel:zig_toolchain_type"],
    doc = "Compiles Zig sources into an executable binary",
)

def _zig_test_impl(ctx):
    """
    Compile and configure Zig test targets.
    
    This rule creates test executables with:
    - Automatic test discovery from Zig test blocks
    - Integration with Bazel's test infrastructure
    - Test filtering capabilities
    - Assertion and error handling
    
    Args:
        ctx: The rule context from Bazel
        
    Returns:
        DefaultInfo provider with test executable
    """
    # Get the Zig toolchain
    toolchain = ctx.toolchains["//build/bazel:zig_toolchain_type"]
    
    # Prepare source files
    srcs = ctx.files.srcs
    main_src = ctx.file.main
    
    # Determine output test binary
    output_file = ctx.actions.declare_file(ctx.label.name)
    
    # Build command arguments
    args = ctx.actions.args()
    args.add("test")
    args.add(main_src.path)
    
    # Set output name
    args.add("-femit-bin=" + output_file.path)
    
    # Set optimization mode (usually Debug for tests)
    args.add("-ODebug")
    
    # Set target architecture
    if toolchain.target:
        args.add("-target", toolchain.target)
    
    # Add dependencies
    for dep in ctx.attr.deps:
        dep_files = dep.files.to_list()
        if dep_files:
            args.add("-L", dep_files[0].dirname)
            lib_name = dep_files[0].basename
            if lib_name.startswith("lib"):
                lib_name = lib_name[3:]
            if lib_name.endswith(".a") or lib_name.endswith(".so"):
                lib_name = lib_name.rsplit(".", 1)[0]
            args.add("-l", lib_name)
    
    # Collect all input files
    inputs = srcs
    for dep in ctx.attr.deps:
        inputs.extend(dep.files.to_list())
    
    # Execute zig test
    ctx.actions.run(
        outputs = [output_file],
        inputs = inputs,
        executable = toolchain.zig,
        arguments = [args],
        mnemonic = "ZigTest",
        progress_message = "Compiling Zig test %s" % ctx.label.name,
    )
    
    return [DefaultInfo(
        files = depset([output_file]),
        executable = output_file,
    )]

zig_test = rule(
    implementation = _zig_test_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".zig"],
            doc = "Zig test source files",
        ),
        "main": attr.label(
            allow_single_file = [".zig"],
            mandatory = True,
            doc = "Main Zig test file",
        ),
        "deps": attr.label_list(
            doc = "Dependencies for this test",
        ),
    },
    test = True,
    toolchains = ["//build/bazel:zig_toolchain_type"],
    doc = "Compiles and runs Zig tests",
)
