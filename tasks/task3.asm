; Akrams work


;===========================================================================
; TASK 3  -  Normalize matrix
;   Source: cleaned_matrix   Destination: normalized_matrix
;   digit < 5  -> stored as ASCII '0'
;   digit >= 5 -> stored as ASCII '1'
;===========================================================================
PROC Task3_NormalizeMatrix

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    ;-- Step A: build normalized_matrix from cleaned_matrix --
    LEA  SI, [cleaned_matrix]      ; load effective address
    LEA  DI, [normalized_matrix]
    ; Its primary purpose is to calculate a memory address and store that address in a register
    ; without actually accessing the memory at that location
    MOV  CX, TOTAL_CELLS

@T3NormLoop:
    LODSB                    ; AL = ASCII digit ('0'..'9')
    ; load string byte , It transfers 1 byte of data from memory into the AL register.
    ; it reads from the address pointed by DS:SI registers
    SUB  AL, '0'             ; convert to numeric value 0..9
    CMP  AL, 5              ; compare between AL and 5
    JAE  @T3SetOne          ; AL >= 5 jump to that label
    MOV  AL, '0'            ; if AL < 5 execute this code else
    JMP  @T3Store           ; will be ignored

@T3SetOne:
    MOV  AL, '1'

@T3Store:
    STOSB                    ; store string byte
    ; store the byte content of the AL register into a specific memory location
    ; pointed to by the DS:DI

    LOOP @T3NormLoop

    ;-- display normalized matrix --
    CALL DisplayNormalizedMatrix  ; display the matrix

    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

ENDP Task3_NormalizeMatrix


;===========================================================================
; DisplayNormalizedMatrix
;   Clears the screen, prints the date/time header, the task subtitle,
;   and then dumps normalized_matrix row by row in WHITE_ON_BLACK colour.
;
;   Inputs  : none  (reads normalized_matrix and str_t3_sub from .DATA)
;   Outputs : none
;   Modifies: nothing  (all registers saved / restored)
;
;   To reuse this pattern for another task, copy the proc, rename it
;   (e.g. DisplayCleanedMatrix), and change:
;       - LEA  SI, [normalized_matrix]  ->  LEA  SI, [cleaned_matrix]
;       - LEA  SI, [str_t3_sub]         ->  LEA  SI, [str_t2_sub]
;===========================================================================
PROC DisplayNormalizedMatrix

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
    LEA  SI, [str_t3_sub]
    CALL PrintString

    MOV  DH, 4
    LEA  SI, [normalized_matrix]
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
