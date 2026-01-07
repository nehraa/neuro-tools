# Neuro-OS Debugging Tools

Advanced debugging tools for Neuro-OS kernel and system development.

## Overview

This directory contains:

- **GDB Scripts**: Kernel debugging extensions for GDB
- **Profilers**: Performance analysis tools using perf and flamegraphs
- **eBPF Tracing**: Real-time system tracing with minimal overhead

## Components

### GDB Scripts (`gdb_scripts/`)

Python extensions for GDB that provide kernel-aware debugging:

**Loading:**
```bash
# In GDB
source debugging/gdb_scripts/kernel_debug.py

# Or add to ~/.gdbinit
add-auto-load-safe-path /path/to/neuro-tools/debugging/gdb_scripts
```

**Commands:**
- `neuro-tasks` - Display all running tasks/processes
- `neuro-memory` - Show memory statistics and regions
- `neuro-trace` - Enhanced backtrace with register state
- `neuro-pagetable <addr>` - Walk page tables for a virtual address

**Example Session:**
```bash
# Start debugging
gdb neuro-kernel
(gdb) source debugging/gdb_scripts/kernel_debug.py

# Connect to QEMU
(gdb) target remote :1234

# Show all tasks
(gdb) neuro-tasks --detailed

# Walk page table
(gdb) neuro-pagetable 0xffff800000001000

# Memory overview
(gdb) neuro-memory --regions
```

### Profilers (`profilers/`)

Performance profiling with Linux perf tools:

**CPU Profiling:**
```bash
./debugging/profilers/profile.sh cpu ./my_program 999 30
```

**Flamegraph Generation:**
```bash
./debugging/profilers/profile.sh flamegraph ./my_program
```

**Cache Analysis:**
```bash
./debugging/profilers/profile.sh cache ./my_program
```

**Hardware Counters:**
```bash
./debugging/profilers/profile.sh hardware ./my_program
```

**Live Monitoring:**
```bash
./debugging/profilers/profile.sh top
```

**Features:**
- CPU profiling with sampling
- Call graph generation
- Interactive flamegraph visualization
- Cache miss analysis
- Branch prediction analysis
- Memory access profiling

### eBPF Tracing (`ebpf_tracing/`)

Real-time system call tracing using eBPF:

**Requirements:**
```bash
sudo apt-get install bpfcc-tools python3-bpfcc
```

**Usage:**
```bash
# Trace all syscalls
sudo python3 debugging/ebpf_tracing/trace_syscalls.py

# Trace specific process
sudo python3 debugging/ebpf_tracing/trace_syscalls.py --pid 1234

# Trace specific syscall
sudo python3 debugging/ebpf_tracing/trace_syscalls.py --syscall open
```

**Features:**
- Minimal overhead (< 1% CPU)
- Real-time event streaming
- Syscall argument capture
- Per-process filtering
- Aggregate statistics

## Usage Scenarios

### Debugging a Kernel Panic

1. Start QEMU with GDB stub:
```bash
qemu-system-x86_64 -s -S -kernel neuro-kernel
```

2. Connect GDB:
```bash
gdb neuro-kernel
(gdb) source debugging/gdb_scripts/kernel_debug.py
(gdb) target remote :1234
(gdb) continue
```

3. When panic occurs, inspect state:
```bash
(gdb) neuro-trace
(gdb) neuro-memory
(gdb) neuro-tasks
```

### Finding Performance Bottlenecks

1. Profile the application:
```bash
./debugging/profilers/profile.sh cpu ./my_program
```

2. Generate flamegraph:
```bash
./debugging/profilers/profile.sh flamegraph ./my_program
```

3. Analyze hotspots in the SVG

4. Check cache performance:
```bash
./debugging/profilers/profile.sh cache ./my_program
```

### Investigating System Call Patterns

1. Start tracing:
```bash
sudo python3 debugging/ebpf_tracing/trace_syscalls.py --pid $(pgrep my_program)
```

2. Exercise the application

3. Review output for unexpected patterns:
   - Excessive syscalls
   - Syscall failures
   - Argument anomalies

4. Press Ctrl+C to see summary statistics

### Memory Leak Detection

1. Run with valgrind-compatible tools:
```bash
valgrind --leak-check=full --track-origins=yes ./my_program
```

2. Or use eBPF for production systems:
```bash
# Coming soon: memory leak tracer
sudo python3 debugging/ebpf_tracing/trace_memory_leaks.py
```

## Advanced Debugging

### Kernel Core Dumps

Configure kdump for automatic crash dumps:

```bash
# Install kdump
sudo apt-get install kdump-tools

# Configure
sudo vim /etc/default/kdump-tools

# Load crash dump
crash /boot/vmlinux /var/crash/vmcore
```

### Time Travel Debugging

Use rr for deterministic debugging:

```bash
# Record execution
rr record ./my_program

# Replay
rr replay
(gdb) reverse-continue
(gdb) reverse-step
```

### Cross-Architecture Debugging

Debug ARM64 code from x86-64:

```bash
# Start QEMU for ARM64
qemu-system-aarch64 -M virt -cpu cortex-a57 -s -S -kernel neuro-kernel-arm64

# Use ARM GDB
aarch64-linux-gnu-gdb neuro-kernel-arm64
(gdb) target remote :1234
```

## Best Practices

1. **Use Debug Builds**: Include symbols for meaningful backtraces
2. **Enable Sanitizers**: Use AddressSanitizer, UBSan for development
3. **Log Strategically**: Add debug logs but don't spam
4. **Reproduce Locally**: Always reproduce issues before debugging
5. **Bisect Regressions**: Use `git bisect` to find breaking commits
6. **Profile First**: Don't optimize without profiling
7. **Keep Tools Updated**: Update eBPF, perf, GDB regularly

## Troubleshooting

### GDB Can't Find Symbols

```bash
# Check symbol file
file neuro-kernel
# Should show "not stripped"

# If stripped, rebuild with symbols
cargo build --release
# Or
bazel build -c dbg //...
```

### eBPF Program Won't Load

```bash
# Check kernel version (requires 4.4+)
uname -r

# Check BPF is enabled
zcat /proc/config.gz | grep BPF

# Verify BCC installation
python3 -c "import bcc; print(bcc.__version__)"
```

### Perf Events Not Available

```bash
# Enable perf events
sudo sysctl -w kernel.perf_event_paranoid=-1

# Or permanently in /etc/sysctl.conf
echo "kernel.perf_event_paranoid = -1" | sudo tee -a /etc/sysctl.conf
```

## Resources

- [GDB Documentation](https://sourceware.org/gdb/documentation/)
- [Linux Perf Wiki](https://perf.wiki.kernel.org/)
- [eBPF Documentation](https://ebpf.io/)
- [FlameGraph](https://github.com/brendangregg/FlameGraph)
- [BCC Tools](https://github.com/iovisor/bcc)

## Contributing

When adding debugging tools:

1. Document all commands and options
2. Include usage examples
3. Add error handling for edge cases
4. Test on multiple kernel versions
5. Update this README
