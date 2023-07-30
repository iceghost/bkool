main:
    sw $fp, -4($sp)
    addi $fp, $sp, -4
    addi $sp, $sp, -20
    li $t8, 8
    sw $t8, 0($fp)
    li $t8, 2
    sw $t8, 4($fp)
    lw $t8, 0($fp)
    addi $t8, $t8, 1
    sw $t8, 8($fp)
    lw $a0, 8($fp)
    jal io_writeInt
    lw $t9, 4($fp)
    lw $t8, 0($fp)
    add $t8, $t9, $t8
    sw $t8, 12($fp)
    lw $a0, 12($fp)
    jal io_writeInt
    addi $sp, $fp, 4
    lw $fp, -4($sp)
    jal exit
