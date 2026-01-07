// libFuzzer Harness for Neuro-OS Components
//
// This module provides fuzzing infrastructure using libFuzzer for finding
// security vulnerabilities and edge cases through coverage-guided fuzzing.
//
// Fuzzing complements traditional testing by:
// - Generating millions of semi-random inputs automatically
// - Using code coverage feedback to guide input generation
// - Finding edge cases that humans might miss
// - Detecting memory safety issues, crashes, and assertion failures
//
// Usage:
//     Build with: cargo fuzz build fuzz_target_name
//     Run with: cargo fuzz run fuzz_target_name
//
// This file should be placed in fuzz/fuzz_targets/lib.rs

#![no_main]

use libfuzzer_sys::fuzz_target;
use std::hint::black_box;

/// Fuzz target for system call argument parsing.
///
/// System calls are a critical attack surface as they accept untrusted
/// input from user space. This fuzzer tests the robustness of syscall
/// argument parsing and validation.
///
/// Input format: [syscall_number: u64][arg1: u64][arg2: u64]...[arg6: u64]
fuzz_target!(|data: &[u8]| {
    // Ensure we have enough data for at least the syscall number
    if data.len() < 8 {
        return;
    }
    
    // Parse syscall number
    let syscall_num = u64::from_le_bytes(data[0..8].try_into().unwrap());
    
    // Parse up to 6 arguments (standard x86-64 syscall convention)
    let mut args = [0u64; 6];
    let mut offset = 8;
    
    for i in 0..6 {
        if offset + 8 <= data.len() {
            args[i] = u64::from_le_bytes(data[offset..offset + 8].try_into().unwrap());
            offset += 8;
        }
    }
    
    // Fuzz the syscall dispatcher (mock implementation)
    // In real code, this would call into the actual syscall handler
    fuzz_syscall_dispatcher(syscall_num, &args);
});

/// Mock syscall dispatcher for fuzzing.
///
/// This simulates the kernel's syscall dispatch logic without actually
/// executing privileged operations.
fn fuzz_syscall_dispatcher(syscall_num: u64, args: &[u64; 6]) {
    match syscall_num {
        // read(fd, buf, count)
        0 => {
            let fd = args[0] as i32;
            let buf_addr = args[1];
            let count = args[2] as usize;
            
            // Validate file descriptor
            if fd < 0 {
                return;
            }
            
            // Validate buffer address (must be in user space)
            if buf_addr >= 0x0000_8000_0000_0000 {
                return; // Invalid user space address
            }
            
            // Validate count
            if count > 0x7FFFF000 {
                return; // Too large
            }
            
            black_box((fd, buf_addr, count));
        }
        
        // write(fd, buf, count)
        1 => {
            let fd = args[0] as i32;
            let buf_addr = args[1];
            let count = args[2] as usize;
            
            // Similar validation as read
            if fd < 0 || buf_addr >= 0x0000_8000_0000_0000 || count > 0x7FFFF000 {
                return;
            }
            
            black_box((fd, buf_addr, count));
        }
        
        // open(path, flags, mode)
        2 => {
            let path_addr = args[0];
            let flags = args[1] as i32;
            let mode = args[2] as u32;
            
            // Validate path address
            if path_addr == 0 || path_addr >= 0x0000_8000_0000_0000 {
                return;
            }
            
            black_box((path_addr, flags, mode));
        }
        
        // mmap(addr, length, prot, flags, fd, offset)
        9 => {
            let addr = args[0];
            let length = args[1] as usize;
            let prot = args[2] as i32;
            let flags = args[3] as i32;
            let fd = args[4] as i32;
            let offset = args[5] as i64;
            
            // Validate length
            if length == 0 || length > 0x7FFFF000 {
                return;
            }
            
            // Validate address alignment
            if addr != 0 && (addr & 0xFFF) != 0 {
                return;
            }
            
            black_box((addr, length, prot, flags, fd, offset));
        }
        
        // Default: unknown syscall
        _ => {
            black_box(syscall_num);
        }
    }
}

