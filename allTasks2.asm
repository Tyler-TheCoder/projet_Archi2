;===========================================================================
; Program  : 2_lessons_on_matrices.asm
; Course   : ARCHI II  -  L2 ACAD A  2025-2026  (USTHB, FI)
;
; Description:
;   Interrupt-driven matrix processing demo using INT 1Ch periodic timer.
;   Every 30 seconds the timer ISR sets a flag; the main loop dispatches
;   the next task from the scenario lookup table.
;
;   Scenario (16 steps total):
;     T1 T2 T3 T4 T5   T1 T2 T3 T4 T5   T6 T7 T6 T7 T6 T7
;
;   Lesson 1 (x2)  Tasks 1-5 : matrix preprocessing
;   Lesson 2 (x3)  Tasks 6-7 : matrix reflections
;
;   INT 1Ch fires 18.2/sec. 546 ticks = 30 seconds.
;
; Tool   : GUI Turbo Assembler x64  (TASM 4.1 / TLINK)
; Mode   : IDEAL  (required: fixes @DATA undefined error in TASM 4.1)
;===========================================================================

IDEAL
MODEL  SMALL
STACK  200h

;===========================================================================
; DATA SEGMENT
;===========================================================================
SEGMENT _DATA

    ;--- Original matrix  4 rows x 7 columns = 28 bytes -------------------
    ; Hex escapes for special chars: 9Ch=£ 2Dh=- 26h=& 2Fh=/ 2Ah=* 3Dh==
    original_matrix  DB '9','7',9Ch,'2','1',2Dh,'2'   ; row 0
                     DB '4','M','8','2','6','3','F'    ; row 1
                     DB '9','u',9Ch,'4',26h,'6','7'   ; row 2
                     DB '0',2Fh,'6','2',2Ah,3Dh,'8'  ; row 3

    cleaned_matrix    DB 28 DUP(0)  ; Task2: non-digits replaced by '0'
    normalized_matrix DB 28 DUP(0)  ; Task3: values mapped to '0'/'1'
    reflect_matrix    DB 28 DUP(0)  ; Tasks 6&7: in-place working copy
    col_sums          DB 7  DUP(0)  ; Task5: column sum accumulators
    row_sum           DB 0          ; Tasks 4&5: running sum for current row

    ;--- Compile-time constants -------------------------------------------
    ROWS        EQU 4
    COLS        EQU 7
    TOTAL_CELLS EQU 28        ; = ROWS*COLS, literal avoids TASM expr error

    ;--- Color attributes  (INT 10h / AH=09h) -----------------------------
    WHITE_ON_BLACK  EQU 07h
    RED_ON_BLACK    EQU 0Ch
    GREEN_ON_BLACK  EQU 0Ah
    YELLOW_ON_BLACK EQU 0Eh

    ;--- Display strings (null-terminated) --------------------------------
    str_preproc  DB 'MATRIX PREPROCESSING',0
    str_process  DB 'MATRIX PROCESSING',0
    str_t1_sub   DB '__________________Matrix__________________',0
    str_t2_sub   DB '__________Step 1: Matrix Data Cleaning________',0
    str_t3_sub   DB '________Step 2: Matrix Data Normalization______',0
    str_t4_sub   DB '________Step 3: Matrix Reduction on Rows______',0
    str_t5_sub   DB '__Step 4: Matrix Reduction on Rows and Columns_',0
    str_t6_sub   DB '_______Horizontal Reflexion of the Matrix_____',0
    str_t7_sub   DB '_______Vertical Reflexion of the Matrix_______',0

    ;--- Task sequence: 16 entries, values 1-7 ----------------------------
    task_sequence  DB 1,2,3,4,5, 1,2,3,4,5, 6,7,6,7,6,7
    TOTAL_TASKS    EQU 16

    ;--- Runtime state variables ------------------------------------------
    task_index   DB 0          ; current step in task_sequence  (0..15)
    task_flag    DB 0          ; 1 = timer says "run next task now"
    tick_count   DW 0          ; ticks counted since last task trigger
    old_1ch_off  DW 0          ; saved INT 1Ch vector (offset)
    old_1ch_seg  DW 0          ; saved INT 1Ch vector (segment)

    TICKS_30SEC  EQU 546       ; 18.2 ticks/sec x 30 sec = 546

    ;--- Day/month name tables (3 bytes each, used by PrintDateTime) ------
    day_names    DB 'Sun','Mon','Tue','Wed','Thu','Fri','Sat'
    month_names  DB 'Jan','Feb','Mar','Apr','May','Jun'
                 DB 'Jul','Aug','Sep','Oct','Nov','Dec'

    ;--- Date/time scratch registers (written then read by PrintDateTime) -
    dt_dow  DB 0
    dt_day  DB 0
    dt_mon  DB 0
    dt_year DW 0
    dt_hour DB 0
    dt_min  DB 0
    dt_sec  DB 0

