.section .rodata.ap_trampoline,"a",@progbits
.balign 16
.global axiom_ap_trampoline
axiom_ap_trampoline:
.code16
    cli
    cld
    mov %cs, %ax
    mov %ax, %ds
    mov %ax, %ss
    movzwl %ax, %ebx
    shl $4, %ebx
    lgdt 0x1e0
    mov %cr0, %eax
    or $1, %eax
    mov %eax, %cr0
    ljmpl *0x1e8
.code32
.Lprotected:
    mov $0x10, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %ss
    mov 0x208(%ebx), %eax
    mov %eax, %cr4
    mov 0x200(%ebx), %eax
    mov %eax, %cr3
    mov $0xc0000080, %ecx
    mov 0x210(%ebx), %eax
    xor %edx, %edx
    wrmsr
    mov %cr0, %eax
    or $0x80010001, %eax
    mov %eax, %cr0
    ljmp *0x1f0(%ebx)
.code64
.Llong:
    mov 0x218(%rbx), %rsp
    and $-16, %rsp
    sub $32, %rsp
    mov 0x228(%rbx), %rcx
    mov 0x220(%rbx), %rax
    call *%rax
1:  cli
    hlt
    jmp 1b
.org 0x1c0
    .quad 0
    .quad 0x00cf9a000000ffff
    .quad 0x00cf92000000ffff
    .quad 0x00af9a000000ffff
.org 0x1e0
    .word 31
    .long 0
.org 0x1e8
    .long .Lprotected - axiom_ap_trampoline
    .word 8
.org 0x1f0
    .long .Llong - axiom_ap_trampoline
    .word 24
.org 0x200
    .space 0x30
.section .note.GNU-stack,"",@progbits
