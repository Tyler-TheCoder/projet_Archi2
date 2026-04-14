;===========================================================================
; Task 4  -  Row sum reduction
;
; Displays normalized_matrix (4 rows x 7 cols of '0'/'1') with each row's
; sum printed in GREEN to the right of that row.
;
; The sum for each row = number of 1s in that row (max 7, fits in one digit).
;
; Design note:
;   The actual row-display logic lives in a separate helper called
;   DisplayRowSums. Task 5 will call that same helper, then add the
;   column sums below it, so there is no code duplication between tasks.
;
; Plug-in: same structure as Tasks 1-3. Just add these two procedures
; to the existing file and call Task4_RowReduction from MAIN.
;===========================================================================

;---------------------------------------------------------------------------
; Task4_RowReduction
;   Entry point called from MAIN. Clears screen, prints the header,
;   then delegates the matrix+sums display to DisplayRowSums.
;---------------------------------------------------------------------------
Task4_RowReduction PROC

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    CALL ClearScreen

    ; --- date/time on row 0 ---
    MOV  DH, 0
    MOV  DL, 1
    CALL SetCursorPos
    CALL PrintDateTime

    ; --- title on row 1 ---
    MOV  DH, 1
    MOV  DL, 10
    CALL SetCursorPos
    LEA  SI, str_header
    CALL PrintString

    ; --- subtitle on row 2 ---
    MOV  DH, 2
    MOV  DL, 5
    CALL SetCursorPos
    LEA  SI, str_t4_sub
    CALL PrintString

    ; --- matrix + row sums starting at screen row 4 ---
    MOV  DH, 4
    CALL DisplayRowSums   ; DH tells it where to start drawing

    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

Task4_RowReduction ENDP

;---------------------------------------------------------------------------
; DisplayRowSums
;   Draws normalized_matrix row by row in WHITE, then appends each row's
;   sum in GREEN. Does NOT clear the screen or print the header — the caller
;   handles that. This lets Task 5 reuse it without duplication.
;
;   Input : DH = screen row to start on (caller sets this before calling)
;   Output: DH = screen row just after the last matrix row  (Task 5 needs
;           this to know where to print the column sums)
;
;   Register plan:
;     SI  = pointer walking through normalized_matrix
;     BH  = outer loop counter (rows remaining)  -- we use BH instead of CX
;           because the inner LOOP instruction needs CX for the column count
;     CX  = inner loop counter (columns)
;     AH  = row sum accumulator for the current row
;           (we use AH instead of another memory variable to keep it simple;
;            AL is used for the actual character being printed)
;---------------------------------------------------------------------------
DisplayRowSums PROC

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH SI

    ; DH is passed in by the caller, do not touch it here
    LEA  SI, normalized_matrix
    MOV  BH, ROWS              ; BH counts down from 4 to 0

RowLoop:
    MOV  DL, 18                ; each row starts at column 18
    CALL SetCursorPos

    MOV  CX, COLS              ; 7 columns per row
    MOV  AH, 0                 ; reset row sum to 0 for this row

ColLoop:
    LODSB                      ; AL = next cell ('0' or '1'), SI++

    PUSH CX                    ; protect CX from CALL instructions inside
    PUSH AX                    ; protect AH (our sum) from DisplayColorChar

    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar      ; print the cell character

    MOV  AL, ' '               ; space between cells
    CALL DisplayColorChar

    POP  AX                    ; restore AH (sum) and AL (the cell value)
    POP  CX

    ; accumulate: AL still holds the character we just printed ('0' or '1')
    SUB  AL, '0'               ; '0'->0, '1'->1
    ADD  AH, AL                ; add to row sum (AH stays 0-7, no overflow)

    LOOP ColLoop               ; CX--, jump back if CX != 0

    ; --- print the row sum in GREEN ---
    ; one space gap before the number
    MOV  AL, ' '
    MOV  BL, WHITE_ON_BLACK
    PUSH AX
    CALL DisplayColorChar
    POP  AX

    ; AH holds the sum (0-7), convert to ASCII and print in green
    MOV  AL, AH
    ADD  AL, '0'               ; numeric -> ASCII digit
    MOV  BL, GREEN_ON_BLACK
    CALL DisplayColorChar

    INC  DH                    ; move down one screen row
    DEC  BH                    ; one fewer matrix row to go
    JNZ  RowLoop               ; keep going until BH reaches 0

    ; DH now points to the row just below the matrix.
    ; We leave it here so Task 5 can read it after we return.

    POP  SI
    POP  CX
    POP  BX
    POP  AX
    RET

DisplayRowSums ENDP

;===========================================================================
; Data to add in the .DATA section:
;
;   str_t4_sub  DB '________Step 3: Matrix Reduction on Rows______',0
;   GREEN_ON_BLACK EQU 0Ah
;
; (GREEN_ON_BLACK and str_t4_sub need to be declared alongside the other
;  color constants and strings already in the .DATA section)
;===========================================================================
