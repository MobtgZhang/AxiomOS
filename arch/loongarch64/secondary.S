.text
.global axiom_bootstrap_id
axiom_bootstrap_id:
    csrrd $a0, 0x20
    jr $ra
.global axiom_cpu_on
axiom_cpu_on:
    la.local $t0, axiom_ap_start
    st.d $a1, $t0, 0x100
    dbar 0
    slli.d $a0, $a0, 16
    li.w $t1, 0x80000000
    or $a0, $a0, $t1
    lu32i.d $a0, 0
    bstrpick.d $t1, $t0, 31, 0
    slli.d $t1, $t1, 32
    or $t1, $t1, $a0
    li.w $t2, 0x1048
    iocsrwr.d $t1, $t2
    srli.d $t1, $t0, 32
    slli.d $t1, $t1, 32
    or $t1, $t1, $a0
    ori $t1, $t1, 4
    iocsrwr.d $t1, $t2
    li.w $t2, 0x1040
    iocsrwr.w $a0, $t2
    jr $ra
.balign 4096
axiom_ap_start:
    csrwr $zero, 0x0
    li.w $t0, 8
    csrwr $t0, 0x0
    la.local $t0, axiom_ap_start
    ld.d $t0, $t0, 0x100
    ld.d $sp, $t0, 0
    ld.d $a0, $t0, 8
    li.w $t1, 0x100c
    li.w $t2, -1
    iocsrwr.w $t2, $t1
    bl axiom_secondary
    b axiom_halt
.org axiom_ap_start + 0x100
    .quad 0
.section .note.GNU-stack,"",@progbits
