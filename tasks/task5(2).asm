;===========================================================================
; Task 5  -  Row + Column sum reduction
;
; Displays exactly like Task 4 (matrix in white + row sums in green),
; then adds one extra row below the matrix showing column sums in YELLOW.
;
; Column sum for column C = cell[0][C] + cell[1][C] + cell[2][C] + cell[3][C]
; Since every cell is 0 or 1, each column sum is at most 4 (one digit).
;
; Strategy:
;   1. Compute all 7 column sums and store them in col_sums[7].
;   2. Clear screen + print header.
;   3. Call DisplayRowSums (reused from Task 4) to draw the matrix+row sums.
;      DisplayRowSums leaves DH pointing to the row just below the matrix.
;   4. Print the column sums on that row in YELLOW.
;
; Data to add in .DATA:
;   col_sums       DB 7 DUP(0)
;   str_t5_sub     DB '__Step 4: Matrix Reduction on Rows and Columns_',0
;   YELLOW_ON_BLACK EQU 0Eh
;===========================================================================

;---------------------------------------------------------------------------
; Task5_ColReduction  -  entry point called from MAIN
;---------------------------------------------------------------------------
Task5_ColReduction PROC

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    ; --- Step 1: compute column sums and store in col_sums[] ---
    ; We walk the matrix column by column.
    ; For column C, the cells are at offsets: C, C+7, C+14, C+21
    ; (because each row is 7 bytes wide, stored flat in memory)

    LEA  DI, col_sums          ; DI = pointer into col_sums array
    MOV  BL, 0                 ; BL = current column index (0..6)

ColSumLoop:
    ; sum up all ROWS values for this column
    LEA  SI, normalized_matrix
    ADD  SI, BX                ; SI now points to row 0 of this column
                               ; (BX = BL zero-extended = column index)
    MOV  AH, 0                 ; AH = column sum accumulator

    MOV  CX, ROWS              ; 4 rows to sum

ColSumRowLoop:
    MOV  AL, [SI]              ; AL = cell value ('0' or '1')
    SUB  AL, '0'               ; convert ASCII to numeric (0 or 1)
    ADD  AH, AL                ; accumulate
    ADD  SI, COLS              ; jump down one row (7 bytes forward)
    LOOP ColSumRowLoop

    MOV  [DI], AH              ; store the column sum
    INC  DI                    ; advance to next slot in col_sums
    INC  BL                    ; next column
    CMP  BL, COLS              ; done all 7 columns?
    JB   ColSumLoop

    ; --- Step 2: clear screen and print header ---
    CALL ClearScreen

    MOV  DH, 0
    MOV  DL, 1
    CALL SetCursorPos
    CALL PrintDateTime

    MOV  DH, 1
    MOV  DL, 10
    CALL SetCursorPos
    LEA  SI, str_header
    CALL PrintString

    MOV  DH, 2
    MOV  DL, 5
    CALL SetCursorPos
    LEA  SI, str_t5_sub
    CALL PrintString

    ; --- Step 3: draw the matrix rows + green row sums ---
    ; DisplayRowSums starts at whatever DH we set, and updates DH
    ; to point to the row right after the last matrix row when it returns.
    MOV  DH, 4
    CALL DisplayRowSums        ; after this, DH = row just below the matrix

    ; --- Step 4: print column sums in YELLOW on the current row ---
    MOV  DL, 18                ; same left margin as the matrix rows
    CALL SetCursorPos

    LEA  SI, col_sums
    MOV  CX, COLS              ; 7 column sums to print

ColSumPrintLoop:
    LODSB                      ; AL = next column sum value (0..4)
    PUSH CX
    ADD  AL, '0'               ; convert to ASCII digit
    MOV  BL, YELLOW_ON_BLACK
    CALL DisplayColorChar      ; print in yellow
    MOV  AL, ' '
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar      ; space between numbers
    POP  CX
    LOOP ColSumPrintLoop

    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

Task5_ColReduction ENDP

;===========================================================================
; Add to .DATA section:
;
;   col_sums        DB 7 DUP(0)
;   str_t5_sub      DB '__Step 4: Matrix Reduction on Rows and Columns_',0
;   YELLOW_ON_BLACK EQU 0Eh
;
; Add to MAIN after Task 4:
;
;   CALL Task5_ColReduction
;   MOV  AH, 00h
;   INT  16h
;===========================================================================
