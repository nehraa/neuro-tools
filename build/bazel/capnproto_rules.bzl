"""
Bazel rules for Cap'n Proto schema compilation in the Neuro-OS ecosystem.

Cap'n Proto is a high-performance data interchange format used for:
- Inter-process communication (IPC)
- Network serialization with zero-copy reads
- RPC (Remote Procedure Call) interfaces
- Language-agnostic data schemas

This module provides:
- Schema compilation to multiple target languages (C++, Rust, Python)
- Dependency tracking between schema files
- Integration with Bazel's build graph
- Support for Cap'n Proto RPC code generation

Usage:
    load("//build/bazel:capnproto_rules.bzl", "capnp_library", "capnp_cc_library", "capnp_rust_library")
    
    capnp_library(
        name = "my_schema",
        srcs = ["schema.capnp"],
        deps = [":base_schema"],
    )
"""

def _capnp_library_impl(ctx):
    """
    Compile Cap'n Proto schema files.
    
    This rule processes .capnp schema files and generates:
    - Compiled schema outputs for various target languages
    - Import resolution for dependent schemas
    - Type checking and validation
    
    Args:
        ctx: The rule context from Bazel
        
    Returns:
        CapnProtoInfo provider with schema outputs
    """
    # Get the Cap'n Proto compiler
    capnp_compiler = ctx.executable._capnp_compiler
    
    # Prepare schema files
    srcs = ctx.files.srcs
    
    # Collect all schema outputs
    schema_outputs = []
    
    # Process each schema file
    for src in srcs:
        # Create output file for compiled schema
        output_file = ctx.actions.declare_file(
            src.basename.replace(".capnp", ".capnp.bin")
        )
        schema_outputs.append(output_file)
        
        # Build command arguments
        args = ctx.actions.args()
        args.add("compile")
        args.add("-o", output_file.path)
        
        # Add import paths from dependencies
        import_paths = []
        for dep in ctx.attr.deps:
            if hasattr(dep, "capnp_import_path"):
                import_paths.append(dep.capnp_import_path)
        
        for import_path in import_paths:
            args.add("-I", import_path)
        
        # Add the schema file
        args.add(src.path)
        
        # Collect input files
        inputs = [src]
        for dep in ctx.attr.deps:
            inputs.extend(dep.files.to_list())
        
        # Execute capnp compile
        ctx.actions.run(
            outputs = [output_file],
            inputs = inputs,
            executable = capnp_compiler,
            arguments = [args],
            mnemonic = "CapnpCompile",
            progress_message = "Compiling Cap'n Proto schema %s" % src.basename,
        )
    
    return [
        DefaultInfo(files = depset(schema_outputs)),
        # Provide import path for dependent rules
        OutputGroupInfo(
            capnp_import_path = ctx.label.package,
        ),
    ]

capnp_library = rule(
    implementation = _capnp_library_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".capnp"],
            mandatory = True,
            doc = "Cap'n Proto schema files",
        ),
        "deps": attr.label_list(
            doc = "Dependencies on other Cap'n Proto schemas",
        ),
        "_capnp_compiler": attr.label(
            default = "@capnproto//:capnp",
            executable = True,
            cfg = "exec",
            doc = "The Cap'n Proto compiler",
        ),
    },
    doc = "Compiles Cap'n Proto schema files",
)

def _capnp_cc_library_impl(ctx):
    """
    Generate C++ code from Cap'n Proto schemas.
    
    This rule produces:
    - C++ header files (.capnp.h) with type definitions
    - C++ source files (.capnp.c++) with serialization code
    - Integration with C++ compilation rules
    
    Args:
        ctx: The rule context from Bazel
        
    Returns:
        CcInfo provider with generated C++ sources
    """
    # Get the Cap'n Proto C++ code generator
    capnp_compiler = ctx.executable._capnp_compiler
    
    # Prepare schema files
    srcs = ctx.files.srcs
    
    # Collect all generated C++ files
    cc_headers = []
    cc_sources = []
    
    # Process each schema file
    for src in srcs:
        # Create output files
        base_name = src.basename.replace(".capnp", "")
        header_file = ctx.actions.declare_file(base_name + ".capnp.h")
        source_file = ctx.actions.declare_file(base_name + ".capnp.c++")
        
        cc_headers.append(header_file)
        cc_sources.append(source_file)
        
        # Build command arguments
        args = ctx.actions.args()
        args.add("compile")
        args.add("-o", "c++:" + header_file.dirname)
        
        # Add import paths
        for dep in ctx.attr.deps:
            if hasattr(dep, "capnp_import_path"):
                args.add("-I", dep.capnp_import_path)
        
        # Add the schema file
        args.add(src.path)
        
        # Collect input files
        inputs = [src]
        for dep in ctx.attr.deps:
            inputs.extend(dep.files.to_list())
        
        # Execute capnp compile for C++
        ctx.actions.run(
            outputs = [header_file, source_file],
            inputs = inputs,
            executable = capnp_compiler,
            arguments = [args],
            mnemonic = "CapnpCxxCompile",
            progress_message = "Generating C++ from Cap'n Proto schema %s" % src.basename,
        )
    
    # Return C++ compilation info
    return [
        DefaultInfo(files = depset(cc_headers + cc_sources)),
        CcInfo(
            compilation_context = cc_common.create_compilation_context(
                headers = depset(cc_headers),
            ),
        ),
    ]

