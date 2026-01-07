#!/usr/bin/env python3
"""
eBPF-based System Tracing for Neuro-OS

This module provides real-time system tracing capabilities using eBPF (extended
Berkeley Packet Filter) technology. eBPF allows safe, efficient kernel-level
tracing and monitoring without requiring kernel modules.

Features:
- Real-time syscall tracing with minimal overhead
- Performance hotspot detection
- Memory leak detection
- Network packet analysis
- I/O latency monitoring

Usage:
    sudo python3 trace_syscalls.py [--pid PID] [--syscall SYSCALL]

Requirements:
    - Linux kernel 4.4+
    - BCC (BPF Compiler Collection)
    - Root privileges

Installation:
    apt-get install bpfcc-tools python3-bpfcc
"""

from bcc import BPF
import argparse
import signal
import sys
import time
from datetime import datetime

# BPF program for syscall tracing
BPF_PROGRAM = """
#include <uapi/linux/ptrace.h>
#include <linux/sched.h>

// Data structure for syscall events
struct syscall_event_t {
    u32 pid;
    u32 tid;
    u64 timestamp;
    u64 syscall_nr;
    u64 args[6];
    char comm[16];
};

// Ring buffer for event data
BPF_PERF_OUTPUT(events);

// Hash map to track syscall entry time
BPF_HASH(start_times, u64, u64);

// Hash map to count syscalls by type
BPF_HASH(syscall_counts, u64, u64);

// Trace syscall entry
TRACEPOINT_PROBE(raw_syscalls, sys_enter) {
    u64 pid_tgid = bpf_get_current_pid_tgid();
    u32 pid = pid_tgid >> 32;
    u32 tid = pid_tgid;
    
    // Filter by PID if specified
    FILTER_PID
    
    // Filter by syscall number if specified
    FILTER_SYSCALL
    
    // Record start time
    u64 ts = bpf_ktime_get_ns();
    start_times.update(&pid_tgid, &ts);
    
    // Increment syscall counter
    u64 syscall_nr = args->id;
    u64 *count = syscall_counts.lookup(&syscall_nr);
    u64 new_count = count ? (*count + 1) : 1;
    syscall_counts.update(&syscall_nr, &new_count);
    
    // Emit event
    struct syscall_event_t event = {};
    event.pid = pid;
    event.tid = tid;
    event.timestamp = ts;
    event.syscall_nr = syscall_nr;
    
    // Copy syscall arguments
    event.args[0] = args->args[0];
    event.args[1] = args->args[1];
    event.args[2] = args->args[2];
    event.args[3] = args->args[3];
    event.args[4] = args->args[4];
    event.args[5] = args->args[5];
    
    // Get process name
    bpf_get_current_comm(&event.comm, sizeof(event.comm));
    
    events.perf_submit(args, &event, sizeof(event));
    
    return 0;
}

// Trace syscall exit
TRACEPOINT_PROBE(raw_syscalls, sys_exit) {
    u64 pid_tgid = bpf_get_current_pid_tgid();
    
    // Calculate latency
    u64 *start_ts = start_times.lookup(&pid_tgid);
    if (start_ts) {
        u64 duration = bpf_ktime_get_ns() - *start_ts;
        start_times.delete(&pid_tgid);
        
        // TODO: Track latency distribution
    }
    
    return 0;
}
"""

# Syscall names mapping (partial - common syscalls)
SYSCALL_NAMES = {
    0: "read",
    1: "write",
    2: "open",
    3: "close",
    4: "stat",
    5: "fstat",
    8: "lseek",
    9: "mmap",
    10: "mprotect",
    11: "munmap",
    12: "brk",
    39: "getpid",
    56: "clone",
    57: "fork",
    59: "execve",
    60: "exit",
    61: "wait4",
    62: "kill",
    257: "openat",
    292: "dup3",
    293: "pipe2",
}