ENDS _DATA

;===========================================================================
; CODE SEGMENT
;===========================================================================
SEGMENT _TEXT

    ASSUME CS:_TEXT, DS:_DATA, ES:_DATA

;===========================================================================
; INT 1Ch INTERRUPT HANDLER
;   Called automatically ~18.2 times/sec (chained from INT 08h timer).
;   Increments tick_count; when it reaches TICKS_30SEC sets task_flag=1.
;   Must save/restore every register it modifies.
;===========================================================================
PROC Timer1Ch_Handler

    PUSH AX
    PUSH DS

    MOV  AX, _DATA            ; ISR needs its own DS initialisation
    MOV  DS, AX

    INC  [tick_count]          ; count this tick

    CMP  [tick_count], TICKS_30SEC
    JB   @@ISR_exit           ; not 30 seconds yet

    MOV  [tick_count], 0      ; reset counter
    MOV  [task_flag],  1      ; signal main loop

@@ISR_exit:
    POP  DS
    POP  AX
    IRET                      ; restores CS:IP and FLAGS for interrupted code

ENDP Timer1Ch_Handler

;===========================================================================
; MAIN  -  program entry point
;===========================================================================
PROC MAIN

    MOV  AX, _DATA
    MOV  DS, AX
    MOV  ES, AX               ; ES=DS required for STOSB

    ;--- Pre-build derived matrices (silent, no display) ------------------
    CALL BuildCleanedMatrix    ; original  -> cleaned
    CALL BuildNormalizedMatrix ; cleaned   -> normalized
    CALL BuildReflectMatrix    ; normalized-> reflect (reset for Tasks 6&7)

    ;--- Save the current INT 1Ch vector (INT 21h / AH=35h) ---------------
    MOV  AH, 35h
    MOV  AL, 1Ch
    INT  21h                   ; returns: ES=segment, BX=offset
    MOV  [old_1ch_off], BX
    MOV  [old_1ch_seg], ES
    MOV  AX, _DATA             ; reload _DATA (AX was clobbered by INT 21h)
    MOV  ES, AX                ; restore ES = DS

    ;--- Install our custom INT 1Ch handler (INT 21h / AH=25h) ------------
    CLI                        ; no interrupt while we modify the IVT
    MOV  AH, 25h
    MOV  AL, 1Ch
    MOV  DX, OFFSET Timer1Ch_Handler
    INT  21h                   ; DS:DX = new vector
    STI                        ; re-enable interrupts

    ;--- Main wait loop ---------------------------------------------------
@@MainLoop:
    CMP  [task_flag], 0
    JE   @@MainLoop            ; idle until ISR sets the flag

    MOV  [task_flag], 0        ; clear flag before dispatching

    ;--- Look up which task to run ----------------------------------------
    MOV  BL, [task_index]      ; BL = current step (0..15)
    MOV  BH, 0
    MOV  AL, [task_sequence+BX] ; AL = task number (1..7)

    CMP  AL, 1
    JE   @@DoT1
    CMP  AL, 2
    JE   @@DoT2
    CMP  AL, 3
    JE   @@DoT3
    CMP  AL, 4
    JE   @@DoT4
    CMP  AL, 5
    JE   @@DoT5
    CMP  AL, 6
    JE   @@DoT6
    JMP  @@DoT7

@@DoT1: CALL Task1_DisplayOriginal
        JMP  @@AfterTask
@@DoT2: CALL Task2_CleanMatrix
        JMP  @@AfterTask
@@DoT3: CALL Task3_NormalizeMatrix
        JMP  @@AfterTask
@@DoT4: CALL Task4_RowReduction
        JMP  @@AfterTask
@@DoT5: CALL Task5_ColReduction
        JMP  @@AfterTask
