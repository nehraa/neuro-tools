# GDB Python Scripts for Neuro-OS Kernel Debugging
#
# This module provides GDB extensions for debugging the Neuro-OS kernel.
# It includes custom pretty-printers, commands, and utilities for inspecting
# kernel data structures, tasks, and memory.
#
# Usage:
#   1. Load in GDB: source kernel_debug.py
#   2. Use custom commands: neuro-tasks, neuro-memory, neuro-trace
#
# To automatically load, add to ~/.gdbinit:
#   add-auto-load-safe-path /path/to/neuro-tools/debugging/gdb_scripts

import gdb
import struct

class NeuroTasksCommand(gdb.Command):
    """
    Display all tasks/processes in the Neuro-OS kernel.
    
    This command walks the task list and displays information about each task:
    - PID (Process ID)
    - State (Running, Sleeping, Zombie, etc.)
    - Priority
    - CPU affinity
    - Memory usage
    - Name/command
    
    Usage: neuro-tasks [--detailed]
    """
    
    def __init__(self):
        super(NeuroTasksCommand, self).__init__("neuro-tasks", gdb.COMMAND_USER)
    
    def invoke(self, arg, from_tty):
        """Execute the neuro-tasks command."""
        detailed = "--detailed" in arg
        
        try:
            # Get the global task list head
            # In actual Neuro-OS, this would be the real symbol
            task_list_head = gdb.parse_and_eval("task_list_head")
            
            print("PID    STATE       PRIO  CPU  MEM(KB)  COMMAND")
            print("-" * 60)
            
            # Walk the linked list of tasks
            current_task = task_list_head['next']
            task_count = 0
            
            while current_task != task_list_head.address:
                task = current_task.dereference()
                
                # Extract task fields
                pid = int(task['pid'])
                state = self._decode_task_state(int(task['state']))
                priority = int(task['priority'])
                cpu_affinity = int(task['cpu_affinity'])
                memory_kb = int(task['memory_pages']) * 4  # Assuming 4KB pages
                command = task['name'].string()
                
                print(f"{pid:<6} {state:<11} {priority:<5} {cpu_affinity:<4} {memory_kb:<8} {command}")
                
                if detailed:
                    self._print_detailed_task_info(task)
                
                current_task = task['next']
                task_count += 1
                
                # Prevent infinite loops in corrupted lists
                if task_count > 10000:
                    print("Warning: Task list may be corrupted (too many entries)")
                    break
            
            print(f"\nTotal tasks: {task_count}")
            
        except gdb.error as e:
            print(f"Error accessing task list: {e}")
            print("Make sure kernel symbols are loaded and execution is paused")
    
    def _decode_task_state(self, state):
        """Decode numeric task state to human-readable string."""
        states = {
            0: "RUNNING",
            1: "SLEEPING",
            2: "WAITING",
            3: "STOPPED",
            4: "ZOMBIE",
            5: "DEAD",
        }
        return states.get(state, f"UNKNOWN({state})")
    
    def _print_detailed_task_info(self, task):
        """Print detailed information about a task."""
        print(f"    Page table: 0x{int(task['page_table']):016x}")
        print(f"    Stack pointer: 0x{int(task['stack_ptr']):016x}")
        print(f"    Parent PID: {int(task['parent_pid'])}")
        print()

