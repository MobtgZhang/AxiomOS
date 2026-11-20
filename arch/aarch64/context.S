.text
.global axiom_switch_root
axiom_switch_root:
    dsb sy
    mrs x1, sctlr_el1
    bic x2, x1, #1
    msr sctlr_el1, x2
    isb
    mov x2, #0xff
    msr mair_el1, x2
    mov x2, #0x3510
    movk x2, #0x80, lsl #16
    mrs x3, id_aa64mmfr0_el1
    and x3, x3, #15
    cmp x3, #5
    mov x4, #5
    csel x3, x3, x4, lo
    orr x2, x2, x3, lsl #32
    msr tcr_el1, x2
    msr ttbr0_el1, x0
    tlbi vmalle1
    dsb sy
    isb
    orr x1, x1, #1
    msr sctlr_el1, x1
    isb
    ret
.global axiom_context_setup
axiom_context_setup:
    mrs x1, CurrentEL
    cmp x1, #4
    b.ne 1f
    adrp x1, axiom_exception_vectors
    add x1, x1, :lo12:axiom_exception_vectors
    msr vbar_el1, x1
    adrp x1, axiom_user_kernel_stack
    add x1, x1, :lo12:axiom_user_kernel_stack
    str x0, [x1]
    isb
    mov x0, #1
    ret
1:  mov x0, #0
    ret
.global axiom_enter_user
axiom_enter_user:
    stp x19, x20, [sp, #-96]!
    stp x21, x22, [sp, #16]
    stp x23, x24, [sp, #32]
    stp x25, x26, [sp, #48]
    stp x27, x28, [sp, #64]
    stp x29, x30, [sp, #80]
    adrp x2, axiom_saved_kernel_sp
    add x2, x2, :lo12:axiom_saved_kernel_sp
    mov x3, sp
    str x3, [x2]
    msr elr_el1, x0
    msr sp_el0, x1
    mov x2, #0x3c0
    msr spsr_el1, x2
    adrp x2, axiom_user_kernel_stack
    add x2, x2, :lo12:axiom_user_kernel_stack
    ldr x2, [x2]
    mov sp, x2
    mov x0, xzr
    mov x1, xzr
    mov x2, xzr
    mov x3, xzr
    mov x4, xzr
    mov x5, xzr
    mov x6, xzr
    mov x7, xzr
    mov x8, xzr
    mov x9, xzr
    mov x10, xzr
    mov x11, xzr
    mov x12, xzr
    mov x13, xzr
    mov x14, xzr
    mov x15, xzr
    mov x16, xzr
    mov x17, xzr
    mov x18, xzr
    mov x19, xzr
    mov x20, xzr
    mov x21, xzr
    mov x22, xzr
    mov x23, xzr
    mov x24, xzr
    mov x25, xzr
    mov x26, xzr
    mov x27, xzr
    mov x28, xzr
    mov x29, xzr
    mov x30, xzr
    eret
.global axiom_leave_user
axiom_leave_user:
    adrp x1, axiom_saved_kernel_sp
    add x1, x1, :lo12:axiom_saved_kernel_sp
    ldr x1, [x1]
    mov sp, x1
    ldp x19, x20, [sp]
    ldp x21, x22, [sp, #16]
    ldp x23, x24, [sp, #32]
    ldp x25, x26, [sp, #48]
    ldp x27, x28, [sp, #64]
    ldp x29, x30, [sp, #80]
    add sp, sp, #96
    ret
.balign 2048
axiom_exception_vectors:
.rept 8
    b axiom_kernel_exception
    .balign 128
.endr
    b axiom_user_sync
    .balign 128
.rept 7
    b axiom_kernel_exception
    .balign 128
.endr
axiom_kernel_exception:
    bl axiom_kernel_fault
    b axiom_halt
axiom_user_sync:
    sub sp, sp, #272
    stp x0, x1, [sp]
    stp x2, x3, [sp, #16]
    stp x4, x5, [sp, #32]
    stp x6, x7, [sp, #48]
    stp x8, x9, [sp, #64]
    stp x10, x11, [sp, #80]
    stp x12, x13, [sp, #96]
    stp x14, x15, [sp, #112]
    stp x16, x17, [sp, #128]
    stp x18, x19, [sp, #144]
    stp x20, x21, [sp, #160]
    stp x22, x23, [sp, #176]
    stp x24, x25, [sp, #192]
    stp x26, x27, [sp, #208]
    stp x28, x29, [sp, #224]
    str x30, [sp, #240]
    mrs x4, elr_el1
    mrs x5, spsr_el1
    stp x4, x5, [sp, #248]
    mrs x4, esr_el1
    lsr x5, x4, #26
    cmp x5, #0x15
    b.ne axiom_user_abort
    mov x3, x2
    mov x2, x1
    mov x1, x0
    mov x0, x8
    bl axiom_user_dispatch
    str x0, [sp]
    ldp x4, x5, [sp, #248]
    msr elr_el1, x4
    msr spsr_el1, x5
    ldp x0, x1, [sp]
    ldp x2, x3, [sp, #16]
    ldp x4, x5, [sp, #32]
    ldp x6, x7, [sp, #48]
    ldp x8, x9, [sp, #64]
    ldp x10, x11, [sp, #80]
    ldp x12, x13, [sp, #96]
    ldp x14, x15, [sp, #112]
    ldp x16, x17, [sp, #128]
    ldp x18, x19, [sp, #144]
    ldp x20, x21, [sp, #160]
    ldp x22, x23, [sp, #176]
    ldp x24, x25, [sp, #192]
    ldp x26, x27, [sp, #208]
    ldp x28, x29, [sp, #224]
    ldr x30, [sp, #240]
    add sp, sp, #272
    eret
axiom_user_abort:
    mrs x0, far_el1
    mov x1, x4
    bl axiom_user_fault
    b axiom_halt
.bss
.balign 8
axiom_saved_kernel_sp: .quad 0
axiom_user_kernel_stack: .quad 0
.section .note.GNU-stack,"",@progbits
