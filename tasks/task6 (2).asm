;===========================================================================
; Task 6  -  Horizontal reflection of the matrix
;
; Takes normalized_matrix (produced by Task 3) and flips it upside-down:
;   row 0  <->  row 3
;   row 1  <->  row 2
;
; The result is stored in reflected_matrix so normalized_matrix stays
; untouched (Task 7 will also need the original normalized data).
;
; Display: "MATRIX PROCESSING" header + subtitle, then the reflected
; matrix in WHITE, all cells in white (no colors needed here).
;
; Data to add in .DATA:
;   reflected_matrix  DB 28 DUP(0)
;   str_t6_sub        DB '________Horizontal Reflexion of the Matrix_____',0
;   str_process       DB 'MATRIX PROCESSING',0
;===========================================================================

;---------------------------------------------------------------------------
; Task6_HorizReflect  -  entry point called from MAIN
;---------------------------------------------------------------------------
Task6_HorizReflect PROC

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    ; --- Step 1: copy normalized_matrix into reflected_matrix ---
    ; We work on the copy so the original is never touched.
    LEA  SI, normalized_matrix
    LEA  DI, reflected_matrix
    MOV  CX, TOTAL_CELLS

CopyLoop:
    LODSB        ; AL = byte from normalized_matrix, SI++
    STOSB        ; store AL into reflected_matrix, DI++
    LOOP CopyLoop

    ; --- Step 2: flip reflected_matrix in-place ---
    ; Swap row 0 with row 3, then row 1 with row 2.
    ; For a 4-row matrix that is ROWS/2 = 2 swaps.
    ;
    ; SI points to the top row, DI points to the bottom row.
    ; After each full row swap, SI moves one row down, DI moves one row up.

    LEA  SI, reflected_matrix              ; SI -> start of row 0
    LEA  DI, reflected_matrix + (ROWS-1)*COLS  ; DI -> start of row 3

    MOV  BH, ROWS/2    ; number of row-pair swaps = 2

SwapRowPair:
    MOV  CX, COLS      ; swap 7 bytes between the two rows

SwapOneByte:
    MOV  AL, [SI]      ; AL = byte from top row
    MOV  AH, [DI]      ; AH = byte from bottom row
    MOV  [SI], AH      ; top row gets bottom byte
    MOV  [DI], AL      ; bottom row gets top byte
    INC  SI
    INC  DI
    LOOP SwapOneByte

    ; SI is now at start of next row going down.
    ; DI just passed the row it swapped -- move it back 2 rows to point
    ; to the next inner row going up.
    SUB  DI, COLS*2

    DEC  BH
    JNZ  SwapRowPair

    ; --- Step 3: display the reflected matrix ---
    CALL DisplayReflectedMatrix

    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

Task6_HorizReflect ENDP

;---------------------------------------------------------------------------
; DisplayReflectedMatrix
;   Clears screen, prints header, then dumps reflected_matrix in WHITE.
;   Same structure as the display procs in Tasks 1-3.
;---------------------------------------------------------------------------
DisplayReflectedMatrix PROC

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

    ; Note: Task 6 uses "MATRIX PROCESSING" not "MATRIX PREPROCESSING"
    MOV  DH, 1
    MOV  DL, 10
    CALL SetCursorPos
    LEA  SI, str_process
    CALL PrintString

    MOV  DH, 2
    MOV  DL, 5
    CALL SetCursorPos
    LEA  SI, str_t6_sub
    CALL PrintString

    MOV  DH, 4
    LEA  SI, reflected_matrix
    MOV  BH, ROWS          ; BH = row counter (CX is used by inner LOOP)

T6DispRow:
    MOV  DL, 18
    CALL SetCursorPos
    MOV  CX, COLS

T6DispCol:
    LODSB
    PUSH CX
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar
    MOV  AL, ' '
    CALL DisplayColorChar
    POP  CX
    LOOP T6DispCol

    INC  DH
    DEC  BH
    JNZ  T6DispRow

    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

DisplayReflectedMatrix ENDP

;===========================================================================
; Add to .DATA:
;
;   reflected_matrix  DB 28 DUP(0)
;   str_process       DB 'MATRIX PROCESSING',0
;   str_t6_sub        DB '________Horizontal Reflexion of the Matrix_____',0
;
; Add to MAIN after Task 5:
;
;   CALL Task6_HorizReflect
;   MOV  AH, 00h
;   INT  16h
;===========================================================================
