.text
.globl axiom_serial_put
axiom_serial_put:
    mov %ecx, %r8d
    mov $0x3fd, %dx
1:  inb %dx, %al
    test $0x20, %al
    jz 1b
    mov $0x3f8, %dx
    mov %r8b, %al
    outb %al, %dx
    ret
.section .note.GNU-stack,"",@progbits
