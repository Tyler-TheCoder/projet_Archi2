.stack 100h
.data
ROWS EQU 4
COLS EQU 7

MATRIX DB 1,2,3,4,5,6,7,
       DB 0,0,1,2,3,4,5,
       DB   6,7,8,9,1,2,3,
       DB   4,5,6,7,8,9,0

.code


; TACHE 6: REFLECTION

REFLECT_MATRIX PROC

    mov bx, 0              ; i = 0
    mov cx, ROWS/2         ;number of substitutions = 2

outer_loop:
    push cx

    ; SI = i * COLS
    mov ax, bx
    mov dl, COLS
    mul dl
    mov si, ax

    ; DI = (ROWS-1-i)*COLS
    mov ax, ROWS
    dec ax
    sub ax, bx
    mov dl, COLS
    mul dl
    mov di, ax

    mov cx, COLS           ; number of elements in line :7   
    
 ;swap one element for another between the two lines
swap_loop:
    mov al, MATRIX[si]
    mov ah, MATRIX[di]

    mov MATRIX[si], ah
    mov MATRIX[di], al

    inc si
    inc di

    loop swap_loop

    inc bx                 ; move to the next line
     
    pop cx
    loop outer_loop

    ret
REFLECT_MATRIX ENDP
    

;===========================================================================
; DisplayYourMatrix
;   Clears the screen, prints the date/time header, the task subtitle,
;   and then dumps Your_matrix row by row in WHITE_ON_BLACK colour.
;
;   To reuse this pattern for another task, copy the proc, rename it
;   (e.g. DisplayYourMatrix), and change:
;       - LEA  SI, [normalized_matrix]  ->  LEA  SI, [your_matrix]
;       - LEA  SI, [str_t3_sub]         ->  LEA  SI, [str_yourTask_sub]
;===========================================================================
PROC DisplayYourMatrix

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    CALL ClearScreen

    MOV  DH, 0
    MOV  DL, 1
    CALL SetCursorPos
    CALL PrintDateTime

    MOV  DH, 1
    MOV  DL, 10
    CALL SetCursorPos
    LEA  SI, [str_header]
    CALL PrintString

    MOV  DH, 2
    MOV  DL, 5
    CALL SetCursorPos
    LEA  SI, [str_yourTask_sub]      ; set your task header here
    CALL PrintString

    MOV  DH, 4
    LEA  SI, [your_matrix]           ; set your matrix here
    MOV  CX, ROWS

@DNMRowLoop:
    PUSH CX
    MOV  DL, 18
    CALL SetCursorPos
    MOV  CX, COLS

@DNMColLoop:
    LODSB
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar
    MOV  AL, ' '
    CALL DisplayColorChar

    LOOP @DNMColLoop

    INC  DH
    POP  CX
    LOOP @DNMRowLoop

    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

ENDP DisplayNormalizedMatrix