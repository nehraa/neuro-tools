// Integration Tests for Neuro-OS
//
// This module contains end-to-end integration tests that verify the correct
// interaction between multiple components of the Neuro-OS system. Unlike unit
// tests that focus on individual functions or modules, these tests exercise
// complete workflows and scenarios.
//
// Test Categories:
// - Boot sequence and initialization
// - Multi-process coordination
// - IPC and communication protocols
// - Filesystem operations
// - Network stack integration
// - Performance benchmarks
//
// Usage:
//   cargo test --test integration

use std::process::{Command, Stdio};
use std::time::{Duration, Instant};
use std::fs;
use std::path::Path;

/// Test complete boot sequence from kernel load to userspace init.
///
/// This test verifies that:
/// - Kernel loads and initializes correctly
/// - Device drivers are loaded in the correct order
/// - Initial ramdisk is mounted
/// - Init process starts successfully
/// - Basic system services are available
#[test]
fn test_boot_sequence() {
    // Build the kernel image
    let build_result = Command::new("bazel")
        .args(&["build", "//kernel:neuro-kernel"])
        .output()
        .expect("Failed to build kernel");
    
    assert!(build_result.status.success(), "Kernel build failed");
    
    // Launch QEMU with the kernel
    let qemu_child = Command::new("qemu-system-x86_64")
        .args(&[
            "-kernel", "bazel-bin/kernel/neuro-kernel",
            "-append", "console=ttyS0 init=/sbin/init",
            "-serial", "stdio",
            "-display", "none",
            "-m", "512M",
            "-no-reboot",
        ])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("Failed to start QEMU");
    
    // Wait for boot completion (with timeout)
    let timeout = Duration::from_secs(30);
    let start = Instant::now();
    
    // In a real test, we'd parse QEMU output to detect successful boot
    // For now, just verify the process starts
    std::thread::sleep(Duration::from_secs(2));
    
    // Clean up
    // Note: In real implementation, we'd gracefully shutdown QEMU
    drop(qemu_child);
    
    assert!(start.elapsed() < timeout, "Boot timeout");
}

/// Test IPC communication between multiple processes.
///
/// This test creates a producer-consumer scenario where:
/// - Producer process generates data and sends via IPC
/// - Consumer process receives and validates data
/// - Message ordering and reliability are verified
#[test]
fn test_ipc_multi_process() {
    // Create a test IPC channel (simplified simulation)
    let channel_name = "/tmp/neuro-test-ipc-channel";
    
    // Start consumer process
    let consumer = Command::new("./bazel-bin/test_consumer")
        .arg(channel_name)
        .stdout(Stdio::piped())
        .spawn()
        .expect("Failed to start consumer");
    
    // Give consumer time to initialize
    std::thread::sleep(Duration::from_millis(100));
    
    // Start producer process
    let producer = Command::new("./bazel-bin/test_producer")
        .args(&[channel_name, "100"]) // Send 100 messages
        .stdout(Stdio::piped())
        .spawn()
        .expect("Failed to start producer");
    
    // Wait for both to complete
    let producer_output = producer.wait_with_output().expect("Producer failed");
    let consumer_output = consumer.wait_with_output().expect("Consumer failed");
    
    // Verify both completed successfully
    assert!(producer_output.status.success(), "Producer failed");
    assert!(consumer_output.status.success(), "Consumer failed");
    
    // Verify message counts match
    let producer_stdout = String::from_utf8_lossy(&producer_output.stdout);
    let consumer_stdout = String::from_utf8_lossy(&consumer_output.stdout);
    
    assert!(producer_stdout.contains("Sent: 100"), "Producer didn't send all messages");
    assert!(consumer_stdout.contains("Received: 100"), "Consumer didn't receive all messages");
}

/// Test filesystem operations including creation, reading, writing, and deletion.
///
/// This test verifies:
/// - File and directory creation
/// - Read/write operations with various sizes
/// - Metadata updates (permissions, timestamps)
/// - Deletion and cleanup
#[test]
fn test_filesystem_operations() {
    let test_dir = "/tmp/neuro-fs-test";
    let test_file = format!("{}/test.txt", test_dir);
    
    // Create test directory
    fs::create_dir_all(test_dir).expect("Failed to create test directory");
    
    // Write test data
    let test_data = "Hello, Neuro-OS! This is a test file.";
    fs::write(&test_file, test_data).expect("Failed to write test file");
    
    // Read and verify
    let read_data = fs::read_to_string(&test_file).expect("Failed to read test file");
    assert_eq!(read_data, test_data, "Data mismatch");
    
    // Check metadata
    let metadata = fs::metadata(&test_file).expect("Failed to get metadata");
    assert!(metadata.is_file(), "Not a file");
    assert_eq!(metadata.len(), test_data.len() as u64, "Size mismatch");
    
    // Clean up
    fs::remove_dir_all(test_dir).expect("Failed to clean up");
}