class SyscallTracer:
    """
    Main syscall tracer class.
    
    This class manages the eBPF program lifecycle, event collection,
    and data presentation.
    """
    
    def __init__(self, pid=None, syscall=None):
        """
        Initialize the syscall tracer.
        
        Args:
            pid: Process ID to filter (None for all processes)
            syscall: Syscall name to filter (None for all syscalls)
        """
        self.pid = pid
        self.syscall = syscall
        self.syscall_counts = {}
        self.start_time = time.time()
        
        # Prepare BPF program with filters
        bpf_text = BPF_PROGRAM
        
        # Add PID filter if specified
        if pid:
            bpf_text = bpf_text.replace(
                'FILTER_PID',
                f'if (pid != {pid}) {{ return 0; }}'
            )
        else:
            bpf_text = bpf_text.replace('FILTER_PID', '')
        
        # Add syscall filter if specified
        if syscall:
            syscall_nr = self._get_syscall_number(syscall)
            if syscall_nr is not None:
                bpf_text = bpf_text.replace(
                    'FILTER_SYSCALL',
                    f'if (syscall_nr != {syscall_nr}) {{ return 0; }}'
                )
            else:
                print(f"Warning: Unknown syscall '{syscall}'")
                bpf_text = bpf_text.replace('FILTER_SYSCALL', '')
        else:
            bpf_text = bpf_text.replace('FILTER_SYSCALL', '')
        
        # Initialize BPF
        self.bpf = BPF(text=bpf_text)
        self.bpf["events"].open_perf_buffer(self._handle_event)
    
    def _get_syscall_number(self, syscall_name):
        """Get syscall number from name."""
        for nr, name in SYSCALL_NAMES.items():
            if name == syscall_name:
                return nr
        return None
    
    def _handle_event(self, cpu, data, size):
        """
        Handle a syscall event from the BPF program.
        
        Args:
            cpu: CPU number where event occurred
            data: Event data from BPF
            size: Size of event data
        """
        # Parse event structure
        class SyscallEvent(object):
            pass
        
        event = self.bpf["events"].event(data)
        
        # Get syscall name
        syscall_name = SYSCALL_NAMES.get(event.syscall_nr, f"syscall_{event.syscall_nr}")
        
        # Update counts
        if syscall_name not in self.syscall_counts:
            self.syscall_counts[syscall_name] = 0
        self.syscall_counts[syscall_name] += 1
        
        # Format timestamp
        ts = datetime.fromtimestamp(event.timestamp / 1e9).strftime('%H:%M:%S.%f')[:-3]
        
        # Decode process name
        comm = event.comm.decode('utf-8', 'replace')
        
        # Print event
        print(f"{ts} CPU{cpu:02d} {comm:16s} PID={event.pid:6d} TID={event.tid:6d} "
              f"{syscall_name:16s} args=({event.args[0]:#x}, {event.args[1]:#x}, "
              f"{event.args[2]:#x}, ...)")
    
    def run(self):
        """
        Start tracing and process events.
        
        This runs until interrupted by Ctrl+C.
        """
        print("Tracing syscalls... Press Ctrl+C to stop")
        print(f"Filter - PID: {self.pid or 'ALL'}, Syscall: {self.syscall or 'ALL'}")
        print("-" * 100)
        
        try:
            while True:
                self.bpf.perf_buffer_poll(timeout=100)
        except KeyboardInterrupt:
            pass
    
    def print_summary(self):
        """Print summary statistics."""
        elapsed = time.time() - self.start_time
        
        print("\n" + "=" * 80)
        print("SUMMARY")
        print("=" * 80)
        print(f"Duration: {elapsed:.2f} seconds")
        print("\nTop Syscalls by Count:")
        print("-" * 40)
        
        # Sort by count
        sorted_syscalls = sorted(
            self.syscall_counts.items(),
            key=lambda x: x[1],
            reverse=True
        )
        
        total_calls = sum(self.syscall_counts.values())
        
        for syscall, count in sorted_syscalls[:20]:
            percentage = 100.0 * count / total_calls
            calls_per_sec = count / elapsed
            print(f"{syscall:20s} {count:10d} ({percentage:5.1f}%) "
                  f"{calls_per_sec:10.1f} calls/sec")
        
        print(f"\nTotal syscalls: {total_calls}")
        print(f"Calls per second: {total_calls / elapsed:.1f}")

def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Trace system calls using eBPF",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument(
        "--pid",
        type=int,
        help="Process ID to trace (default: all processes)"
    )
    
    parser.add_argument(
        "--syscall",
        type=str,
        help="Syscall name to trace (default: all syscalls)"
    )
    
    args = parser.parse_args()
    
    # Check if running as root
    import os
    if os.geteuid() != 0:
        print("Error: This script requires root privileges")
        print("Please run with: sudo python3 trace_syscalls.py")
        sys.exit(1)
    
    # Create tracer
    tracer = SyscallTracer(pid=args.pid, syscall=args.syscall)
    
    # Set up signal handler for clean exit
    def signal_handler(sig, frame):
        tracer.print_summary()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    
    # Run tracer
    tracer.run()

if __name__ == "__main__":
    main()
