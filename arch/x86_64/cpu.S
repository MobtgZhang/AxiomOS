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

