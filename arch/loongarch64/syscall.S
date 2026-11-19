.text
.global axiom_syscall
axiom_syscall:
    move $a7, $a0
    move $a0, $a1
    move $a1, $a2
    move $a2, $a3
    syscall 0
    jr $ra
.section .note.GNU-stack,"",@progbits
