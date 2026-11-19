.text
.globl axiom_serial_put
axiom_serial_put:
    mov x1, #0x9000000
1:  ldr w2, [x1, #0x18]
    tbnz w2, #5, 1b
    str w0, [x1]
    ret
.section .note.GNU-stack,"",@progbits
