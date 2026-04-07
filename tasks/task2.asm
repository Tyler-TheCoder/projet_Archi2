;===========================================================================
; TASK 2  -  Clean matrix
;   Non-digit characters replaced by ASCII '0'
;   Replaced cells shown in RED, unchanged digits in WHITE
;===========================================================================
PROC Task2_CleanMatrix

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    ;-- Step A: copy original -> cleaned, replacing non-digits with '0' --
    LEA  SI, [original_matrix]
    LEA  DI, [cleaned_matrix]
    MOV  CX, TOTAL_CELLS

@@T2CleanLoop:
    LODSB                    ; AL = original byte
    CMP  AL, '0'
    JB   @@T2Replace
    CMP  AL, '9'
    JA   @@T2Replace
    STOSB                    ; it is a digit: store unchanged
    JMP  @@T2Next

@@T2Replace:
    MOV  AL, '0'
    STOSB                    ; not a digit: store '0'

@@T2Next:
    LOOP @@T2CleanLoop

    ;-- Step B: display cleaned matrix --
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
    LEA  SI, [str_t2_sub]
    CALL PrintString

    ;-- rows 4+: walk original and cleaned in parallel --
    MOV  DH, 4
    LEA  SI, [original_matrix]
    LEA  DI, [cleaned_matrix]
    MOV  CX, ROWS

@@T2RowLoop:
    PUSH CX
    MOV  DL, 18
    CALL SetCursorPos
    MOV  CX, COLS

@@T2ColLoop:
    MOV  BH, [SI]            ; BH = original byte  (save before INC)
    INC  SI
    MOV  AL, [DI]            ; AL = cleaned byte
    INC  DI

    CMP  AL, BH              ; equal -> was a digit -> white
    JE   @@T2WasDigit
    MOV  BL, RED_ON_BLACK    ; not equal -> was replaced -> red
    JMP  @@T2Print

@@T2WasDigit:
    MOV  BL, WHITE_ON_BLACK

@@T2Print:
    CALL DisplayColorChar
    MOV  AL, ' '
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar

    LOOP @@T2ColLoop

    INC  DH
    POP  CX
    LOOP @@T2RowLoop

    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

ENDP Task2_CleanMatrix
