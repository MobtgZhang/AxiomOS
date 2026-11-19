.text
.global axiom_syscall
axiom_syscall:
    push %rdi
    push %rsi
    mov %rcx, %rax
    mov %rdx, %rdi
    mov %r8, %rsi
    mov %r9, %rdx
    int $0x80
    pop %rsi
    pop %rdi
    ret
.section .note.GNU-stack,"",@progbits
