.text
#ifdef AXIOM_LOADER
.globl efi_entry
efi_entry:
    b axiom_efi_main
#endif
.globl axiom_disable_interrupts
axiom_disable_interrupts:
    msr daifset, #15
    ret
.globl axiom_halt
axiom_halt:
    msr daifset, #15
1:  wfi
    b 1b
.globl axiom_pause
axiom_pause:
    yield
    ret
.globl axiom_handoff
axiom_handoff:
    mov x3, x0
    mov x0, x1
    mov sp, x2
    blr x3
    b axiom_halt
.globl axiom_sync_code
axiom_sync_code:
    mrs x2, ctr_el0
    ubfx x3, x2, #16, #4
    mov x4, #4
    lsl x3, x4, x3
    add x1, x0, x1
    sub x4, x3, #1
    bic x4, x0, x4
1:  dc cvau, x4
    add x4, x4, x3
    cmp x4, x1
    b.lo 1b
    dsb ish
    and x2, x2, #15
    mov x3, #4
    lsl x3, x3, x2
    sub x4, x3, #1
    bic x4, x0, x4
2:  ic ivau, x4
    add x4, x4, x3
    cmp x4, x1
    b.lo 2b
    dsb ish
    isb
    ret
.globl axiom_exchange
axiom_exchange:
1:  ldaxr w2, [x0]
    stxr w3, w1, [x0]
    cbnz w3, 1b
    mov w0, w2
    ret
.globl axiom_release
axiom_release:
    stlr wzr, [x0]
    ret
.section .note.GNU-stack,"",@progbits

.text
.global axiom_fence
axiom_fence:
    dsb sy
    ret