capnp_cc_library = rule(
    implementation = _capnp_cc_library_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".capnp"],
            mandatory = True,
            doc = "Cap'n Proto schema files",
        ),
        "deps": attr.label_list(
            doc = "Dependencies on other Cap'n Proto schemas",
        ),
        "_capnp_compiler": attr.label(
            default = "@capnproto//:capnpc-c++",
            executable = True,
            cfg = "exec",
            doc = "The Cap'n Proto C++ code generator",
        ),
    },
    provides = [CcInfo],
    doc = "Generates C++ code from Cap'n Proto schemas",
)

def _capnp_rust_library_impl(ctx):
    """
    Generate Rust code from Cap'n Proto schemas.
    
    This rule produces:
    - Rust module files (.rs) with type definitions
    - Builder and reader implementations
    - Zero-copy deserialization support
    
    Args:
        ctx: The rule context from Bazel
        
    Returns:
        DefaultInfo provider with generated Rust sources
    """
    # Get the Cap'n Proto Rust code generator (capnpc-rust)
    capnp_compiler = ctx.executable._capnp_compiler
    capnpc_rust = ctx.executable._capnpc_rust
    
    # Prepare schema files
    srcs = ctx.files.srcs
    
    # Collect all generated Rust files
    rust_sources = []
    
    # Process each schema file
    for src in srcs:
        # Create output file
        base_name = src.basename.replace(".capnp", "")
        rust_file = ctx.actions.declare_file(base_name + "_capnp.rs")
        rust_sources.append(rust_file)
        
        # Build command arguments for capnp
        args = ctx.actions.args()
        args.add("compile")
        args.add("-o", capnpc_rust.path + ":" + rust_file.dirname)
        
        # Add import paths
        for dep in ctx.attr.deps:
            if hasattr(dep, "capnp_import_path"):
                args.add("-I", dep.capnp_import_path)
        
        # Add the schema file
        args.add(src.path)
        
        # Collect input files
        inputs = [src, capnpc_rust]
        for dep in ctx.attr.deps:
            inputs.extend(dep.files.to_list())
        
        # Execute capnp compile for Rust
        ctx.actions.run(
            outputs = [rust_file],
            inputs = inputs,
            executable = capnp_compiler,
            arguments = [args],
            mnemonic = "CapnpRustCompile",
            progress_message = "Generating Rust from Cap'n Proto schema %s" % src.basename,
        )
    
    return [DefaultInfo(files = depset(rust_sources))]

capnp_rust_library = rule(
    implementation = _capnp_rust_library_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".capnp"],
            mandatory = True,
            doc = "Cap'n Proto schema files",
        ),
        "deps": attr.label_list(
            doc = "Dependencies on other Cap'n Proto schemas",
        ),
        "_capnp_compiler": attr.label(
            default = "@capnproto//:capnp",
            executable = True,
            cfg = "exec",
            doc = "The Cap'n Proto compiler",
        ),
        "_capnpc_rust": attr.label(
            default = "@capnproto//:capnpc-rust",
            executable = True,
            cfg = "exec",
            doc = "The Cap'n Proto Rust code generator",
        ),
    },
    doc = "Generates Rust code from Cap'n Proto schemas",
)

def _capnp_python_library_impl(ctx):
    """
    Generate Python code from Cap'n Proto schemas.
    
    This rule produces:
    - Python module files (.py) with class definitions
    - Serialization and deserialization support
    - Type hints for better IDE integration
    
    Args:
        ctx: The rule context from Bazel
        
    Returns:
        PyInfo provider with generated Python sources
    """
    # Get the Cap'n Proto Python code generator (capnpc-python)
    capnp_compiler = ctx.executable._capnp_compiler
    
    # Prepare schema files
    srcs = ctx.files.srcs
    
    # Collect all generated Python files
    python_sources = []
    
    # Process each schema file
    for src in srcs:
        # Create output file
        base_name = src.basename.replace(".capnp", "")
        python_file = ctx.actions.declare_file(base_name + "_capnp.py")
        python_sources.append(python_file)
        
        # Build command arguments
        args = ctx.actions.args()
        args.add("compile")
        args.add("-o", "python:" + python_file.dirname)
        
        # Add import paths
        for dep in ctx.attr.deps:
            if hasattr(dep, "capnp_import_path"):
                args.add("-I", dep.capnp_import_path)
        
        # Add the schema file
        args.add(src.path)
        
        # Collect input files
        inputs = [src]
        for dep in ctx.attr.deps:
            inputs.extend(dep.files.to_list())
        
        # Execute capnp compile for Python
        ctx.actions.run(
            outputs = [python_file],
            inputs = inputs,
            executable = capnp_compiler,
            arguments = [args],
            mnemonic = "CapnpPythonCompile",
            progress_message = "Generating Python from Cap'n Proto schema %s" % src.basename,
        )
    
    return [DefaultInfo(files = depset(python_sources))]

capnp_python_library = rule(
    implementation = _capnp_python_library_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".capnp"],
            mandatory = True,
            doc = "Cap'n Proto schema files",
        ),
        "deps": attr.label_list(
            doc = "Dependencies on other Cap'n Proto schemas",
        ),
        "_capnp_compiler": attr.label(
            default = "@capnproto//:capnpc-python",
            executable = True,
            cfg = "exec",
            doc = "The Cap'n Proto Python code generator",
        ),
    },
    doc = "Generates Python code from Cap'n Proto schemas",
)
