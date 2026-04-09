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

    ; copy original , replace non-digits with '0' 
    LEA  SI, [original_matrix]
    LEA  DI, [cleaned_matrix]
    MOV  CX, TOTAL_CELLS

@T2CleanLoop:
    LODSB                    ; load single byte from original matrix , ( AL = DS:SI )
    CMP  AL, '0'
    JB   @T2Replace          ; if al < 0  => not a digit
    CMP  AL, '9'
    JA   @T2Replace          ; if al > 9  => not a digit
        
        ; this section handles digits
    STOSB                    ; store single byte to the cleaned matrix .   
    JMP  @T2Next
        
        ; this label handles non digits (replace characters with '0')
@T2Replace:
    MOV  AL, '0'
    STOSB                    ; not a digit: store '0'

@T2Next:
    LOOP @T2CleanLoop


    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

ENDP Task2_CleanMatrix


  ; display procedure for task 2


PROC DisplayT2Matrix

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
    LEA  SI, [str_2_sub]
    CALL PrintString

    MOV  DH, 4
    LEA  SI, [cleaned_matrix]    
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