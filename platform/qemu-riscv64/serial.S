.text
.globl axiom_serial_put
axiom_serial_put:
    li t0, 0x10000000
1:  lbu t1, 5(t0)
    andi t1, t1, 0x20
    beqz t1, 1b
    sb a0, 0(t0)
    ret
.section .note.GNU-stack,"",@progbits