@@DoT6: CALL Task6_HorizReflect
        JMP  @@AfterTask
@@DoT7: CALL Task7_VertReflect

@@AfterTask:
    INC  [task_index]
    CMP  [task_index], TOTAL_TASKS
    JB   @@MainLoop            ; more tasks remain

    ;--- All 16 tasks done: restore INT 1Ch and exit ----------------------
    CLI
    MOV  AH, 25h
    MOV  AL, 1Ch
    PUSH DS
    MOV  DX, [old_1ch_off]
    MOV  AX, [old_1ch_seg]
    MOV  DS, AX
    INT  21h                   ; restore original vector
    POP  DS
    STI

    MOV  AH, 4Ch
    MOV  AL, 0
    INT  21h

ENDP MAIN

;===========================================================================
; BUILD HELPERS  -  populate work matrices without any display
;===========================================================================

;--- BuildCleanedMatrix  --------------------------------------------------
; Copies original_matrix to cleaned_matrix; non-digit chars become '0'.
; All registers preserved.
PROC BuildCleanedMatrix
    PUSH AX
    PUSH CX
    PUSH SI
    PUSH DI
    LEA  SI, [original_matrix]
    LEA  DI, [cleaned_matrix]
    MOV  CX, TOTAL_CELLS
@@BCM_loop:
    LODSB
    CMP  AL, '0'
    JB   @@BCM_rep
    CMP  AL, '9'
    JA   @@BCM_rep
    STOSB
    JMP  @@BCM_next
@@BCM_rep:
    MOV  AL, '0'
    STOSB
@@BCM_next:
    LOOP @@BCM_loop
    POP  DI
    POP  SI
    POP  CX
    POP  AX
    RET
ENDP BuildCleanedMatrix

;--- BuildNormalizedMatrix  -----------------------------------------------
; Copies cleaned_matrix to normalized_matrix; digit<5->'0', >=5->'1'.
; All registers preserved.
PROC BuildNormalizedMatrix
    PUSH AX
    PUSH CX
    PUSH SI
    PUSH DI
    LEA  SI, [cleaned_matrix]
    LEA  DI, [normalized_matrix]
    MOV  CX, TOTAL_CELLS
@@BNM_loop:
    LODSB
    SUB  AL, '0'              ; ASCII -> numeric  (0..9)
    CMP  AL, 5
    JAE  @@BNM_one
    MOV  AL, '0'
    JMP  @@BNM_store
@@BNM_one:
    MOV  AL, '1'
@@BNM_store:
    STOSB
    LOOP @@BNM_loop
    POP  DI
    POP  SI
    POP  CX
    POP  AX
    RET
ENDP BuildNormalizedMatrix

;--- BuildReflectMatrix  --------------------------------------------------
; Copies normalized_matrix to reflect_matrix (reset before each T6/T7 pair).
; All registers preserved.
PROC BuildReflectMatrix
    PUSH AX
    PUSH CX
    PUSH SI
    PUSH DI
    LEA  SI, [normalized_matrix]
    LEA  DI, [reflect_matrix]
    MOV  CX, TOTAL_CELLS
@@BRM_loop:
    LODSB
    STOSB
    LOOP @@BRM_loop
    POP  DI
    POP  SI
    POP  CX
    POP  AX
    RET
ENDP BuildReflectMatrix

;===========================================================================
; DISPLAY HEADER HELPER
;   Prints ClearScreen + DateTime line + header title + subtitle.
;   Input: SI_title  = string pointer passed in SI before call? No —
;   We pass the two string pointers via registers:
;     SI = pointer to title string  (str_preproc or str_process)
;     DI = pointer to subtitle string
;   DH is set to 2 when this returns (subtitle row).
;   All registers preserved except DH (caller must set DH after return).
;===========================================================================
PROC PrintHeader
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    CALL ClearScreen

    MOV  DH, 0
    MOV  DL, 1
    CALL SetCursorPos
    CALL PrintDateTime

    MOV  DH, 1
    MOV  DL, 10
    CALL SetCursorPos
    CALL PrintString          ; SI = title string

    MOV  DH, 2
    MOV  DL, 5
    CALL SetCursorPos
    MOV  SI, DI               ; DI = subtitle string
    CALL PrintString

    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
ENDP PrintHeader

