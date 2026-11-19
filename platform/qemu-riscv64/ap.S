.option norelax
.text
.global axiom_bootstrap_id
axiom_bootstrap_id:
    mv a0, tp
    ret
.global axiom_ticks
axiom_ticks:
    rdtime a0
    ret
.global axiom_cpu_on
axiom_cpu_on:
    mv a2, a1
    csrr t0, satp
    sd t0, 16(a2)
    la a1, axiom_ap_start
    li a6, 0
    li a7, 0x48534d
    fence rw,rw
    ecall
    ret
axiom_ap_start:
    csrci sstatus, 2
    mv tp, a0
    ld t0, 16(a1)
    csrw satp, t0
    sfence.vma
    fence.i
    ld sp, 0(a1)
    ld a0, 8(a1)
    call axiom_secondary
    tail axiom_halt
.section .note.GNU-stack,"",@progbits