/// Fuzz target for memory allocator.
///
/// Memory allocators are complex and must handle arbitrary allocation
/// patterns without corruption. This fuzzer tests allocation, deallocation,
/// and reallocation operations.
///
/// Input format: [operation: u8][size: u32][align: u32]...
#[export_name = "LLVMFuzzerCustomMutator"]
pub fn fuzz_allocator(data: &[u8]) {
    if data.is_empty() {
        return;
    }
    
    let mut offset = 0;
    let mut allocations: Vec<(*mut u8, usize)> = Vec::new();
    
    while offset < data.len() {
        if offset + 9 > data.len() {
            break;
        }
        
        let operation = data[offset];
        let size = u32::from_le_bytes(data[offset + 1..offset + 5].try_into().unwrap()) as usize;
        let align = u32::from_le_bytes(data[offset + 5..offset + 9].try_into().unwrap()) as usize;
        offset += 9;
        
        match operation % 3 {
            // Allocate
            0 => {
                // Clamp size to reasonable values
                let size = size % 0x100000; // Max 1MB
                if size == 0 {
                    continue;
                }
                
                // Ensure alignment is power of 2
                let align = if align == 0 || !align.is_power_of_two() {
                    8
                } else {
                    align.min(4096)
                };
                
                // Simulate allocation (don't actually allocate in fuzzer)
                let fake_ptr = (size | align) as *mut u8;
                allocations.push((fake_ptr, size));
                black_box((size, align));
            }
            
            // Deallocate
            1 => {
                if !allocations.is_empty() {
                    let idx = (size as usize) % allocations.len();
                    let (ptr, size) = allocations.remove(idx);
                    black_box((ptr, size));
                }
            }
            
            // Reallocate
            2 => {
                if !allocations.is_empty() {
                    let idx = (size as usize) % allocations.len();
                    let (old_ptr, old_size) = allocations[idx];
                    let new_size = (align as usize) % 0x100000;
                    
                    if new_size > 0 {
                        let fake_new_ptr = (new_size | old_size) as *mut u8;
                        allocations[idx] = (fake_new_ptr, new_size);
                        black_box((old_ptr, old_size, new_size));
                    }
                }
            }
            
            _ => unreachable!(),
        }
    }
    
    // Clean up all allocations
    for (ptr, size) in allocations {
        black_box((ptr, size));
    }
}

/// Fuzz target for IPC message parser.
///
/// IPC messages can come from untrusted sources, so the parser must
/// handle malformed input gracefully without crashing or leaking information.
///
/// Input format: [msg_type: u32][payload_len: u32][payload: ...]
#[export_name = "LLVMFuzzerTestOneInput"]
pub fn fuzz_ipc_message(data: &[u8]) {
    if data.len() < 8 {
        return;
    }
    
    // Parse message header
    let msg_type = u32::from_le_bytes(data[0..4].try_into().unwrap());
    let payload_len = u32::from_le_bytes(data[4..8].try_into().unwrap()) as usize;
    
    // Validate payload length
    if payload_len > data.len() - 8 {
        return; // Truncated message
    }
    
    if payload_len > 0x100000 {
        return; // Too large
    }
    
    let payload = &data[8..8 + payload_len];
    
    // Parse message based on type
    match msg_type {
        // Simple notification
        0 => {
            if payload.is_empty() {
                black_box(msg_type);
            }
        }
        
        // Data transfer
        1 => {
            if payload.len() >= 4 {
                let data_id = u32::from_le_bytes(payload[0..4].try_into().unwrap());
                black_box((msg_type, data_id, &payload[4..]));
            }
        }
        
        // RPC call
        2 => {
            if payload.len() >= 8 {
                let method_id = u32::from_le_bytes(payload[0..4].try_into().unwrap());
                let num_args = u32::from_le_bytes(payload[4..8].try_into().unwrap());
                
                // Validate number of arguments
                if num_args > 16 {
                    return;
                }
                
                black_box((msg_type, method_id, num_args));
            }
        }
        
        // Unknown message type - should be handled gracefully
        _ => {
            black_box((msg_type, payload));
        }
    }
}

/// Fuzz target for filesystem path parsing.
///
/// Path parsing is security-critical as it can lead to directory traversal
/// vulnerabilities if not handled correctly.
fn fuzz_path_parser(data: &[u8]) {
    // Try to parse as UTF-8 path
    if let Ok(path_str) = std::str::from_utf8(data) {
        // Check for various path traversal patterns
        let has_dot_dot = path_str.contains("..");
        let has_absolute = path_str.starts_with('/');
        let has_null_byte = path_str.contains('\0');
        
        // Normalize path (simplified version)
        let mut components = Vec::new();
        
        for component in path_str.split('/') {
            match component {
                "" | "." => continue,
                ".." => {
                    components.pop();
                }
                _ => {
                    if !component.contains('\0') {
                        components.push(component);
                    }
                }
            }
        }
        
        black_box((has_dot_dot, has_absolute, has_null_byte, components));
    }
}