;===========================================================================
; TASK 1  -  Display original matrix
;   Digits -> WHITE,  non-digits -> RED
;===========================================================================
PROC Task1_DisplayOriginal
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    LEA  SI, [str_preproc]
    LEA  DI, [str_t1_sub]
    CALL PrintHeader

    MOV  DH, 4
    LEA  SI, [original_matrix]
    MOV  BH, ROWS             ; BH = row counter (CX is used by inner LOOP)

@@T1_row:
    MOV  DL, 18
    CALL SetCursorPos
    MOV  CX, COLS

@@T1_col:
    LODSB
    PUSH CX
    CMP  AL, '0'
    JB   @@T1_red
    CMP  AL, '9'
    JA   @@T1_red
    MOV  BL, WHITE_ON_BLACK
    JMP  @@T1_print
@@T1_red:
    MOV  BL, RED_ON_BLACK
@@T1_print:
    CALL DisplayColorChar
    MOV  AL, ' '
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar
    POP  CX
    LOOP @@T1_col

    INC  DH
    DEC  BH
    JNZ  @@T1_row

    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
ENDP Task1_DisplayOriginal

;===========================================================================
; TASK 2  -  Clean matrix display
;   Replaced zeros -> RED,  original digits -> WHITE
;===========================================================================
PROC Task2_CleanMatrix
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    CALL BuildCleanedMatrix

    LEA  SI, [str_preproc]
    LEA  DI, [str_t2_sub]
    CALL PrintHeader

    MOV  DH, 4
    LEA  SI, [original_matrix]  ; parallel walk: orig to detect replacements
    LEA  DI, [cleaned_matrix]   ; cleaned to print
    MOV  BH, ROWS

@@T2_row:
    MOV  DL, 18
    CALL SetCursorPos
    MOV  CX, COLS

@@T2_col:
    PUSH CX
    MOV  AH, [SI]            ; AH = original char
    INC  SI
    MOV  AL, [DI]            ; AL = cleaned char
    INC  DI
    CMP  AL, AH              ; same -> was digit -> white
    JE   @@T2_wh
    MOV  BL, RED_ON_BLACK
    JMP  @@T2_pr
@@T2_wh:
    MOV  BL, WHITE_ON_BLACK
@@T2_pr:
    CALL DisplayColorChar
    MOV  AL, ' '
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar
    POP  CX
    LOOP @@T2_col

    INC  DH
    DEC  BH
    JNZ  @@T2_row

    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
ENDP Task2_CleanMatrix

;===========================================================================
; TASK 3  -  Normalize matrix display
;   All cells WHITE  ('0' or '1')
;===========================================================================
PROC Task3_NormalizeMatrix
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    CALL BuildNormalizedMatrix
    CALL BuildReflectMatrix

    LEA  SI, [str_preproc]
    LEA  DI, [str_t3_sub]
    CALL PrintHeader

    MOV  DH, 4
    LEA  SI, [normalized_matrix]
    MOV  BH, ROWS

@@T3_row:
    MOV  DL, 18
    CALL SetCursorPos
    MOV  CX, COLS

@@T3_col:
    LODSB
    PUSH CX
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar
    MOV  AL, ' '
    CALL DisplayColorChar
    POP  CX
    LOOP @@T3_col

    INC  DH
    DEC  BH
    JNZ  @@T3_row

    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
ENDP Task3_NormalizeMatrix

;===========================================================================
; TASK 4  -  Row sum reduction
;   Display normalized_matrix; append each row's sum in GREEN.
;   Register plan: BH=row counter, CX=col loop, CH saved for sum via stack.
;   We use a local memory var 'row_sum' to hold the running sum per row,
;   avoiding any conflict between CH (sum) and CX (LOOP counter).
;   Actually: CX is used by LOOP (full 16-bit). We use a PUSH/POP guard
;   around inner loop and keep sum in AH between iterations.
;===========================================================================
PROC Task4_RowReduction
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    LEA  SI, [str_preproc]
    LEA  DI, [str_t4_sub]
    CALL PrintHeader

    MOV  DH, 4
    LEA  SI, [normalized_matrix]
    MOV  BH, ROWS

@@T4_row:
    MOV  DL, 18
    CALL SetCursorPos
    MOV  CX, COLS
    MOV  [row_sum], 0         ; clear row sum for this row

