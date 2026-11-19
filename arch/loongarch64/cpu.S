.text
#ifdef AXIOM_LOADER
.globl efi_entry
efi_entry:
    b axiom_efi_main
#endif
.globl axiom_disable_interrupts
axiom_disable_interrupts:
    li.w $t0, 4
    csrxchg $zero, $t0, 0
    jr $ra
.globl axiom_halt
axiom_halt:
    li.w $t0, 4
    csrxchg $zero, $t0, 0
1:  idle 0
    b 1b
.globl axiom_pause
axiom_pause:
    nop
    jr $ra
.globl axiom_handoff
axiom_handoff:
    move $t0, $a0
    move $a0, $a1
    move $sp, $a2
    jirl $ra, $t0, 0
    b axiom_halt
.globl axiom_sync_code
axiom_sync_code:
    dbar 0
    ibar 0
    jr $ra
.globl axiom_exchange
axiom_exchange:
    amswap_db.w $t0, $a1, $a0
    move $a0, $t0
    jr $ra
.globl axiom_release
axiom_release:
    dbar 0
    st.w $zero, $a0, 0
    jr $ra
.section .note.GNU-stack,"",@progbits

.text
.global axiom_fence
axiom_fence:
    dbar 0
    jr $ra
