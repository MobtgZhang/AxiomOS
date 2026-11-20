.option norelax
.text
.global axiom_switch_root
axiom_switch_root:
    srli a0, a0, 12
    li t0, 8
    slli t0, t0, 60
    or a0, a0, t0
    csrw satp, a0
    sfence.vma
    fence.i
    ret
.global axiom_context_setup
axiom_context_setup:
    la t0, axiom_trap
    csrw stvec, t0
    csrw sscratch, zero
    la t0, axiom_user_kernel_stack
    sd a0, 0(t0)
    ret
.global axiom_enter_user
axiom_enter_user:
    addi sp, sp, -112
    sd ra, 0(sp)
    sd s0, 8(sp)
    sd s1, 16(sp)
    sd s2, 24(sp)
    sd s3, 32(sp)
    sd s4, 40(sp)
    sd s5, 48(sp)
    sd s6, 56(sp)
    sd s7, 64(sp)
    sd s8, 72(sp)
    sd s9, 80(sp)
    sd s10, 88(sp)
    sd s11, 96(sp)
    la t0, axiom_saved_kernel_sp
    sd sp, 0(t0)
    la t0, axiom_user_kernel_stack
    ld t0, 0(t0)
    csrw sscratch, t0
    csrw sepc, a0
    li t0, 0xc6122
    csrc sstatus, t0
    mv sp, a1
    li a0, 0
    li a1, 0
    li ra, 0
    li gp, 0
    li tp, 0
    li a2, 0
    li a3, 0
    li a4, 0
    li a5, 0
    li a6, 0
    li a7, 0
    li s0, 0
    li s1, 0
    li s2, 0
    li s3, 0
    li s4, 0
    li s5, 0
    li s6, 0
    li s7, 0
    li s8, 0
    li s9, 0
    li s10, 0
    li s11, 0
    li t0, 0
    li t1, 0
    li t2, 0
    li t3, 0
    li t4, 0
    li t5, 0
    li t6, 0
    sret
.global axiom_leave_user
axiom_leave_user:
    csrw sscratch, zero
    la t0, axiom_saved_kernel_sp
    ld sp, 0(t0)
    ld ra, 0(sp)
    ld s0, 8(sp)
    ld s1, 16(sp)
    ld s2, 24(sp)
    ld s3, 32(sp)
    ld s4, 40(sp)
    ld s5, 48(sp)
    ld s6, 56(sp)
    ld s7, 64(sp)
    ld s8, 72(sp)
    ld s9, 80(sp)
    ld s10, 88(sp)
    ld s11, 96(sp)
    addi sp, sp, 112
    ret
.balign 4
axiom_trap:
    csrrw sp, sscratch, sp
    beqz sp, axiom_kernel_exception
    addi sp, sp, -272
    sd ra, 0(sp)
    sd gp, 8(sp)
    sd tp, 16(sp)
    sd t0, 24(sp)
    sd t1, 32(sp)
    sd t2, 40(sp)
    sd s0, 48(sp)
    sd s1, 56(sp)
    sd a0, 64(sp)
    sd a1, 72(sp)
    sd a2, 80(sp)
    sd a3, 88(sp)
    sd a4, 96(sp)
    sd a5, 104(sp)
    sd a6, 112(sp)
    sd a7, 120(sp)
    sd s2, 128(sp)
    sd s3, 136(sp)
    sd s4, 144(sp)
    sd s5, 152(sp)
    sd s6, 160(sp)
    sd s7, 168(sp)
    sd s8, 176(sp)
    sd s9, 184(sp)
    sd s10, 192(sp)
    sd s11, 200(sp)
    sd t3, 208(sp)
    sd t4, 216(sp)
    sd t5, 224(sp)
    sd t6, 232(sp)
    csrr t0, sepc
    sd t0, 240(sp)
    csrr t0, sscratch
    sd t0, 248(sp)
    csrw sscratch, zero
    csrr t0, scause
    li t1, 8
    bne t0, t1, axiom_user_abort
    mv a3, a2
    mv a2, a1
    mv a1, a0
    mv a0, a7
    call axiom_user_dispatch
    sd a0, 64(sp)
    ld t0, 240(sp)
    addi t0, t0, 4
    csrw sepc, t0
    ld t0, 248(sp)
    csrw sscratch, t0
    li t0, 0x100
    csrc sstatus, t0
    ld ra, 0(sp)
    ld gp, 8(sp)
    ld tp, 16(sp)
    ld t0, 24(sp)
    ld t1, 32(sp)
    ld t2, 40(sp)
    ld s0, 48(sp)
    ld s1, 56(sp)
    ld a0, 64(sp)
    ld a1, 72(sp)
    ld a2, 80(sp)
    ld a3, 88(sp)
    ld a4, 96(sp)
    ld a5, 104(sp)
    ld a6, 112(sp)
    ld a7, 120(sp)
    ld s2, 128(sp)
    ld s3, 136(sp)
    ld s4, 144(sp)
    ld s5, 152(sp)
    ld s6, 160(sp)
    ld s7, 168(sp)
    ld s8, 176(sp)
    ld s9, 184(sp)
    ld s10, 192(sp)
    ld s11, 200(sp)
    ld t3, 208(sp)
    ld t4, 216(sp)
    ld t5, 224(sp)
    ld t6, 232(sp)
    addi sp, sp, 272
    csrrw sp, sscratch, sp
    sret
axiom_user_abort:
    csrr a0, stval
    csrr a1, scause
    call axiom_user_fault
    tail axiom_halt
axiom_kernel_exception:
    csrrw sp, sscratch, sp
    call axiom_kernel_fault
    tail axiom_halt
.bss
.balign 8
axiom_saved_kernel_sp: .quad 0
axiom_user_kernel_stack: .quad 0
.section .note.GNU-stack,"",@progbits