@@T4_col:
    LODSB                     ; AL = '0' or '1'
    PUSH CX
    MOV  AH, AL               ; save char value before DisplayColorChar clobbers AL
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar     ; print cell  (AL still = char, BL = attr)
    MOV  AL, ' '
    CALL DisplayColorChar     ; space
    ; accumulate: AH holds the original char '0'/'1'
    MOV  AL, AH
    SUB  AL, '0'              ; 0 or 1
    ADD  [row_sum], AL
    POP  CX
    LOOP @@T4_col

    ; print row sum in GREEN
    MOV  AL, ' '
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar
    MOV  AL, [row_sum]
    ADD  AL, '0'
    MOV  BL, GREEN_ON_BLACK
    CALL DisplayColorChar

    INC  DH
    DEC  BH
    JNZ  @@T4_row

    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
ENDP Task4_RowReduction

;===========================================================================
; TASK 5  -  Row + Column sum reduction
;   Same as Task 4 (rows with GREEN sums), plus column sums in YELLOW below.
;   Column sums computed with explicit row/col counters (no LOOP conflict).
;===========================================================================
PROC Task5_ColReduction
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    ;--- Zero col_sums[] --------------------------------------------------
    LEA  DI, [col_sums]
    MOV  CX, COLS
    MOV  AL, 0
@@T5_zero:
    MOV  [DI], AL
    INC  DI
    LOOP @@T5_zero

    ;--- Accumulate column sums -------------------------------------------
    ; Use DH=row counter, DL=col counter to avoid CX/LOOP conflicts
    LEA  SI, [normalized_matrix]
    MOV  DH, ROWS

@@T5_acc_row:
    MOV  DL, 0
@@T5_acc_col:
    MOV  AL, [SI]
    SUB  AL, '0'              ; 0 or 1
    MOV  BL, DL               ; col index
    MOV  BH, 0
    ADD  [col_sums+BX], AL    ; col_sums[col] += value
    INC  SI
    INC  DL
    CMP  DL, COLS
    JB   @@T5_acc_col
    DEC  DH
    JNZ  @@T5_acc_row

    ;--- Display ----------------------------------------------------------
    LEA  SI, [str_preproc]
    LEA  DI, [str_t5_sub]
    CALL PrintHeader

    MOV  DH, 4
    LEA  SI, [normalized_matrix]
    MOV  BH, ROWS

@@T5_row:
    MOV  DL, 18
    CALL SetCursorPos
    MOV  CX, COLS
    MOV  [row_sum], 0

@@T5_col:
    LODSB
    PUSH CX
    MOV  AH, AL               ; save char before DisplayColorChar
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar
    MOV  AL, ' '
    CALL DisplayColorChar
    MOV  AL, AH
    SUB  AL, '0'
    ADD  [row_sum], AL
    POP  CX
    LOOP @@T5_col

    ; row sum in GREEN
    MOV  AL, ' '
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar
    MOV  AL, [row_sum]
    ADD  AL, '0'
    MOV  BL, GREEN_ON_BLACK
    CALL DisplayColorChar

    INC  DH
    DEC  BH
    JNZ  @@T5_row

    ;--- Column sums row in YELLOW (DH = row just below matrix) -----------
    MOV  DL, 18
    CALL SetCursorPos
    LEA  SI, [col_sums]
    MOV  CX, COLS

@@T5_colsum:
    LODSB
    PUSH CX
    ADD  AL, '0'
    MOV  BL, YELLOW_ON_BLACK
    CALL DisplayColorChar
    MOV  AL, ' '
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar
    POP  CX
    LOOP @@T5_colsum

    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
ENDP Task5_ColReduction

;===========================================================================
; TASK 6  -  Horizontal reflection
;   Resets reflect_matrix from normalized_matrix, then flips rows top<->bot.
;   For 4 rows: swap row0<->row3, swap row1<->row2  (ROWS/2 = 2 swaps).
;===========================================================================
PROC Task6_HorizReflect
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    CALL BuildReflectMatrix   ; always start from fresh normalized copy

    ;--- Swap rows pairwise: SI=top row ptr, DI=bottom row ptr ------------
    LEA  SI, [reflect_matrix]
    LEA  DI, [reflect_matrix + (ROWS-1)*COLS]
    MOV  BH, ROWS/2           ; number of row-pair swaps (=2)

