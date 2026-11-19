.text
.globl axiom_serial_put
axiom_serial_put:
    li.d $t0, 0x1fe001e0
1:  ld.bu $t1, $t0, 5
    andi $t1, $t1, 0x20
    beqz $t1, 1b
    st.b $a0, $t0, 0
    jr $ra
.section .note.GNU-stack,"",@progbits
