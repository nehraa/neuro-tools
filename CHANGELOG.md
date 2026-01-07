# Changelog

All notable changes to Neuro-Tools will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Complete build system with Bazel rules for Rust, Zig, and Cap'n Proto
- Comprehensive testing framework including:
  - Property-based testing with QuickCheck
  - Fuzzing with libFuzzer
  - Integration testing infrastructure
- Advanced debugging tools:
  - GDB Python extensions for kernel debugging
  - Performance profiling with perf and flamegraphs
  - eBPF-based system call tracing
- CI/CD configurations for GitHub Actions and GitLab CI
- Essential automation scripts:
  - `clone-all.sh` - Repository cloning utility
  - `build-image.sh` - Bootable ISO creation
  - `test-all.sh` - Comprehensive test runner
  - `deploy-service.sh` - Service deployment
  - `update-system.sh` - System update automation
  - `health-check.sh` - Service health monitoring
  - `cross-repo-test.sh` - Cross-repository testing
  - `neuro-sync` - Dependency synchronization
- Comprehensive documentation:
  - README files for all major components
  - Build system usage guide
  - Testing framework documentation
  - Debugging tools guide
  - Contributing guidelines
  - Code examples and templates

### Changed
- Enhanced MODULE.yaml with complete component and tool specifications
- Improved README with detailed usage examples and setup instructions

### Fixed
- N/A (initial implementation)

## [0.1.0] - 2024-01-07

### Added
- Initial project structure
- Basic directory layout
- Placeholder scripts

---

## Release Guidelines

### Version Numbers

- **0.1.x**: Initial development releases
- **0.x.y**: Beta releases with breaking changes possible
- **1.0.0**: First stable release
- **1.x.y**: Stable releases with backward compatibility

### Release Checklist

Before releasing a new version:

- [ ] Update version in MODULE.yaml
- [ ] Update CHANGELOG.md
- [ ] Run full test suite: `./scripts/test-all.sh`
- [ ] Build all components: `./scripts/cross-repo-test.sh`
- [ ] Update documentation
- [ ] Create git tag: `git tag -a v0.1.0 -m "Release v0.1.0"`
- [ ] Push tag: `git push origin v0.1.0`
- [ ] Create GitHub release with notes

### Deprecation Policy

Features marked for deprecation will:

1. Be documented in CHANGELOG.md
2. Emit warnings for at least one minor version
3. Be removed in the next major version

Example:
```
## [1.2.0] - Deprecation Notice
- DEPRECATED: `old_function()` will be removed in v2.0.0. Use `new_function()` instead.

## [2.0.0] - Breaking Changes
- REMOVED: `old_function()` (deprecated since v1.2.0)
```