@@T6_swap_pair:
    MOV  CX, COLS
@@T6_swap_byte:
    MOV  AL, [SI]
    MOV  AH, [DI]
    MOV  [SI], AH
    MOV  [DI], AL
    INC  SI
    INC  DI
    LOOP @@T6_swap_byte
    ; SI now at start of next row, DI now past the bottom row we just swapped.
    ; Move DI back by 2*COLS to point to the new inner bottom row.
    SUB  DI, COLS*2
    DEC  BH
    JNZ  @@T6_swap_pair

    ;--- Display reflect_matrix -------------------------------------------
    LEA  SI, [str_process]
    LEA  DI, [str_t6_sub]
    CALL PrintHeader

    MOV  DH, 4
    LEA  SI, [reflect_matrix]
    MOV  BH, ROWS

@@T6_row:
    MOV  DL, 18
    CALL SetCursorPos
    MOV  CX, COLS
@@T6_col:
    LODSB
    PUSH CX
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar
    MOV  AL, ' '
    CALL DisplayColorChar
    POP  CX
    LOOP @@T6_col
    INC  DH
    DEC  BH
    JNZ  @@T6_row

    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
ENDP Task6_HorizReflect

;===========================================================================
; TASK 7  -  Vertical reflection
;   Operates on reflect_matrix (already horizontally reflected by Task6).
;   Mirrors each row left-to-right in-place.
;   For COLS=7: swap col0<->col6, col1<->col5, col2<->col4. col3 unchanged.
;===========================================================================
PROC Task7_VertReflect
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    ;--- Reflect each row independently -----------------------------------
    LEA  BX, [reflect_matrix] ; BX = base of current row
    MOV  DH, ROWS             ; DH = row counter

@@T7_row:
    MOV  SI, BX               ; SI = left ptr (start of row)
    MOV  DI, BX
    ADD  DI, COLS-1           ; DI = right ptr (end of row)
    MOV  CX, COLS/2           ; number of element swaps (=3 for 7 cols)

@@T7_swap:
    MOV  AL, [SI]
    MOV  AH, [DI]
    MOV  [SI], AH
    MOV  [DI], AL
    INC  SI
    DEC  DI
    LOOP @@T7_swap

    ADD  BX, COLS             ; advance base to next row
    DEC  DH
    JNZ  @@T7_row

    ;--- Display reflect_matrix -------------------------------------------
    LEA  SI, [str_process]
    LEA  DI, [str_t7_sub]
    CALL PrintHeader

    MOV  DH, 4
    LEA  SI, [reflect_matrix]
    MOV  BH, ROWS

@@T7_row_disp:
    MOV  DL, 18
    CALL SetCursorPos
    MOV  CX, COLS
@@T7_col_disp:
    LODSB
    PUSH CX
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar
    MOV  AL, ' '
    CALL DisplayColorChar
    POP  CX
    LOOP @@T7_col_disp
    INC  DH
    DEC  BH
    JNZ  @@T7_row_disp

    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
ENDP Task7_VertReflect

;===========================================================================
; UTILITY PROCEDURES
;===========================================================================

;--- ClearScreen  ---  blanks 80x25 screen, homes cursor to (0,0) ---------
PROC ClearScreen
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    MOV  AH, 06h
    MOV  AL, 00h
    MOV  BH, WHITE_ON_BLACK
    MOV  CX, 0000h
    MOV  DH, 24
    MOV  DL, 79
    INT  10h
    MOV  AH, 02h
    MOV  BH, 0
    MOV  DX, 0
    INT  10h
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
ENDP ClearScreen

;--- SetCursorPos  ---  Input: DH=row, DL=col  ----------------------------
PROC SetCursorPos
    PUSH AX
    PUSH BX
    MOV  AH, 02h
    MOV  BH, 0
    INT  10h
    POP  BX
    POP  AX
    RET
ENDP SetCursorPos

;--- DisplayColorChar  ---  AL=char, BL=attr, then advance cursor ---------
PROC DisplayColorChar
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    MOV  AH, 09h
    MOV  BH, 0
    MOV  CX, 1
    INT  10h
    MOV  AH, 03h
    MOV  BH, 0
    INT  10h
    INC  DL
    MOV  AH, 02h
    INT  10h
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
ENDP DisplayColorChar

