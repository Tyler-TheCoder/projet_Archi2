; Linas work

DATA SEGMENT
    matrix  DB 28 DUP(?)      ; 7x4 = 28 elements
    colSum  DB 4 DUP(0)       ; result (4 columns)
DATA ENDS
CODE SEGMENT
ASSUME DS:DATA, CS:CODE

START:
    MOV AX, DATA
    MOV DS, AX

    CALL COLUMN_SUM

    ; end program
    MOV AH, 4CH
    INT 21H
COLUMN_SUM PROC
    MOV CX, 4            ; number of columns
    MOV SI, 0            ; column index

COL_LOOP:
    MOV BX, SI           ; start at column index
    MOV DL, 0            ; sum = 0
    MOV DI, 7            ; number of rows

ROW_LOOP:
    ADD DL, matrix[BX]   ; add element
    ADD BX, 4            ; move to next row (same column)
    DEC DI
    JNZ ROW_LOOP

    MOV colSum[SI], DL   ; store result

    INC SI               ; next column
    LOOP COL_LOOP

    RET
COLUMN_SUM ENDP
