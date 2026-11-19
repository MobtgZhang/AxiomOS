.option norelax
.text
#ifdef AXIOM_LOADER
.globl efi_entry
efi_entry:
    tail axiom_efi_main
#endif
.globl axiom_disable_interrupts
axiom_disable_interrupts:
    csrci sstatus, 2
    ret
.globl axiom_halt
axiom_halt:
    csrci sstatus, 2
1:  wfi
    j 1b
.globl axiom_pause
axiom_pause:
    nop
    ret
.globl axiom_handoff
axiom_handoff:
    mv t0, a0
    mv a0, a1
    mv sp, a2
    jalr t0
    tail axiom_halt
.globl axiom_sync_code
axiom_sync_code:
    fence rw,rw
    fence.i
    ret
.globl axiom_exchange
axiom_exchange:
    amoswap.w.aq a0, a1, (a0)
    ret
.globl axiom_release
axiom_release:
    fence rw,w
    sw zero, (a0)
    ret
.section .note.GNU-stack,"",@progbits

.text
.global axiom_fence
axiom_fence:
    fence rw,rw
    ret
