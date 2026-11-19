.text
.global axiom_enable_nx
axiom_enable_nx:
    mov $0xc0000080, %ecx
    rdmsr
    or $0x800, %eax
    wrmsr
    mov %cr0, %rax
    or $0x10000, %rax
    mov %rax, %cr0
    ret
.global axiom_load_tables
axiom_load_tables:
    lgdt (%rcx)
    lidt (%rdx)
    pushq $8
    lea 1f(%rip), %rax
    push %rax
    lretq
1:  mov $16, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %ss
    mov $40, %ax
    ltr %ax
    ret
.global axiom_enter_user
axiom_enter_user:
    push %rbx
    push %rbp
    push %rdi
    push %rsi
    push %r12
    push %r13
    push %r14
    push %r15
    lea axiom_saved_kernel_sp(%rip), %rax
    mov %rsp, (%rax)
    mov $27, %ax
    mov %ax, %ds
    mov %ax, %es
    pushq $27
    push %rdx
    pushq $2
    pushq $35
    push %rcx
    xor %eax, %eax
    xor %ecx, %ecx
    xor %edx, %edx
    xor %ebx, %ebx
    xor %ebp, %ebp
    xor %edi, %edi
    xor %esi, %esi
    xor %r8d, %r8d
    xor %r9d, %r9d
    xor %r10d, %r10d
    xor %r11d, %r11d
    xor %r12d, %r12d
    xor %r13d, %r13d
    xor %r14d, %r14d
    xor %r15d, %r15d
    iretq
.global axiom_leave_user
axiom_leave_user:
    lea axiom_saved_kernel_sp(%rip), %rax
    mov (%rax), %rsp
    mov %rcx, %rax
    pop %r15
    pop %r14
    pop %r13
    pop %r12
    pop %rsi
    pop %rdi
    pop %rbp
    pop %rbx
    ret
.global axiom_syscall_stub
axiom_syscall_stub:
    cld
    push %rax
    push %rcx
    push %rdx
    push %rbx
    push %rbp
    push %rsi
    push %rdi
    push %r8
    push %r9
    push %r10
    push %r11
    push %r12
    push %r13
    push %r14
    push %r15
    mov %rdx, %r9
    mov %rsi, %r8
    mov %rdi, %rdx
    mov %rax, %rcx
    sub $32, %rsp
    call axiom_user_dispatch
    mov %rax, 144(%rsp)
    add $32, %rsp
    pop %r15
    pop %r14
    pop %r13
    pop %r12
    pop %r11
    pop %r10
    pop %r9
    pop %r8
    pop %rdi
    pop %rsi
    pop %rbp
    pop %rbx
    pop %rdx
    pop %rcx
    pop %rax
    iretq
.global axiom_page_fault_stub
axiom_page_fault_stub:
    mov %cr2, %rcx
    mov (%rsp), %rdx
    and $-16, %rsp
    sub $32, %rsp
    call axiom_user_fault
    jmp axiom_halt
.global axiom_fault_stub
axiom_fault_stub:
    and $-16, %rsp
    sub $32, %rsp
    call axiom_kernel_fault
    jmp axiom_halt
.bss
.balign 8
axiom_saved_kernel_sp:
    .quad 0
.section .note.GNU-stack,"",@progbits
