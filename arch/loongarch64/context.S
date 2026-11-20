.text
.global axiom_switch_root
axiom_switch_root:
    csrwr $a0, 0x19
    li.w $t0, (12 | (9<<5) | (21<<10) | (9<<15) | (30<<20) | (9<<25))
    csrwr $t0, 0x1c
    csrwr $zero, 0x1d
    li.w $t0, 12
    csrwr $t0, 0x1e
    li.w $t0, 12
    csrwr $t0, 0x8e
    la.local $t0, axiom_tlb_refill
    csrwr $t0, 0x88
    csrwr $zero, 0x180
    csrwr $zero, 0x181
    csrwr $zero, 0x182
    csrwr $zero, 0x183
    invtlb 0x0, $zero, $zero
    csrrd $t0, 0x0
    li.w $t1, -9
    and $t0, $t0, $t1
    ori $t0, $t0, 16
    csrwr $t0, 0x0
    ibar 0
    jr $ra
.balign 64
axiom_tlb_refill:
    csrwr $t0, 0x8b
    csrrd $t0, 0x1b
    lddir $t0, $t0, 2
    lddir $t0, $t0, 1
    ldpte $t0, 0
    ldpte $t0, 1
    tlbfill
    csrrd $t0, 0x8b
    ertn
.global axiom_context_setup
axiom_context_setup:
    la.local $t0, axiom_exception
    csrwr $t0, 0xc
    csrwr $zero, 0x4
    la.local $t0, axiom_user_kernel_stack
    st.d $a0, $t0, 0
    csrwr $zero, 0x30
    jr $ra
.global axiom_enter_user
axiom_enter_user:
    addi.d $sp, $sp, -96
    st.d $ra, $sp, 0
    st.d $fp, $sp, 8
    st.d $s0, $sp, 16
    st.d $s1, $sp, 24
    st.d $s2, $sp, 32
    st.d $s3, $sp, 40
    st.d $s4, $sp, 48
    st.d $s5, $sp, 56
    st.d $s6, $sp, 64
    st.d $s7, $sp, 72
    st.d $s8, $sp, 80
    la.local $t0, axiom_saved_kernel_sp
    st.d $sp, $t0, 0
    la.local $t0, axiom_user_kernel_stack
    ld.d $t0, $t0, 0
    csrwr $t0, 0x30
    csrwr $a0, 0x6
    li.w $t0, 3
    csrwr $t0, 0x1
    move $sp, $a1
    move $a0, $zero
    move $a1, $zero
    move $ra, $zero
    move $tp, $zero
    move $fp, $zero
    move $r21, $zero
    move $a2, $zero
    move $a3, $zero
    move $a4, $zero
    move $a5, $zero
    move $a6, $zero
    move $a7, $zero
    move $t0, $zero
    move $t1, $zero
    move $t2, $zero
    move $t3, $zero
    move $t4, $zero
    move $t5, $zero
    move $t6, $zero
    move $t7, $zero
    move $t8, $zero
    move $s0, $zero
    move $s1, $zero
    move $s2, $zero
    move $s3, $zero
    move $s4, $zero
    move $s5, $zero
    move $s6, $zero
    move $s7, $zero
    move $s8, $zero
    ertn
.global axiom_leave_user
axiom_leave_user:
    csrwr $zero, 0x30
    la.local $t0, axiom_saved_kernel_sp
    ld.d $sp, $t0, 0
    ld.d $ra, $sp, 0
    ld.d $fp, $sp, 8
    ld.d $s0, $sp, 16
    ld.d $s1, $sp, 24
    ld.d $s2, $sp, 32
    ld.d $s3, $sp, 40
    ld.d $s4, $sp, 48
    ld.d $s5, $sp, 56
    ld.d $s6, $sp, 64
    ld.d $s7, $sp, 72
    ld.d $s8, $sp, 80
    addi.d $sp, $sp, 96
    jr $ra
.balign 64
axiom_exception:
    csrwr $sp, 0x30
    beqz $sp, axiom_kernel_exception
    addi.d $sp, $sp, -272
    st.d $ra, $sp, 0
    st.d $tp, $sp, 8
    st.d $a0, $sp, 16
    st.d $a1, $sp, 24
    st.d $a2, $sp, 32
    st.d $a3, $sp, 40
    st.d $a4, $sp, 48
    st.d $a5, $sp, 56
    st.d $a6, $sp, 64
    st.d $a7, $sp, 72
    st.d $t0, $sp, 80
    st.d $t1, $sp, 88
    st.d $t2, $sp, 96
    st.d $t3, $sp, 104
    st.d $t4, $sp, 112
    st.d $t5, $sp, 120
    st.d $t6, $sp, 128
    st.d $t7, $sp, 136
    st.d $t8, $sp, 144
    st.d $r21, $sp, 152
    st.d $fp, $sp, 160
    st.d $s0, $sp, 168
    st.d $s1, $sp, 176
    st.d $s2, $sp, 184
    st.d $s3, $sp, 192
    st.d $s4, $sp, 200
    st.d $s5, $sp, 208
    st.d $s6, $sp, 216
    st.d $s7, $sp, 224
    st.d $s8, $sp, 232
    csrrd $t0, 0x30
    st.d $t0, $sp, 240
    csrrd $t0, 0x6
    st.d $t0, $sp, 248
    csrwr $zero, 0x30
    csrrd $t0, 0x5
    srli.d $t0, $t0, 16
    andi $t0, $t0, 63
    li.w $t1, 11
    bne $t0, $t1, axiom_user_abort
    move $a3, $a2
    move $a2, $a1
    move $a1, $a0
    move $a0, $a7
    bl axiom_user_dispatch
    st.d $a0, $sp, 16
    ld.d $t0, $sp, 248
    addi.d $t0, $t0, 4
    csrwr $t0, 0x6
    li.w $t0, 3
    csrwr $t0, 0x1
    ld.d $t0, $sp, 240
    csrwr $t0, 0x30
    ld.d $ra, $sp, 0
    ld.d $tp, $sp, 8
    ld.d $a0, $sp, 16
    ld.d $a1, $sp, 24
    ld.d $a2, $sp, 32
    ld.d $a3, $sp, 40
    ld.d $a4, $sp, 48
    ld.d $a5, $sp, 56
    ld.d $a6, $sp, 64
    ld.d $a7, $sp, 72
    ld.d $t0, $sp, 80
    ld.d $t1, $sp, 88
    ld.d $t2, $sp, 96
    ld.d $t3, $sp, 104
    ld.d $t4, $sp, 112
    ld.d $t5, $sp, 120
    ld.d $t6, $sp, 128
    ld.d $t7, $sp, 136
    ld.d $t8, $sp, 144
    ld.d $r21, $sp, 152
    ld.d $fp, $sp, 160
    ld.d $s0, $sp, 168
    ld.d $s1, $sp, 176
    ld.d $s2, $sp, 184
    ld.d $s3, $sp, 192
    ld.d $s4, $sp, 200
    ld.d $s5, $sp, 208
    ld.d $s6, $sp, 216
    ld.d $s7, $sp, 224
    ld.d $s8, $sp, 232
    addi.d $sp, $sp, 272
    csrwr $sp, 0x30
    ertn
axiom_user_abort:
    csrrd $a0, 0x7
    csrrd $a1, 0x5
    bl axiom_user_fault
    b axiom_halt
axiom_kernel_exception:
    csrwr $sp, 0x30
    bl axiom_kernel_fault
    b axiom_halt
.bss
.balign 8
axiom_saved_kernel_sp: .quad 0
axiom_user_kernel_stack: .quad 0
.section .note.GNU-stack,"",@progbits
