.text
.global axiom_bootstrap_id
axiom_bootstrap_id:
    mrs x0, mpidr_el1
    and x0, x0, #0xffffff
    ret
.global axiom_cpu_on
axiom_cpu_on:
    stp x29, x30, [sp, #-16]!
    mov x2, x1
    mov x1, x0
    mrs x3, ttbr0_el1
    str x3, [x2, #16]
    mrs x3, tcr_el1
    str x3, [x2, #24]
    mrs x3, mair_el1
    str x3, [x2, #32]
    mrs x3, sctlr_el1
    str x3, [x2, #40]
    mov x3, x2
    adrp x2, axiom_ap_start
    add x2, x2, :lo12:axiom_ap_start
    mov x0, #3
    movk x0, #0xc400, lsl #16
    dc cvac, x3
    dsb sy
    hvc #0
    ldp x29, x30, [sp], #16
    ret
axiom_ap_start:
    msr daifset, #15
    ldr x1, [x0, #16]
    msr ttbr0_el1, x1
    ldr x1, [x0, #24]
    msr tcr_el1, x1
    ldr x1, [x0, #32]
    msr mair_el1, x1
    ldr x1, [x0, #40]
    tlbi vmalle1
    dsb sy
    isb
    msr sctlr_el1, x1
    isb
    ldr x1, [x0]
    mov sp, x1
    ldr x0, [x0, #8]
    bl axiom_secondary
    b axiom_halt
.section .note.GNU-stack,"",@progbits
