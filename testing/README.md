# Neuro-OS Testing Framework

Comprehensive testing infrastructure for Neuro-OS including property-based testing, fuzzing, and integration tests.

## Overview

This directory contains:

- **Property-Based Tests**: QuickCheck-style tests that verify invariants
- **Fuzzing**: Coverage-guided fuzzing with libFuzzer
- **Integration Tests**: End-to-end system tests

## Components

### Property-Based Testing (`property_tests.rs`)

Tests system invariants with randomly generated inputs:

```rust
#[quickcheck]
fn prop_address_translation_reversible(vaddr: VirtualAddress) -> bool {
    // Test that virtual-to-physical-to-virtual translation is reversible
    translate_back(translate_forward(vaddr)) == vaddr
}
```

**Features:**
- Custom generators for kernel data types (addresses, memory regions, tasks)
- Automatic test case shrinking to find minimal failing cases
- Integration with standard Rust test harness

### Fuzzing (`fuzzing/`)

Coverage-guided fuzzing to find edge cases and security issues:

```bash
# Install cargo-fuzz
cargo install cargo-fuzz

# Run fuzz targets
cargo fuzz run fuzz_syscall
cargo fuzz run fuzz_allocator
cargo fuzz run fuzz_ipc
cargo fuzz run fuzz_path
```

**Fuzz Targets:**
- `fuzz_syscall`: System call argument parsing
- `fuzz_allocator`: Memory allocator operations
- `fuzz_ipc`: IPC message parsing
- `fuzz_path`: Filesystem path parsing

### Integration Tests (`integration/tests.rs`)

End-to-end tests that verify complete workflows:

- Boot sequence testing
- Multi-process IPC
- Filesystem operations
- Scheduler fairness
- Performance benchmarks

**Running:**
```bash
cargo test --test integration
```

## Running Tests

### All Tests
```bash
cargo test
```

### Unit Tests Only
```bash
cargo test --lib
```

### Property Tests
```bash
cargo test property_tests
```

### Integration Tests
```bash
cargo test --test '*'
```

### Fuzzing (Continuous)
```bash
# Run indefinitely until crash found
cargo fuzz run fuzz_syscall -- -max_total_time=3600
```

## Writing Tests

### Property-Based Tests

1. Define custom `Arbitrary` implementations for domain types
2. Write properties as predicates that should always hold
3. Use `TestResult` for conditional properties

Example:
```rust
use quickcheck::{Arbitrary, TestResult};

#[derive(Clone, Debug)]
pub struct MyType { /* ... */ }

impl Arbitrary for MyType {
    fn arbitrary(g: &mut Gen) -> Self {
        // Generate random instance
    }
    
    fn shrink(&self) -> Box<dyn Iterator<Item = Self>> {
        // Generate smaller instances for shrinking
    }
}

pub fn prop_my_invariant(x: MyType, y: MyType) -> TestResult {
    if !precondition(x, y) {
        return TestResult::discard();
    }
    TestResult::from_bool(my_invariant_holds(x, y))
}
```

### Fuzz Targets

1. Create a new file in `fuzzing/fuzz_targets/`
2. Use `fuzz_target!` macro
3. Parse input data and exercise code

Example:
```rust
#![no_main]
use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &[u8]| {
    if data.len() < 4 {
        return;
    }
    
    let value = u32::from_le_bytes(data[0..4].try_into().unwrap());
    my_function_to_test(value);
});
```

### Integration Tests

1. Create test functions in `integration/tests.rs`
2. Use standard `#[test]` attribute
3. Exercise multiple components together

Example:
```rust
#[test]
fn test_full_workflow() {
    // Setup
    let system = setup_test_system();
    
    // Execute workflow
    system.boot();
    system.run_service("my-service");
    
    // Verify results
    assert!(system.check_status().is_ok());
    
    // Cleanup
    system.shutdown();
}
```

## Test Coverage

Generate coverage reports:

```bash
# Install tarpaulin
cargo install cargo-tarpaulin

# Generate coverage
cargo tarpaulin --out Html --output-dir coverage/

# View report
firefox coverage/index.html
```

## Continuous Integration

Tests are automatically run on:
- Every push to main/develop
- Pull requests
- Nightly builds

See `.github/workflows/` and `.gitlab-ci.yml` for CI configuration.

## Best Practices

1. **Fast unit tests**: Keep unit tests fast (< 1ms each)
2. **Hermetic tests**: No dependency on external state or files
3. **Deterministic**: Tests should always pass or always fail
4. **Descriptive names**: Use clear test function names
5. **Minimal assertions**: One logical assertion per test
6. **Property over examples**: Prefer property tests for algorithms
7. **Fuzz critical paths**: Fuzz all input parsing and boundary code

## Debugging Failed Tests

### Property Test Failures

QuickCheck will show the failing input:
```
thread 'tests::prop_my_test' panicked at 'Test failed: ...
Failing input: MyType { field: 42, ... }
```

Re-run with the specific input to debug:
```rust
#[test]
fn debug_failure() {
    let failing_input = MyType { field: 42 };
    assert!(prop_my_test(failing_input));
}
```

### Fuzz Crashes

Crashes are saved to `fuzz/artifacts/`:
```bash
# Reproduce crash
cargo fuzz run fuzz_syscall fuzz/artifacts/fuzz_syscall/crash-abc123

# Debug with gdb
cargo fuzz run --debug fuzz_syscall fuzz/artifacts/fuzz_syscall/crash-abc123
gdb target/x86_64-unknown-linux-gnu/debug/fuzz_syscall
```

### Integration Test Failures

Check logs and system state:
```bash
# Verbose output
cargo test --test integration -- --nocapture

# Single test
cargo test --test integration test_boot_sequence -- --nocapture
```

## Performance Testing

Benchmarks are in `benches/`:

```bash
# Run benchmarks
cargo bench

# Specific benchmark
cargo bench bench_memory_allocation
```

## Resources

- [QuickCheck Documentation](https://docs.rs/quickcheck/)
- [libFuzzer Documentation](https://llvm.org/docs/LibFuzzer.html)
- [The Rust Performance Book](https://nnethercote.github.io/perf-book/)
