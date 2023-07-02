        .globl io_writeInt
        .globl exit
        .text
io_writeInt:
        li $v0, 1
        syscall
        jr $ra

exit:
        li $v0, 10
        syscall
