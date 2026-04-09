;===========================================================================
; TASK 1  -  Display original matrix
;   Digits     -> printed in WHITE
;   Non-digits -> printed in RED
;===========================================================================
PROC Task1_DisplayOriginal

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    CALL ClearScreen

    ;-- row 0: date and time --
    MOV  DH, 0
    MOV  DL, 1
    CALL SetCursorPos
    CALL PrintDateTime

    ;-- row 1: title --
    MOV  DH, 1
    MOV  DL, 10
    CALL SetCursorPos
    LEA  SI, [str_header]
    CALL PrintString

    ;-- row 2: subtitle --
    MOV  DH, 2
    MOV  DL, 5
    CALL SetCursorPos
    LEA  SI, [str_t1_sub]
    CALL PrintString

    ;-- rows 4+: matrix body --
    MOV  DH, 4
    LEA  SI, [original_matrix]
    MOV  CX, ROWS

@T1RowLoop:
    PUSH CX
    MOV  DL, 18
    CALL SetCursorPos
    MOV  CX, COLS

@T1ColLoop:
    LODSB                    ; AL = current matrix byte, SI advances

    CMP  AL, '0'
    JB   @T1NotDigit
    CMP  AL, '9'
    JA   @T1NotDigit
    MOV  BL, WHITE_ON_BLACK
    JMP  @T1Print

@T1NotDigit:
    MOV  BL, RED_ON_BLACK

@T1Print:
    CALL DisplayColorChar    ; prints AL with attribute BL, advances cursor
    MOV  AL, ' '
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar    ; space separator between elements

    LOOP @T1ColLoop

    INC  DH                  ; move down one screen row
    POP  CX
    LOOP @T1RowLoop

    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

ENDP Task1_DisplayOriginal