class NeuroMemoryCommand(gdb.Command):
    """
    Display memory statistics and regions.
    
    This command shows:
    - Total physical memory
    - Available memory
    - Memory regions (kernel, user, DMA, etc.)
    - Page allocation statistics
    - Memory fragmentation info
    
    Usage: neuro-memory [--regions]
    """
    
    def __init__(self):
        super(NeuroMemoryCommand, self).__init__("neuro-memory", gdb.COMMAND_USER)
    
    def invoke(self, arg, from_tty):
        """Execute the neuro-memory command."""
        show_regions = "--regions" in arg
        
        try:
            # Get memory statistics from kernel globals
            total_pages = int(gdb.parse_and_eval("total_memory_pages"))
            free_pages = int(gdb.parse_and_eval("free_memory_pages"))
            
            total_mb = (total_pages * 4) // 1024
            free_mb = (free_pages * 4) // 1024
            used_mb = total_mb - free_mb
            
            print("Memory Statistics")
            print("=" * 40)
            print(f"Total:     {total_mb:>8} MB")
            print(f"Used:      {used_mb:>8} MB ({100 * used_mb // total_mb}%)")
            print(f"Free:      {free_mb:>8} MB ({100 * free_mb // total_mb}%)")
            print()
            
            if show_regions:
                self._print_memory_regions()
            
            # Show page allocator stats
            print("Page Allocator Statistics")
            print("=" * 40)
            
            for order in range(11):  # Buddy allocator orders 0-10
                try:
                    free_list = gdb.parse_and_eval(f"free_pages[{order}]")
                    count = int(free_list['count'])
                    size_kb = (2 ** order) * 4
                    
                    if count > 0:
                        print(f"Order {order:2d} ({size_kb:>6} KB): {count:>6} blocks")
                except (gdb.error, ValueError, RuntimeError):
                    # Some kernels may not expose allocator stats for all orders; skip missing/invalid entries
                    pass
            
        except gdb.error as e:
            print(f"Error accessing memory statistics: {e}")
    
    def _print_memory_regions(self):
        """Print memory region information."""
        print("Memory Regions")
        print("=" * 70)
        print("START              END                SIZE       TYPE")
        print("-" * 70)
        
        # Common memory regions (simplified)
        regions = [
            (0x0000000000000000, 0x00007FFFFFFFFFFF, "User Space"),
            (0xFFFF800000000000, 0xFFFF87FFFFFFFFFF, "Direct Mapping"),
            (0xFFFF888000000000, 0xFFFFC7FFFFFFFFFF, "vmalloc/ioremap"),
            (0xFFFFFFFF80000000, 0xFFFFFFFFFFFFFFFF, "Kernel Code/Data"),
        ]
        
        for start, end, region_type in regions:
            size = (end - start + 1) // (1024 * 1024)  # MB
            print(f"0x{start:016x} - 0x{end:016x} {size:>8} MB  {region_type}")
        
        print()

class NeuroBacktraceCommand(gdb.Command):
    """
    Enhanced backtrace with kernel-specific information.
    
    This command provides an improved backtrace that includes:
    - Symbol resolution for kernel functions
    - Source file and line numbers
    - Inlined function information
    - Register state at each frame
    
    Usage: neuro-trace [--registers]
    """
    
    def __init__(self):
        super(NeuroBacktraceCommand, self).__init__("neuro-trace", gdb.COMMAND_USER)
    
    def invoke(self, arg, from_tty):
        """Execute the neuro-trace command."""
        show_registers = "--registers" in arg
        
        try:
            frame = gdb.newest_frame()
            frame_num = 0
            
            print("Call Stack")
            print("=" * 80)
            
            while frame is not None:
                # Get frame information
                pc = frame.pc()
                name = frame.name() or "??"
                sal = frame.find_sal()
                
                # Format output
                print(f"#{frame_num:<3} 0x{pc:016x} in {name}", end="")
                
                if sal.symtab:
                    filename = sal.symtab.filename.split('/')[-1]
                    print(f" at {filename}:{sal.line}", end="")
                
                print()
                
                if show_registers:
                    self._print_frame_registers(frame)
                
                # Move to older frame
                frame = frame.older()
                frame_num += 1
                
                # Limit depth to prevent excessive output
                if frame_num > 50:
                    print("... (truncated, too many frames)")
                    break
            
            print("=" * 80)
            
        except gdb.error as e:
            print(f"Error generating backtrace: {e}")
    
    def _print_frame_registers(self, frame):
        """Print register values for a frame."""
        try:
            # Get common x86-64 registers
            regs = ["rax", "rbx", "rcx", "rdx", "rsi", "rdi", "rbp", "rsp", "rip"]
            
            print("    Registers:", end="")
            for i, reg in enumerate(regs):
                try:
                    val = frame.read_register(reg)
                    if i % 3 == 0:
                        print(f"\n    ", end="")
                    print(f"{reg}=0x{int(val):016x}  ", end="")
                except gdb.error:
                    # Ignore registers that cannot be read in the current frame
                    pass
            print()
        except gdb.error:
            # Best-effort register printing: ignore unexpected failures so backtrace still works
            pass

