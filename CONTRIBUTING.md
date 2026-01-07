# Contributing to Neuro-Tools

Thank you for your interest in contributing to Neuro-Tools! This document provides guidelines and information for contributors.

## Code of Conduct

We are committed to providing a welcoming and inclusive environment. Please:

- Be respectful and professional
- Welcome newcomers and help them get started
- Focus on constructive feedback
- Assume good intentions

## How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in Issues
2. If not, create a new issue with:
   - Clear title and description
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details (OS, versions, etc.)
   - Relevant logs or error messages

### Suggesting Enhancements

1. Check existing issues and discussions
2. Create an issue describing:
   - The problem you're trying to solve
   - Your proposed solution
   - Alternatives you've considered
   - Any potential drawbacks

### Pull Requests

1. **Fork and Clone**
   ```bash
   git clone https://github.com/YOUR-USERNAME/neuro-tools.git
   cd neuro-tools
   git remote add upstream https://github.com/nehraa/neuro-tools.git
   ```

2. **Create a Branch**
   ```bash
   git checkout -b feature/my-feature
   # or
   git checkout -b fix/issue-123
   ```

3. **Make Your Changes**
   - Follow the code style guidelines below
   - Add tests for new functionality
   - Update documentation as needed
   - Keep commits focused and atomic

4. **Test Your Changes**
   ```bash
   # Run all tests
   ./scripts/test-all.sh
   
   # Run specific tests
   cargo test --lib
   
   # Check formatting
   cargo fmt --check
   cargo clippy
   ```

5. **Commit**
   ```bash
   git add .
   git commit -m "feat: add new feature"
   ```
   
   Use conventional commit messages:
   - `feat:` New feature
   - `fix:` Bug fix
   - `docs:` Documentation changes
   - `test:` Test additions/changes
   - `refactor:` Code refactoring
   - `perf:` Performance improvements
   - `chore:` Maintenance tasks

6. **Push and Create PR**
   ```bash
   git push origin feature/my-feature
   ```
   
   Then create a pull request on GitHub with:
   - Clear title and description
   - Reference to related issues
   - Screenshots (if UI changes)
   - Checklist of what you've done

## Code Style

### Rust

- Use `rustfmt` for formatting: `cargo fmt`
- Use `clippy` for linting: `cargo clippy`
- Follow the [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/)
- Add documentation comments for public APIs
- Write unit tests alongside code

```rust
/// Calculate the factorial of a number.
///
/// # Arguments
///
/// * `n` - The number to calculate factorial for
///
/// # Returns
///
/// The factorial of n
///
/// # Examples
///
/// ```
/// assert_eq!(factorial(5), 120);
/// ```
pub fn factorial(n: u64) -> u64 {
    // Implementation
}
```

### Python

- Follow [PEP 8](https://www.python.org/dev/peps/pep-0008/)
- Use `black` for formatting: `black .`
- Use type hints where possible
- Add docstrings for functions and classes

```python
def process_data(input_data: List[str]) -> Dict[str, int]:
    """
    Process input data and return statistics.
    
    Args:
        input_data: List of strings to process
        
    Returns:
        Dictionary mapping items to counts
        
    Example:
        >>> process_data(['a', 'b', 'a'])
        {'a': 2, 'b': 1}
    """
    # Implementation
```

### Shell Scripts

- Use ShellCheck for validation
- Include shebang: `#!/bin/bash`
- Use `set -euo pipefail` for safety
- Add comments for complex logic
- Use functions for reusability

```bash
#!/bin/bash
# Description of script purpose

set -euo pipefail

# Function documentation
process_file() {
    local input_file="$1"
    # Implementation
}
```

### Bazel/Starlark

- Follow [Bazel Style Guide](https://bazel.build/rules/bzl-style)
- Use meaningful target names
- Document attributes and rules
- Keep BUILD files simple

```starlark
"""
Documentation for the rule.
"""

def my_rule(name, srcs, **kwargs):
    """
    Brief description.
    
    Args:
        name: Target name
        srcs: Source files
        **kwargs: Additional arguments
    """
    # Implementation
```

## Documentation

- Update README files when adding features
- Add inline comments for complex logic
- Write clear commit messages
- Update CHANGELOG.md

## Testing

All contributions must include appropriate tests:

### Unit Tests

```rust
#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_functionality() {
        assert_eq!(my_function(5), 10);
    }
}
```

### Integration Tests

```rust
#[test]
fn test_integration() {
    // Setup
    let system = setup_test_system();
    
    // Execute
    let result = system.run_test();
    
    // Verify
    assert!(result.is_ok());
    
    // Cleanup
    teardown_test_system(system);
}
```

### Property-Based Tests

```rust
use quickcheck::quickcheck;

#[quickcheck]
fn prop_reversible(xs: Vec<i32>) -> bool {
    reverse(reverse(xs.clone())) == xs
}
```

## Development Setup

### Prerequisites

```bash
# Ubuntu/Debian
sudo apt-get install build-essential git curl python3

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install development tools
cargo install cargo-watch cargo-edit cargo-audit
```

### Building

```bash
# Clone repository
git clone https://github.com/nehraa/neuro-tools.git
cd neuro-tools

# Build
cargo build

# Run tests
cargo test
```

### Running Locally

```bash
# Run specific tool
cargo run --bin tool-name

# With arguments
cargo run --bin tool-name -- --arg value
```

## Review Process

1. **Automated Checks**: CI runs tests, linting, and security scans
2. **Code Review**: Maintainer reviews code for quality and design
3. **Discussion**: Address any feedback or questions
4. **Approval**: Once approved, PR is merged

## Release Process

Releases follow [Semantic Versioning](https://semver.org/):

- `MAJOR.MINOR.PATCH`
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes

## Getting Help

- **Documentation**: Check README files and docs/
- **Issues**: Search existing issues or create new one
- **Discussions**: Use GitHub Discussions for questions
- **Chat**: Join our development chat (link TBD)

## Recognition

Contributors are recognized in:
- Git commit history
- CHANGELOG.md
- Contributors list (coming soon)

Thank you for contributing to Neuro-Tools!
