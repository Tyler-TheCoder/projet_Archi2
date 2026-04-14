;===========================================================================
; Task 7  -  Vertical reflection of the matrix
;
; Takes normalized_matrix and mirrors each row left-to-right independently.
; This means element[col] swaps with element[COLS-1-col] for each row.
;
; For 7 columns per row we do 3 swaps per row (middle element stays put):
;   col 0 <-> col 6
;   col 1 <-> col 5
;   col 2 <-> col 4
;   col 3      (untouched, it is the middle)
;
; The result goes into vert_reflected_matrix.
; normalized_matrix is never modified.
;
; Data to add in .DATA:
;   vert_reflected_matrix  DB 28 DUP(0)
;   str_t7_sub             DB '_______Vertical Reflexion of the Matrix______',0
;
; str_process is already declared for Task 6, reuse it here.
;===========================================================================

;---------------------------------------------------------------------------
; Task7_VertReflect  -  entry point called from MAIN
;---------------------------------------------------------------------------
Task7_VertReflect PROC

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    ; --- Step 1: copy normalized_matrix into vert_reflected_matrix ---
    LEA  SI, normalized_matrix
    LEA  DI, vert_reflected_matrix
    MOV  CX, TOTAL_CELLS

T7CopyLoop:
    LODSB
    STOSB
    LOOP T7CopyLoop

    ; --- Step 2: reverse each row in-place inside vert_reflected_matrix ---
    ; For each row:
    ;   SI = pointer to first element of the row  (left side)
    ;   DI = pointer to last element of the row   (right side)
    ;   Swap COLS/2 = 3 pairs, then advance both pointers to the next row.
    ;
    ; We use BX as a base that tracks the start of the current row.

    LEA  BX, vert_reflected_matrix   ; BX = start of current row
    MOV  DH, ROWS                    ; DH = rows remaining

T7RowLoop:
    MOV  SI, BX                      ; SI -> left end of this row
    MOV  DI, BX
    ADD  DI, COLS - 1                ; DI -> right end of this row

    MOV  CX, COLS / 2                ; number of swaps per row = 3

T7SwapLoop:
    MOV  AL, [SI]    ; AL = left element
    MOV  AH, [DI]    ; AH = right element
    MOV  [SI], AH    ; put right value on the left
    MOV  [DI], AL    ; put left value on the right
    INC  SI          ; move left pointer inward
    DEC  DI          ; move right pointer inward
    LOOP T7SwapLoop  ; repeat for all 3 pairs

    ADD  BX, COLS    ; advance BX to the start of the next row
    DEC  DH
    JNZ  T7RowLoop

    ; --- Step 3: display the result ---
    CALL DisplayVertReflected

    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

Task7_VertReflect ENDP

;---------------------------------------------------------------------------
; DisplayVertReflected
;   Clears screen, prints header, then displays vert_reflected_matrix
;   row by row in WHITE. Same structure as all other display procs.
;---------------------------------------------------------------------------
DisplayVertReflected PROC

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
    LEA  SI, str_process          ; "MATRIX PROCESSING" (reused from Task 6)
    CALL PrintString

    MOV  DH, 2
    MOV  DL, 5
    CALL SetCursorPos
    LEA  SI, str_t7_sub
    CALL PrintString

    MOV  DH, 4
    LEA  SI, vert_reflected_matrix
    MOV  BH, ROWS                 ; BH = row counter (CX needed by inner LOOP)

T7DispRow:
    MOV  DL, 18
    CALL SetCursorPos
    MOV  CX, COLS

T7DispCol:
    LODSB
    PUSH CX
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar
    MOV  AL, ' '
    CALL DisplayColorChar
    POP  CX
    LOOP T7DispCol

    INC  DH
    DEC  BH
    JNZ  T7DispRow

    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

DisplayVertReflected ENDP

;===========================================================================
; Add to .DATA:
;
;   vert_reflected_matrix  DB 28 DUP(0)
;   str_t7_sub             DB '_______Vertical Reflexion of the Matrix______',0
;
; Add to MAIN after Task 6:
;
;   CALL Task7_VertReflect
;   MOV  AH, 00h
;   INT  16h
;===========================================================================