class NeuroPageTableWalk(gdb.Command):
    """
    Walk the page table hierarchy for a given virtual address.
    
    This command shows the page table translation process:
    - PML4 entry
    - PDPT entry
    - PD entry
    - PT entry
    - Final physical address
    - Page flags (present, writable, user, etc.)
    
    Usage: neuro-pagetable <virtual_address>
    """
    
    def __init__(self):
        super(NeuroPageTableWalk, self).__init__("neuro-pagetable", gdb.COMMAND_USER)
    
    def invoke(self, arg, from_tty):
        """Execute the neuro-pagetable command."""
        if not arg:
            print("Usage: neuro-pagetable <virtual_address>")
            return
        
        try:
            # Parse virtual address
            vaddr = int(arg, 16) if arg.startswith("0x") else int(arg)
            
            print(f"Page Table Walk for Virtual Address: 0x{vaddr:016x}")
            print("=" * 70)
            
            # Get current CR3 (page table base)
            cr3 = int(gdb.parse_and_eval("$cr3"))
            pml4_base = cr3 & ~0xFFF
            
            print(f"CR3 (Page Table Base): 0x{pml4_base:016x}")
            print()
            
            # Extract page table indices
            pml4_idx = (vaddr >> 39) & 0x1FF
            pdpt_idx = (vaddr >> 30) & 0x1FF
            pd_idx = (vaddr >> 21) & 0x1FF
            pt_idx = (vaddr >> 12) & 0x1FF
            offset = vaddr & 0xFFF
            
            # Walk PML4
            pml4_entry = self._read_pte(pml4_base + pml4_idx * 8)
            print(f"PML4[{pml4_idx:3d}] = 0x{pml4_entry:016x} {self._decode_flags(pml4_entry)}")
            
            if not (pml4_entry & 1):
                print("  -> Page not present")
                return
            
            # Walk PDPT
            pdpt_base = pml4_entry & ~0xFFF
            pdpt_entry = self._read_pte(pdpt_base + pdpt_idx * 8)
            print(f"PDPT[{pdpt_idx:3d}] = 0x{pdpt_entry:016x} {self._decode_flags(pdpt_entry)}")
            
            if not (pdpt_entry & 1):
                print("  -> Page not present")
                return
            
            # Walk PD
            pd_base = pdpt_entry & ~0xFFF
            pd_entry = self._read_pte(pd_base + pd_idx * 8)
            print(f"PD[{pd_idx:3d}]   = 0x{pd_entry:016x} {self._decode_flags(pd_entry)}")
            
            if not (pd_entry & 1):
                print("  -> Page not present")
                return
            
            # Check for 2MB page
            if pd_entry & (1 << 7):
                paddr = (pd_entry & ~0x1FFFFF) | (vaddr & 0x1FFFFF)
                print(f"\n  -> 2MB Page")
                print(f"  -> Physical Address: 0x{paddr:016x}")
                return
            
            # Walk PT
            pt_base = pd_entry & ~0xFFF
            pt_entry = self._read_pte(pt_base + pt_idx * 8)
            print(f"PT[{pt_idx:3d}]   = 0x{pt_entry:016x} {self._decode_flags(pt_entry)}")
            
            if not (pt_entry & 1):
                print("  -> Page not present")
                return
            
            # Calculate final physical address
            paddr = (pt_entry & ~0xFFF) | offset
            print(f"\n  -> 4KB Page")
            print(f"  -> Physical Address: 0x{paddr:016x}")
            
        except Exception as e:
            print(f"Error walking page table: {e}")
    
    def _read_pte(self, addr):
        """Read a page table entry from memory."""
        try:
            inferior = gdb.selected_inferior()
            mem = inferior.read_memory(addr, 8)
            return struct.unpack('<Q', mem)[0]
        except (gdb.error, RuntimeError, struct.error):
            # Return 0 if memory cannot be read (e.g., invalid address)
            return 0
    
    def _decode_flags(self, entry):
        """Decode page table entry flags."""
        flags = []
        if entry & (1 << 0):
            flags.append("P")  # Present
        if entry & (1 << 1):
            flags.append("W")  # Writable
        if entry & (1 << 2):
            flags.append("U")  # User
        if entry & (1 << 3):
            flags.append("PWT")  # Write-through
        if entry & (1 << 4):
            flags.append("PCD")  # Cache disabled
        if entry & (1 << 5):
            flags.append("A")  # Accessed
        if entry & (1 << 6):
            flags.append("D")  # Dirty
        if entry & (1 << 7):
            flags.append("PS")  # Page size
        if entry & (1 << 63):
            flags.append("NX")  # No execute
        
        return f"[{' '.join(flags)}]" if flags else "[None]"

# Register all custom commands
NeuroTasksCommand()
NeuroMemoryCommand()
NeuroBacktraceCommand()
NeuroPageTableWalk()

print("Neuro-OS kernel debugging extensions loaded")
print("Available commands:")
print("  neuro-tasks      - Display all tasks/processes")
print("  neuro-memory     - Display memory statistics")
print("  neuro-trace      - Enhanced backtrace")
print("  neuro-pagetable  - Walk page table for an address")
