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
.globl axiom_cas
axiom_cas:
1:  ll.w $a3, $a0, 0
    xor $t0, $a3, $a1
    slli.d $t0, $t0, 32
    bnez $t0, 2f
    move $a4, $a2
    sc.w $a4, $a0, 0
    beqz $a4, 1b           # sc.w yields the LLBit: 1 = success, 0 = retry
2:  move $a0, $a3
    jr $ra
.globl axiom_fetch_add
axiom_fetch_add:
1:  ll.w $a2, $a0, 0
    add.w $a3, $a2, $a1
    move $a4, $a3
    sc.w $a4, $a0, 0
    beqz $a4, 1b           # retry only when the conditional store failed
    move $a0, $a2
    jr $ra
.section .note.GNU-stack,"",@progbits

.text
.global axiom_fence
axiom_fence:
    dbar 0
    jr $ra

.text
.global axiom_ticks
axiom_ticks:
    rdtime.d $a0, $zero
    jr $ra

.global axiom_counter_frequency
axiom_counter_frequency:
    li.w $t0, 4
    cpucfg $a0, $t0
    li.w $t0, 5
    cpucfg $t1, $t0
    bstrpick.d $t2, $t1, 15, 0
    srli.d $t1, $t1, 16
    mul.d $a0, $a0, $t2
    beqz $t1, 1f
    div.du $a0, $a0, $t1
    jr $ra
1:  move $a0, $zero
    jr $ra
