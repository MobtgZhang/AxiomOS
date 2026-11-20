.text
#ifdef AXIOM_LOADER
.globl efi_entry
efi_entry:
    jmp axiom_efi_main
#endif
.globl axiom_disable_interrupts
axiom_disable_interrupts:
    cli
    ret
.globl axiom_halt
axiom_halt:
    cli
1:  hlt
    jmp 1b
.globl axiom_pause
axiom_pause:
    pause
    ret
.globl axiom_handoff
axiom_handoff:
    mov %rcx, %rax
    mov %rdx, %rcx
    mov %r8, %rsp
    and $-16, %rsp
    sub $32, %rsp
    call *%rax
    jmp axiom_halt
.globl axiom_sync_code
axiom_sync_code:
    mfence
    ret
.globl axiom_exchange
axiom_exchange:
    mov %edx, %eax
    xchg %eax, (%rcx)
    ret
.globl axiom_release
axiom_release:
    movl $0, (%rcx)
    ret
.globl axiom_cas
axiom_cas:
    mov %edx, %eax
    lock cmpxchg %r8d, (%rcx)
    ret
.globl axiom_fetch_add
axiom_fetch_add:
    mov %edx, %eax
    lock xadd %eax, (%rcx)
    ret
.section .note.GNU-stack,"",@progbits
.text
.globl axiom_apic_id
axiom_apic_id:
    push %rbx
    mov $1, %eax
    cpuid
    mov %ebx, %eax
    shr $24, %eax
    pop %rbx
    ret
.globl axiom_read_cr3
axiom_read_cr3:
    mov %cr3, %rax
    ret
.globl axiom_read_cr4
axiom_read_cr4:
    mov %cr4, %rax
    ret
.globl axiom_read_efer
axiom_read_efer:
    mov $0xc0000080, %ecx
    rdmsr
    shl $32, %rdx
    or %rdx, %rax
    ret
.globl axiom_write_cr3
axiom_write_cr3:
    mov %rcx, %cr3
    ret
.globl axiom_ticks
axiom_ticks:
    lfence
    rdtsc
    shl $32, %rdx
    or %rdx, %rax
    ret

.text
.global axiom_fence
axiom_fence:
    mfence
    ret


# Calibrate the invariant TSC with the q35 PIT channel 2 (10 ms).
# Bounded polling; no firmware services or interrupt handlers are required.
.global axiom_counter_frequency
axiom_counter_frequency:
    inb $0x61, %al
    mov %al, %r8b
    and $0xfc, %al
    outb %al, $0x61
    mov $0xb0, %al
    outb %al, $0x43
    mov $0x9c, %al
    outb %al, $0x42
    mov $0x2e, %al
    outb %al, $0x42
    lfence
    rdtsc
    shl $32, %rdx
    or %rdx, %rax
    mov %rax, %r9
    mov %r8b, %al
    and $0xfc, %al
    or $1, %al
    outb %al, $0x61
    mov $10000000, %r10d
1:  inb $0x61, %al
    test $0x20, %al
    jnz 2f
    pause
    dec %r10d
    jnz 1b
    xor %r9d, %r9d
2:  lfence
    rdtsc
    shl $32, %rdx
    or %rdx, %rax
    sub %r9, %rax
    imul $100, %rax, %r11
    mov %r8b, %al
    outb %al, $0x61
    mov %r11, %rax
    test %r9, %r9
    jnz 3f
    xor %eax, %eax
3:  ret