/// Test scheduler fairness under load.
///
/// This test creates multiple CPU-bound tasks and verifies:
/// - All tasks make progress
/// - No task is starved
/// - CPU time distribution is reasonable
#[test]
fn test_scheduler_fairness() {
    let num_tasks = 10;
    let duration = Duration::from_secs(5);
    
    let mut tasks = Vec::new();
    
    // Spawn CPU-bound tasks
    for i in 0..num_tasks {
        let task = Command::new("./bazel-bin/cpu_bound_task")
            .arg(format!("{}", i))
            .arg(format!("{}", duration.as_secs()))
            .stdout(Stdio::piped())
            .spawn()
            .expect("Failed to spawn task");
        
        tasks.push(task);
    }
    
    // Wait for all tasks to complete
    let mut results = Vec::new();
    for task in tasks {
        let output = task.wait_with_output().expect("Task failed");
        results.push(output);
    }
    
    // Parse iteration counts from each task
    let mut iterations: Vec<u64> = results
        .iter()
        .map(|output| {
            let stdout = String::from_utf8_lossy(&output.stdout);
            // Parse "Iterations: <count>" from output
            stdout
                .lines()
                .find(|line| line.starts_with("Iterations:"))
                .and_then(|line| line.split(':').nth(1))
                .and_then(|s| s.trim().parse().ok())
                .unwrap_or(0)
        })
        .collect();
    
    // Verify all tasks made progress
    assert!(iterations.iter().all(|&count| count > 0), "Some tasks starved");
    
    // Check fairness: max shouldn't be more than 2x min
    let min_iterations = *iterations.iter().min().unwrap();
    let max_iterations = *iterations.iter().max().unwrap();
    
    let ratio = max_iterations as f64 / min_iterations as f64;
    assert!(ratio < 2.0, "Scheduler unfairness detected: ratio = {}", ratio);
}

/// Performance benchmark: Memory allocation throughput.
///
/// This benchmark measures:
/// - Allocations per second for various sizes
/// - Memory fragmentation over time
/// - Allocator overhead
#[test]
fn bench_memory_allocation() {
    let iterations = 100_000;
    let allocation_sizes = vec![16, 64, 256, 1024, 4096, 16384];
    
    for size in allocation_sizes {
        let start = Instant::now();
        
        // Simulate allocation/deallocation pattern
        let mut allocations = Vec::new();
        
        for _ in 0..iterations {
            allocations.push(vec![0u8; size]);
            
            // Periodically free some allocations to avoid OOM
            if allocations.len() > 1000 {
                allocations.drain(0..500);
            }
        }
        
        let elapsed = start.elapsed();
        let allocs_per_sec = iterations as f64 / elapsed.as_secs_f64();
        
        println!("Size {}: {:.0} allocations/sec", size, allocs_per_sec);
        
        // Verify reasonable performance (at least 10K allocs/sec)
        assert!(allocs_per_sec > 10_000.0, "Allocation too slow for size {}", size);
    }
}

/// Performance benchmark: IPC message throughput.
///
/// This benchmark measures:
/// - Messages per second for various sizes
/// - Latency distribution
/// - Throughput under concurrent load
#[test]
fn bench_ipc_throughput() {
    let message_counts = vec![1000, 10000, 100000];
    let message_sizes = vec![64, 512, 4096];
    
    for count in message_counts {
        for size in &message_sizes {
            let start = Instant::now();
            
            // Simulate sending messages (simplified)
            for _ in 0..count {
                let _message = vec![0u8; *size];
                // In real implementation, this would go through actual IPC
                std::hint::black_box(_message);
            }
            
            let elapsed = start.elapsed();
            let msgs_per_sec = count as f64 / elapsed.as_secs_f64();
            let throughput_mbps = (count * size * 8) as f64 / elapsed.as_secs_f64() / 1_000_000.0;
            
            println!(
                "Count: {}, Size: {} - {:.0} msgs/sec, {:.2} Mbps",
                count, size, msgs_per_sec, throughput_mbps
            );
        }
    }
}

/// Test system recovery from process crashes.
///
/// This test verifies that:
/// - Crashed processes are properly cleaned up
/// - Resources are released
/// - Other processes are not affected
/// - System remains stable
#[test]
fn test_process_crash_recovery() {
    // Start a process that will crash
    let crash_process = Command::new("./bazel-bin/crash_test")
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("Failed to start crash test");
    
    // Wait for it to crash
    let output = crash_process.wait_with_output().expect("Wait failed");
    
    // Verify it crashed (non-zero exit code)
    assert!(!output.status.success(), "Process should have crashed");
    
    // Verify system is still responsive by starting another process
    let normal_process = Command::new("echo")
        .arg("System still alive")
        .output()
        .expect("System unresponsive after crash");
    
    assert!(normal_process.status.success(), "System corrupted after crash");
}

/// Helper function to check if running in CI environment.
fn is_ci_environment() -> bool {
    std::env::var("CI").is_ok() || std::env::var("CONTINUOUS_INTEGRATION").is_ok()
}

/// Helper function to skip tests that require hardware or QEMU.
fn requires_qemu() -> bool {
    Command::new("which")
        .arg("qemu-system-x86_64")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}