;--- PrintString  ---  DS:SI points to null-terminated string -------------
PROC PrintString
    PUSH AX
    PUSH BX
    PUSH SI
@@PStr:
    LODSB
    CMP  AL, 0
    JE   @@PStr_done
    MOV  AH, 0Eh
    MOV  BH, 0
    INT  10h
    JMP  @@PStr
@@PStr_done:
    POP  SI
    POP  BX
    POP  AX
    RET
ENDP PrintString

;--- PrintTwoDigits  ---  AL = value 0-99, printed as two ASCII digits ----
; Saves units in CL before INT 10h corrupts AH.
PROC PrintTwoDigits
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    MOV  AH, 0
    MOV  BL, 10
    DIV  BL                   ; AL=tens, AH=units
    MOV  CL, AH               ; save units NOW (INT 10h will clobber AH)
    ADD  AL, '0'
    MOV  AH, 0Eh
    MOV  BH, 0
    INT  10h                  ; print tens
    MOV  AL, CL
    ADD  AL, '0'
    MOV  AH, 0Eh
    MOV  BH, 0
    INT  10h                  ; print units
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
ENDP PrintTwoDigits

;--- PrintYear  ---  AX = year (e.g. 2026), printed as four digits --------
PROC PrintYear
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    MOV  BX, 100
    MOV  DX, 0
    DIV  BX                   ; AX=century(20), DX=yy(26)
    MOV  CX, DX               ; save yy
    CALL PrintTwoDigits        ; print century "20"
    MOV  AX, CX
    CALL PrintTwoDigits        ; print yy "26"
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
ENDP PrintYear

;--- PrintDateTime  ---  prints "DayName DD Mon YYYY  HH:MM:SS" ----------
; Uses dt_* memory vars to avoid register corruption across INT calls.
PROC PrintDateTime
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    MOV  AH, 2Ah              ; get date
    INT  21h                  ; CX=year, DH=month, DL=day, AL=dow
    MOV  [dt_dow],  AL
    MOV  [dt_day],  DL
    MOV  [dt_mon],  DH
    MOV  [dt_year], CX

    MOV  AH, 2Ch              ; get time
    INT  21h                  ; CH=hour, CL=min, DH=sec
    MOV  [dt_hour], CH
    MOV  [dt_min],  CL
    MOV  [dt_sec],  DH

    ;-- day name (3 chars) --
    MOV  BL, [dt_dow]
    MOV  BH, 0
    MOV  AL, 3
    MUL  BL
    LEA  SI, [day_names]
    ADD  SI, AX
    MOV  CX, 3
@@PD_d:
    LODSB
    MOV  AH, 0Eh
    MOV  BH, 0
    INT  10h
    LOOP @@PD_d
    MOV  AL, ' '
    MOV  AH, 0Eh
    INT  10h

    ;-- day number --
    MOV  AL, [dt_day]
    CALL PrintTwoDigits
    MOV  AL, ' '
    MOV  AH, 0Eh
    INT  10h

    ;-- month name (3 chars) --
    MOV  BL, [dt_mon]
    DEC  BL
    MOV  BH, 0
    MOV  AL, 3
    MUL  BL
    LEA  SI, [month_names]
    ADD  SI, AX
    MOV  CX, 3
@@PD_m:
    LODSB
    MOV  AH, 0Eh
    MOV  BH, 0
    INT  10h
    LOOP @@PD_m
    MOV  AL, ' '
    MOV  AH, 0Eh
    INT  10h

    ;-- year --
    MOV  AX, [dt_year]
    CALL PrintYear
    MOV  AL, ' '
    MOV  AH, 0Eh
    INT  10h
    MOV  AL, ' '
    MOV  AH, 0Eh
    INT  10h

    ;-- HH:MM:SS --
    MOV  AL, [dt_hour]
    CALL PrintTwoDigits
    MOV  AL, ':'
    MOV  AH, 0Eh
    INT  10h
    MOV  AL, [dt_min]
    CALL PrintTwoDigits
    MOV  AL, ':'
    MOV  AH, 0Eh
    INT  10h
    MOV  AL, [dt_sec]
    CALL PrintTwoDigits

    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
ENDP PrintDateTime

ENDS _TEXT

END MAIN
