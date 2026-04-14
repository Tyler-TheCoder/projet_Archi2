;===========================================================================
; EXTENSION  -  Conditional Task Execution based on matrix row sum
;
; Description:
;   After the main scenario finishes (Lesson 1 x2 + Lesson 2 x3), this
;   extension computes the total sum of all rows in normalized_matrix.
;   If the sum >= 10, Task 6 and Task 7 are executed one extra time as
;   a bonus lesson. Otherwise they are skipped and the program ends.
;
; Why >= 10?
;   normalized_matrix has 28 cells of '0' or '1' (max sum = 28).
;   A sum >= 10 means more than a third of the matrix is '1', indicating
;   a data-rich matrix worth processing further.
;
; How the 1Ch interrupt is used:
;   The Wait30Sec mechanism already uses INT 1Ch for timing.
;   This extension reuses the same Wait30Sec between the conditional tasks,
;   keeping the timing consistent with the rest of the program.
;   The condition check itself happens in MAIN, not inside the ISR --
;   this is cleaner and does not disturb the interrupt handler.
;
; Integration:
;   1. Add  total_sum DB 0  to the DATA segment
;   2. Add  str_ext_skip / str_ext_run  message strings to DATA
;   3. Call  ComputeTotalSum  after the lesson2Loop in MAIN
;   4. Call  RunExtension  right after
;
; Add to MAIN after lesson2Loop:
;
;     CALL ComputeTotalSum
;     CALL RunExtension
;
; Add to .DATA / SEGMENT _DATA:
;
;     total_sum   DB 0
;     str_ext_title DB 'EXTENSION : Conditional Task Execution',0
;     str_ext_run   DB 'Sum >= 10 : Running Tasks 6 and 7 again...',0
;     str_ext_skip  DB 'Sum < 10  : Tasks 6 and 7 skipped.',0
;===========================================================================

;---------------------------------------------------------------------------
; ComputeTotalSum
;   Sums all 28 cells of normalized_matrix ('0'/'1') into total_sum.
;   Since each cell is ASCII '0' or '1', we subtract '0' to get 0 or 1.
;   All registers preserved.
;---------------------------------------------------------------------------
PROC ComputeTotalSum

    PUSH AX
    PUSH CX
    PUSH SI

    LEA  SI, [normalized_matrix]
    MOV  CX, TOTAL_CELLS
    MOV  AH, 0                  ; AH = running sum

SumLoop:
    LODSB                       ; AL = '0' or '1'
    SUB  AL, '0'                ; convert ASCII to numeric (0 or 1)
    ADD  AH, AL                 ; accumulate
    LOOP SumLoop

    MOV  total_sum, AH          ; store result

    POP  SI
    POP  CX
    POP  AX
    RET

ENDP ComputeTotalSum

;---------------------------------------------------------------------------
; RunExtension
;   Checks total_sum. If >= 10, runs Task 6 + Task 7 with 30sec waits.
;   Displays a message either way so the user knows what happened.
;   All registers preserved.
;---------------------------------------------------------------------------
PROC RunExtension

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    CALL ClearScreen

    ; --- print extension header ---
    MOV  DH, 0
    MOV  DL, 1
    CALL SetCursorPos
    CALL PrintDateTime

    MOV  DH, 1
    MOV  DL, 10
    CALL SetCursorPos
    LEA  SI, [str_ext_title]
    CALL PrintString

    ; --- print the computed sum on row 3 ---
    MOV  DH, 3
    MOV  DL, 5
    CALL SetCursorPos

    ; print "Total matrix sum = XX"
    LEA  SI, [str_sum_label]
    CALL PrintString
    MOV  AL, total_sum
    CALL PrintTwoDigits

    ; --- check condition: sum >= 10? ---
    MOV  AL, total_sum
    CMP  AL, 10
    JB   ExtSkip                ; sum < 10 -> skip

    ; --- sum >= 10: run the extra tasks ---
    MOV  DH, 5
    MOV  DL, 5
    CALL SetCursorPos
    LEA  SI, [str_ext_run]
    CALL PrintString

    CALL Wait30Sec

    CALL Task6_HorizReflect
    CALL Wait30Sec

    CALL Task7_VertReflect
    CALL Wait30Sec

    JMP  ExtDone

ExtSkip:
    ; --- sum < 10: display skip message ---
    MOV  DH, 5
    MOV  DL, 5
    CALL SetCursorPos
    LEA  SI, [str_ext_skip]
    CALL PrintString

    CALL Wait30Sec              ; still wait so the user can read the message

ExtDone:
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

ENDP RunExtension

;===========================================================================
; Add these to your DATA segment:
;
;   total_sum     DB 0
;   str_ext_title DB 'EXTENSION : Conditional Task Execution',0
;   str_sum_label DB 'Total matrix sum = ',0
;   str_ext_run   DB 'Sum >= 10 : Running Tasks 6 and 7 again...',0
;   str_ext_skip  DB 'Sum < 10  : Tasks 6 and 7 skipped.',0
;
; Add these two calls at the END of MAIN, after the lesson2Loop:
;
;   CALL ComputeTotalSum
;   CALL RunExtension
;
; Final MAIN structure:
;
;   PROC MAIN
;       MOV AX, _DATA / MOV DS, AX / MOV ES, AX
;
;       MOV CX, 2
;   lesson1Loop:
;       PUSH CX
;       CALL Task1..5 with Wait30Sec between each
;       POP CX
;       LOOP lesson1Loop
;
;       MOV CX, 3
;   lesson2Loop:
;       PUSH CX
;       CALL Task6 + Wait30Sec
;       CALL Task7 + Wait30Sec
;       POP CX
;       LOOP lesson2Loop
;
;       CALL ComputeTotalSum    <- NEW
;       CALL RunExtension       <- NEW
;
;       MOV AH, 4Ch / INT 21h
;   ENDP MAIN
;===========================================================================
