;===========================================================================
; Program  : 2_lessons_on_matrices.asm
; Course   : ARCHI II  -  L2 ACAD A  2025-2026  (USTHB, FI)
; Author   : [Your Name / Group]
;
; Description:
;   Interrupt-driven matrix processing demo using INT 1Ch periodic timer.
;   Every 30 seconds the timer ISR sets a flag; the main loop dispatches
;   the next task from a scenario lookup table.
;
;   Scenario (16 steps total):
;     T1 T2 T3 T4 T5   T1 T2 T3 T4 T5   T6 T7 T6 T7 T6 T7
;
;   Lesson 1 (x2) - Tasks 1-5 : matrix preprocessing
;   Lesson 2 (x3) - Tasks 6-7 : matrix reflections (T6 then T7 per pair)
;
;   Timer:  INT 1Ch fires ~18.2 times/sec.  546 ticks = 30 seconds.
;
; Tool    : GUI Turbo Assembler x64  (TASM 4.1 / TLINK)
; Mode    : IDEAL  (required: fixes @DATA undefined error in TASM 4.1)
;===========================================================================

IDEAL
MODEL  SMALL
STACK  200h

;===========================================================================
; DATA SEGMENT
;===========================================================================
SEGMENT _DATA

    ;-----------------------------------------------------------------------
    ; Original 4x7 matrix (4 rows, 7 columns = 28 bytes)
    ; Contains digits AND non-digit symbols/letters to demonstrate cleaning.
    ; Special chars encoded as hex: 9Ch=£  2Dh=-  26h=&  2Fh=/  2Ah=*  3Dh==
    ;-----------------------------------------------------------------------
    original_matrix  DB '9','7',9Ch,'2','1',2Dh,'2'   ; row 0
                     DB '4','M','8','2','6','3','F'    ; row 1
                     DB '9','u',9Ch,'4',26h,'6','7'   ; row 2
                     DB '0',2Fh,'6','2',2Ah,3Dh,'8'  ; row 3

    ;--- Derived work matrices (built once at startup, silently) -----------
    cleaned_matrix    DB 28 DUP(0)  ; Task 2: non-digits replaced by '0'
    normalized_matrix DB 28 DUP(0)  ; Task 3: values mapped to '0' or '1'
    reflect_matrix    DB 28 DUP(0)  ; Tasks 6 & 7: working copy reset at T6

    ;--- Accumulators -------------------------------------------------------
    col_sums  DB 7 DUP(0)   ; Task 5: per-column running sums
    row_sum   DB 0           ; Tasks 4 & 5: running sum for the current row

    ;--- Compile-time matrix dimensions -------------------------------------
    ROWS        EQU 4
    COLS        EQU 7
    TOTAL_CELLS EQU 28       ; ROWS*COLS (literal avoids TASM expression error)

    ;--- Video attribute bytes (INT 10h / AH=09h) --------------------------
    WHITE_ON_BLACK  EQU 07h
    RED_ON_BLACK    EQU 0Ch
    GREEN_ON_BLACK  EQU 0Ah
    YELLOW_ON_BLACK EQU 0Eh

    ;--- Display strings (null-terminated) ---------------------------------
    str_preproc  DB 'MATRIX PREPROCESSING',0
    str_process  DB 'MATRIX PROCESSING',0

    ; Each subtitle string uses underscores to form a decorative border
    str_t1_sub   DB '__________________Matrix__________________',0
    str_t2_sub   DB '__________Step 1: Matrix Data Cleaning________',0
    str_t3_sub   DB '________Step 2: Matrix Data Normalization______',0
    str_t4_sub   DB '________Step 3: Matrix Reduction on Rows______',0
    str_t5_sub   DB '__Step 4: Matrix Reduction on Rows and Columns_',0
    str_t6_sub   DB '_______Horizontal Reflexion of the Matrix_____',0
    str_t7_sub   DB '_______Vertical Reflexion of the Matrix_______',0

    ;--- Task execution sequence: 16 entries, values 1-7 ------------------
    ; Lesson 1 twice (tasks 1-5, 1-5) then Lesson 2 three times (6-7, 6-7, 6-7)
    task_sequence  DB 1,2,3,4,5, 1,2,3,4,5, 6,7,6,7,6,7
    TOTAL_TASKS    EQU 16

    ;--- Runtime state variables -------------------------------------------
    task_index   DB 0     ; current position in task_sequence (0..15)
    task_flag    DB 0     ; 1 = ISR signalled "run the next task now"
    tick_count   DW 0     ; ticks elapsed since the last task was triggered
    old_1ch_off  DW 0     ; saved INT 1Ch vector - offset
    old_1ch_seg  DW 0     ; saved INT 1Ch vector - segment

    TICKS_30SEC  EQU 18  ; 18.2 ticks/sec * 30 sec ≈ 546

    ;--- Day and month name tables (3 bytes per entry, no separators) ------
    day_names    DB 'Sun','Mon','Tue','Wed','Thu','Fri','Sat'
    month_names  DB 'Jan','Feb','Mar','Apr','May','Jun'
                 DB 'Jul','Aug','Sep','Oct','Nov','Dec'

    ;--- Date/time scratch storage (populated once per PrintDateTime call) -
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
; INT 1Ch INTERRUPT HANDLER  (Timer1Ch_Handler)
;
; Called automatically ~18.2 times/second (chained from INT 08h).
; Counts ticks; when TICKS_30SEC is reached it sets task_flag and resets
; the counter, signalling the main loop to dispatch the next task.
;
; Design rule: do only the minimum necessary here (increment + compare).
; All display work is deferred to the main loop to keep the ISR short.
; Registers: AX and DS are the only ones touched; both are saved/restored.
;===========================================================================
PROC Timer1Ch_Handler

    PUSH AX
    PUSH DS

    MOV  AX, _DATA         ; ISR must initialise its own DS
    MOV  DS, AX

    INC  [tick_count]       ; count this hardware tick

    CMP  [tick_count], TICKS_30SEC
    JB   @@ISR_exit         ; 30 seconds not yet elapsed

    MOV  [tick_count], 0   ; reset tick counter for next interval
    MOV  [task_flag],  1   ; signal main loop: time to run next task

@@ISR_exit:
    POP  DS
    POP  AX
    IRET                    ; restores CS:IP and FLAGS for the interrupted code

ENDP Timer1Ch_Handler

;===========================================================================
; MAIN  -  program entry point
;
; Sequence:
;   1. Initialise data segment registers
;   2. Pre-build derived matrices (cleaned, normalized, reflect copy)
;   3. Save current INT 1Ch vector and install our custom handler
;   4. Main wait loop: idle until ISR sets task_flag, then dispatch task
;   5. After all 16 tasks: restore INT 1Ch vector and exit
;===========================================================================
PROC MAIN

    ;--- Initialise segment registers --------------------------------------
    MOV  AX, _DATA
    MOV  DS, AX
    MOV  ES, AX             ; ES=DS is required by STOSB in build helpers

    ;--- Pre-build all derived matrices once (no screen output) ------------
    CALL BuildCleanedMatrix      ; original  -> cleaned  (replaces non-digits with '0')
    CALL BuildNormalizedMatrix   ; cleaned   -> normalized (maps digits to '0'/'1')
    CALL BuildReflectMatrix      ; normalized-> reflect  (initial copy for Tasks 6&7)

    ;--- Save the current INT 1Ch vector: INT 21h / AH=35h -----------------
    MOV  AH, 35h
    MOV  AL, 1Ch
    INT  21h                ; returns ES=segment  BX=offset of current handler
    MOV  [old_1ch_off], BX
    MOV  [old_1ch_seg], ES
    MOV  AX, _DATA          ; restore AX/_DATA (clobbered by INT 21h)
    MOV  ES, AX             ; restore ES = DS (INT 21h changed ES above)

    ;--- Install our INT 1Ch handler: INT 21h / AH=25h ---------------------
    CLI                     ; disable interrupts while modifying the IVT
    MOV  AH, 25h
    MOV  AL, 1Ch
    MOV  DX, OFFSET Timer1Ch_Handler
    INT  21h                ; DS:DX = address of new handler
    STI                     ; re-enable interrupts

    ;--- Main idle loop: waits for ISR to set task_flag --------------------
@@MainLoop:
    CMP  [task_flag], 0
    JE   @@MainLoop         ; spin until 30-second timer fires

    MOV  [task_flag], 0     ; clear flag before dispatching (avoid re-entry)

    ;--- Dispatch the correct task using the sequence lookup table ---------
    MOV  BL, [task_index]   ; BL = current step index (0..15)
    MOV  BH, 0
    MOV  AL, [task_sequence+BX]  ; AL = task number (1..7)

    ; Dispatch table via cascaded comparisons
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
    JMP  @@DoT7              ; AL must be 7 here

@@DoT1: CALL Task1_DisplayOriginal   
    JMP @@AfterTask
@@DoT2: CALL Task2_CleanMatrix       
    JMP @@AfterTask
@@DoT3: CALL Task3_NormalizeMatrix   
    JMP @@AfterTask
@@DoT4: CALL Task4_RowReduction      
    JMP @@AfterTask
@@DoT5: CALL Task5_ColReduction      
    JMP @@AfterTask
@@DoT6: CALL Task6_HorizReflect      
    JMP @@AfterTask
@@DoT7: CALL Task7_VertReflect

@@AfterTask:
    INC  [task_index]
    CMP  [task_index], TOTAL_TASKS
    JB   @@MainLoop          ; more tasks remain, keep looping

    ;--- All 16 tasks completed: restore INT 1Ch and exit cleanly ----------
    CLI
    MOV  AH, 25h
    MOV  AL, 1Ch
    PUSH DS
    MOV  DX, [old_1ch_off]
    MOV  AX, [old_1ch_seg]
    MOV  DS, AX
    INT  21h                 ; restore the original INT 1Ch vector
    POP  DS
    STI

    MOV  AH, 4Ch             ; DOS terminate program
    MOV  AL, 0               ; exit code 0 = success
    INT  21h

ENDP MAIN

;===========================================================================
; BUILD HELPERS
; These procedures silently populate the derived matrices at startup.
; They are also called again inside individual Task procedures to ensure
; the displayed data is always consistent with the current matrix state.
; All registers are fully saved and restored (caller-transparent).
;===========================================================================

;---------------------------------------------------------------------------
; BuildCleanedMatrix
; Copies original_matrix to cleaned_matrix.
; Every non-digit character (ASCII < '0' or > '9') is replaced with '0'.
;---------------------------------------------------------------------------
PROC BuildCleanedMatrix
    PUSH AX
    PUSH CX
    PUSH SI
    PUSH DI

    LEA  SI, [original_matrix]
    LEA  DI, [cleaned_matrix]
    MOV  CX, TOTAL_CELLS

@@BCM_loop:
    LODSB                   ; AL = next character from original matrix
    CMP  AL, '0'
    JB   @@BCM_replace      ; below '0' -> not a digit
    CMP  AL, '9'
    JA   @@BCM_replace      ; above '9' -> not a digit
    STOSB                   ; digit: copy as-is
    JMP  @@BCM_next
@@BCM_replace:
    MOV  AL, '0'
    STOSB                   ; non-digit: store '0'
@@BCM_next:
    LOOP @@BCM_loop

    POP  DI
    POP  SI
    POP  CX
    POP  AX
    RET
ENDP BuildCleanedMatrix

;---------------------------------------------------------------------------
; BuildNormalizedMatrix
; Copies cleaned_matrix to normalized_matrix.
; Digit < '5' -> store '0';  digit >= '5' -> store '1'.
;---------------------------------------------------------------------------
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
    SUB  AL, '0'            ; convert ASCII digit to numeric value (0..9)
    CMP  AL, 5
    JAE  @@BNM_one          ; >= 5 -> normalize to 1
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

;---------------------------------------------------------------------------
; BuildReflectMatrix
; Copies normalized_matrix to reflect_matrix.
; Called at the start of Task 6 to reset the working copy before each
; T6-T7 lesson-2 pair, so every pair starts from the normalized state.
;---------------------------------------------------------------------------
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
; PrintHeader
;
; Clears the screen, then prints:
;   Row 0, col  1 : current date and time
;   Row 1, col 10 : lesson title   (SI = pointer to null-terminated string)
;   Row 2, col  5 : task subtitle  (DI = pointer to null-terminated string)
;
; Called by every Task procedure before displaying matrix data.
; On return DH = 2 (the subtitle row); caller increments DH as needed
; to position subsequent matrix rows starting at row 4.
;
; Registers modified: DH (caller uses it); all others preserved.
;===========================================================================
PROC PrintHeader
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    CALL ClearScreen

    ;-- Line 0: date and time at left margin ------
    MOV  DH, 0
    MOV  DL, 1
    CALL SetCursorPos
    CALL PrintDateTime

    ;-- Line 1: lesson title centred --------------
    MOV  DH, 1
    MOV  DL, 10
    CALL SetCursorPos
    CALL PrintString          ; SI still points to the title string

    ;-- Line 2: task subtitle ---------------------
    MOV  DH, 2
    MOV  DL, 5
    CALL SetCursorPos
    MOV  SI, DI               ; DI carries the subtitle pointer; move into SI
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
; TASK 1  -  Display the original matrix
;
; Iterates original_matrix. Digits are printed WHITE; non-digits RED.
; This visually flags the "dirty" cells before cleaning takes place.
; The cleaned/normalized matrices are NOT modified here.
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

    MOV  DH, 4                ; matrix display starts at screen row 4
    LEA  SI, [original_matrix]
    MOV  BH, ROWS             ; BH = row counter (CX is used by inner LOOP)

@@T1_row:
    MOV  DL, 18               ; column 18: centre the matrix on an 80-col screen
    CALL SetCursorPos
    MOV  CX, COLS

@@T1_col:
    LODSB                     ; AL = current matrix element
    PUSH CX                   ; protect CX from DisplayColorChar

    CMP  AL, '0'
    JB   @@T1_red             ; below digit range -> highlight red
    CMP  AL, '9'
    JA   @@T1_red             ; above digit range -> highlight red
    MOV  BL, WHITE_ON_BLACK
    JMP  @@T1_print
@@T1_red:
    MOV  BL, RED_ON_BLACK
@@T1_print:
    CALL DisplayColorChar     ; print the matrix cell with chosen colour
    MOV  AL, ' '              ; inter-cell space in white
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar

    POP  CX
    LOOP @@T1_col

    INC  DH                   ; next screen row
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
;
; Rebuilds cleaned_matrix (non-digit -> '0'), then displays it.
; Cells that were replaced appear RED to show which values were cleaned;
; cells that were already digits appear WHITE (unchanged from original).
;
; Technique: walk original_matrix and cleaned_matrix in parallel.
; If original != cleaned at a position, it was replaced -> colour RED.
;===========================================================================
PROC Task2_CleanMatrix
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    CALL BuildCleanedMatrix    ; refresh cleaned_matrix from current original

    LEA  SI, [str_preproc]
    LEA  DI, [str_t2_sub]
    CALL PrintHeader

    MOV  DH, 4
    LEA  SI, [original_matrix] ; SI: original  (to detect which cells changed)
    LEA  DI, [cleaned_matrix]  ; DI: cleaned   (actual values to print)
    MOV  BH, ROWS

@@T2_row:
    MOV  DL, 18
    CALL SetCursorPos
    MOV  CX, COLS

@@T2_col:
    PUSH CX
    MOV  AH, [SI]              ; AH = original character
    INC  SI
    MOV  AL, [DI]              ; AL = cleaned character (printed value)
    INC  DI

    CMP  AL, AH                ; if equal: was already a digit -> white
    JE   @@T2_white
    MOV  BL, RED_ON_BLACK      ; not equal: was replaced -> red
    JMP  @@T2_print
@@T2_white:
    MOV  BL, WHITE_ON_BLACK
@@T2_print:
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
;
; Rebuilds normalized_matrix (digit<5->'0', digit>=5->'1') from the
; cleaned matrix, then rebuilds reflect_matrix (so Tasks 6&7 always
; start from the freshest normalized state).
; All cells displayed WHITE.
;===========================================================================
PROC Task3_NormalizeMatrix
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    CALL BuildNormalizedMatrix  ; refresh normalized_matrix
    CALL BuildReflectMatrix     ; keep reflect_matrix in sync for Lesson 2

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
;
; Displays normalized_matrix with each row's sum appended in GREEN.
; Sum is computed inline while printing; stored in memory variable row_sum
; to avoid conflicts between CH (sum scratch) and the CX LOOP counter.
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
    MOV  [row_sum], 0          ; reset running sum for this row

@@T4_col:
    LODSB                      ; AL = '0' or '1'
    PUSH CX
    MOV  AH, AL                ; save char value; DisplayColorChar will modify AL
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar      ; print the cell
    MOV  AL, ' '
    CALL DisplayColorChar      ; inter-cell space

    MOV  AL, AH                ; recover cell value
    SUB  AL, '0'               ; ASCII -> numeric: 0 or 1
    ADD  [row_sum], AL         ; accumulate

    POP  CX
    LOOP @@T4_col

    ;-- Print row sum in GREEN at end of row --
    MOV  AL, ' '
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar      ; separator space before sum
    MOV  AL, [row_sum]
    ADD  AL, '0'               ; numeric -> ASCII (sum <= 7, single digit)
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
;
; Identical to Task 4 for the row sums (GREEN), plus a row of column
; sums in YELLOW printed below the matrix.
;
; Column sums are accumulated in a separate pass over normalized_matrix
; before display begins, using explicit row/col counters (DH/DL) instead
; of the CX LOOP instruction to avoid register conflicts.
;===========================================================================
PROC Task5_ColReduction
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    ;--- Zero the col_sums array before accumulation ----------------------
    LEA  DI, [col_sums]
    MOV  CX, COLS
    MOV  AL, 0
@@T5_zero:
    MOV  [DI], AL
    INC  DI
    LOOP @@T5_zero

    ;--- Pass 1: accumulate column sums -----------------------------------
    ; Use DH (row counter) and DL (col counter) to index;
    ; BX used as base-relative index into col_sums[].
    LEA  SI, [normalized_matrix]
    MOV  DH, ROWS

@@T5_acc_row:
    MOV  DL, 0                 ; reset column counter for each new row
@@T5_acc_col:
    MOV  AL, [SI]
    SUB  AL, '0'               ; numeric value: 0 or 1
    MOV  BL, DL                ; BL = column index
    MOV  BH, 0
    ADD  [col_sums+BX], AL     ; col_sums[col] += value
    INC  SI
    INC  DL
    CMP  DL, COLS
    JB   @@T5_acc_col          ; next column in this row
    DEC  DH
    JNZ  @@T5_acc_row          ; next row

    ;--- Pass 2: display matrix with row sums (same as Task 4) -----------
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
    MOV  AH, AL                ; save char value
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar
    MOV  AL, ' '
    CALL DisplayColorChar
    MOV  AL, AH
    SUB  AL, '0'
    ADD  [row_sum], AL
    POP  CX
    LOOP @@T5_col

    ;-- GREEN row sum --
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

    ;--- Pass 3: display column sums in YELLOW on the row below matrix ----
    ; DH is now pointing to the first row below the matrix
    MOV  DL, 18
    CALL SetCursorPos
    LEA  SI, [col_sums]
    MOV  CX, COLS

@@T5_colsum:
    LODSB                      ; AL = column sum (0..4 for a 4-row binary matrix)
    PUSH CX
    ADD  AL, '0'               ; numeric -> ASCII
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
; TASK 6  -  Horizontal reflection (flip rows top <-> bottom)
;
; Always begins by resetting reflect_matrix from normalized_matrix, so
; every T6-T7 pair in Lesson 2 starts from the same baseline state.
;
; Algorithm:
;   Two row pointers: SI = first row, DI = last row.
;   Swap bytes element-by-element across both rows (CX=COLS swaps).
;   Move SI forward one row, DI backward one row; repeat ROWS/2 times.
;
; After in-place swapping, displays reflect_matrix (now horizontally
; flipped).  Task 7 will then further vertically flip this same buffer.
;===========================================================================
PROC Task6_HorizReflect
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    CALL BuildReflectMatrix    ; reset working copy from normalized (each T6 starts fresh)

    ;--- Swap rows pairwise: top row <-> bottom row -----------------------
    LEA  SI, [reflect_matrix]                   ; SI -> row 0 (top)
    LEA  DI, [reflect_matrix + (ROWS-1)*COLS]   ; DI -> row 3 (bottom)
    MOV  BH, ROWS/2            ; number of row-pair swaps needed (= 2 for 4 rows)

@@T6_swap_pair:
    MOV  CX, COLS              ; swap all COLS bytes of this pair
@@T6_swap_byte:
    MOV  AL, [SI]              ; AL = element from top row
    MOV  AH, [DI]              ; AH = element from bottom row
    MOV  [SI], AH              ; top row <- bottom value
    MOV  [DI], AL              ; bottom row <- top value
    INC  SI
    INC  DI
    LOOP @@T6_swap_byte
    ; After the loop SI is at the start of the next (inner) top row.
    ; DI has gone past the bottom row we just swapped; retreat by 2*COLS
    ; to point to the new inner bottom row.
    SUB  DI, COLS*2
    DEC  BH
    JNZ  @@T6_swap_pair

    ;--- Display the horizontally reflected matrix ------------------------
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
; TASK 7  -  Vertical reflection (mirror each row left <-> right)
;
; Operates directly on reflect_matrix which Task 6 already flipped
; horizontally.  This produces the full horizontal+vertical reflection.
;
; Note: BuildReflectMatrix is NOT called here.  Task 6 resets the buffer;
; Task 7 continues from where Task 6 left off (in-place vertical flip).
;
; Algorithm per row:
;   SI = left pointer (start of row)
;   DI = right pointer (end of row = start + COLS - 1)
;   Swap SI<->DI, advance SI, retreat DI, repeat COLS/2 times.
;   (Middle element of an odd-length row is untouched.)
;===========================================================================
PROC Task7_VertReflect
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    ;--- Mirror each row in-place -----------------------------------------
    LEA  BX, [reflect_matrix]  ; BX = base address of current row
    MOV  DH, ROWS              ; DH = row counter

@@T7_row:
    MOV  SI, BX                ; SI = left edge of this row
    MOV  DI, BX
    ADD  DI, COLS-1            ; DI = right edge of this row
    MOV  CX, COLS/2            ; number of element swaps (3 for COLS=7)

@@T7_swap:
    MOV  AL, [SI]              ; AL = left element
    MOV  AH, [DI]              ; AH = right element
    MOV  [SI], AH              ; left  <- right value
    MOV  [DI], AL              ; right <- left value
    INC  SI
    DEC  DI
    LOOP @@T7_swap

    ADD  BX, COLS              ; advance base pointer to next row
    DEC  DH
    JNZ  @@T7_row

    ;--- Display the fully reflected (horiz + vert) matrix ----------------
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

;---------------------------------------------------------------------------
; ClearScreen
; Scrolls the entire 80x25 text screen up by 0 lines (= blank it) using
; INT 10h / AH=06h, then homes the cursor to position (0, 0).
;---------------------------------------------------------------------------
PROC ClearScreen
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV  AH, 06h
    MOV  AL, 00h               ; scroll 0 lines = clear entire window
    MOV  BH, WHITE_ON_BLACK    ; fill attribute for blanked area
    MOV  CX, 0000h             ; top-left corner  (row 0, col 0)
    MOV  DH, 24                ; bottom-right row
    MOV  DL, 79                ; bottom-right col
    INT  10h

    MOV  AH, 02h               ; set cursor position
    MOV  BH, 0                 ; page 0
    MOV  DX, 0                 ; row 0, col 0
    INT  10h

    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
ENDP ClearScreen

;---------------------------------------------------------------------------
; SetCursorPos
; Input: DH = screen row,  DL = screen column
;---------------------------------------------------------------------------
PROC SetCursorPos
    PUSH AX
    PUSH BX

    MOV  AH, 02h
    MOV  BH, 0                 ; page 0
    INT  10h

    POP  BX
    POP  AX
    RET
ENDP SetCursorPos

;---------------------------------------------------------------------------
; DisplayColorChar
; Prints a single character with a specified colour attribute at the
; current cursor position, then advances the cursor one column to the right.
;
; Input:  AL = character to print
;         BL = colour attribute byte (e.g. WHITE_ON_BLACK, RED_ON_BLACK)
;
; Method: INT 10h / AH=09h writes char+attr without moving the cursor,
;         so we follow it with INT 10h / AH=03h (get cursor) and manually
;         increment DL, then INT 10h / AH=02h (set cursor).
;---------------------------------------------------------------------------
PROC DisplayColorChar
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV  AH, 09h               ; write character and attribute
    MOV  BH, 0                 ; page 0
    MOV  CX, 1                 ; write 1 copy
    INT  10h

    MOV  AH, 03h               ; read current cursor position into DX
    MOV  BH, 0
    INT  10h
    INC  DL                    ; advance cursor one column
    MOV  AH, 02h               ; set new cursor position
    INT  10h

    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
ENDP DisplayColorChar

;---------------------------------------------------------------------------
; PrintString
; Prints a null-terminated string at the current cursor position using
; INT 10h / AH=0Eh (TTY write, auto-advances cursor).
; Input: DS:SI = pointer to string (modified; restored on return)
;---------------------------------------------------------------------------
PROC PrintString
    PUSH AX
    PUSH BX
    PUSH SI

@@PS_loop:
    LODSB                      ; AL = next character
    CMP  AL, 0
    JE   @@PS_done             ; null terminator reached
    MOV  AH, 0Eh
    MOV  BH, 0
    INT  10h
    JMP  @@PS_loop
@@PS_done:

    POP  SI
    POP  BX
    POP  AX
    RET
ENDP PrintString

;---------------------------------------------------------------------------
; PrintTwoDigits
; Prints a value 0-99 as exactly two decimal ASCII digits at the current
; cursor position (e.g. 7 -> "07", 42 -> "42").
; Input: AL = value (0..99)
; Note: Saves units digit to CL BEFORE the first INT 10h call because
;       INT 10h corrupts AH, which would overwrite the remainder.
;---------------------------------------------------------------------------
PROC PrintTwoDigits
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV  AH, 0
    MOV  BL, 10
    DIV  BL                    ; AL = tens digit,  AH = units digit
    MOV  CL, AH                ; save units NOW before INT 10h clobbers AH
    ADD  AL, '0'               ; tens digit -> ASCII
    MOV  AH, 0Eh
    MOV  BH, 0
    INT  10h                   ; print tens

    MOV  AL, CL
    ADD  AL, '0'               ; units digit -> ASCII
    MOV  AH, 0Eh
    INT  10h                   ; print units

    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
ENDP PrintTwoDigits

;---------------------------------------------------------------------------
; PrintYear
; Prints a four-digit year (e.g. 2026) at the current cursor position.
; Input: AX = year (e.g. 2026)
; Method: divides by 100 to separate century (20) from year-within-century
;         (26), then calls PrintTwoDigits for each part.
;---------------------------------------------------------------------------
PROC PrintYear
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV  BX, 100
    MOV  DX, 0
    DIV  BX                    ; AX = century (20), DX = year-in-century (26)
    MOV  CX, DX                ; save year-in-century

    CALL PrintTwoDigits        ; print "20"
    MOV  AX, CX
    CALL PrintTwoDigits        ; print "26"

    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
ENDP PrintYear

;---------------------------------------------------------------------------
; PrintDateTime
; Prints the current system date and time in the format:
;   DayName DD Mon YYYY  HH:MM:SS
; e.g.: "Tue 07 Apr 2026  17:15:02"
;
; Uses INT 21h / AH=2Ah for date and INT 21h / AH=2Ch for time.
; Values are stored in dt_* memory variables to survive the INT calls
; and avoid register corruption across the multiple INT 10h TTY writes.
;---------------------------------------------------------------------------
PROC PrintDateTime
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    ;--- Capture date: INT 21h / AH=2Ah -----------------------------------
    MOV  AH, 2Ah
    INT  21h                   ; CX=year, DH=month(1-12), DL=day, AL=dow(0=Sun)
    MOV  [dt_dow],  AL
    MOV  [dt_day],  DL
    MOV  [dt_mon],  DH
    MOV  [dt_year], CX

    ;--- Capture time: INT 21h / AH=2Ch -----------------------------------
    MOV  AH, 2Ch
    INT  21h                   ; CH=hours, CL=minutes, DH=seconds
    MOV  [dt_hour], CH
    MOV  [dt_min],  CL
    MOV  [dt_sec],  DH

    ;--- Print 3-char day name (e.g. "Mon") --------------------------------
    MOV  BL, [dt_dow]
    MOV  BH, 0
    MOV  AL, 3
    MUL  BL                    ; AX = dow * 3 = byte offset into day_names
    LEA  SI, [day_names]
    ADD  SI, AX                ; SI -> first char of day name
    MOV  CX, 3
@@PDT_day:
    LODSB
    MOV  AH, 0Eh
    MOV  BH, 0
    INT  10h
    LOOP @@PDT_day
    MOV  AL, ' '               ; space after day name
    MOV  AH, 0Eh
    INT  10h

    ;--- Print two-digit day number (e.g. "07") ----------------------------
    MOV  AL, [dt_day]
    CALL PrintTwoDigits
    MOV  AL, ' '
    MOV  AH, 0Eh
    INT  10h

    ;--- Print 3-char month name (e.g. "Apr") ------------------------------
    MOV  BL, [dt_mon]
    DEC  BL                    ; convert 1-based month to 0-based index
    MOV  BH, 0
    MOV  AL, 3
    MUL  BL                    ; AX = (month-1) * 3
    LEA  SI, [month_names]
    ADD  SI, AX
    MOV  CX, 3
@@PDT_mon:
    LODSB
    MOV  AH, 0Eh
    MOV  BH, 0
    INT  10h
    LOOP @@PDT_mon
    MOV  AL, ' '
    MOV  AH, 0Eh
    INT  10h

    ;--- Print four-digit year (e.g. "2026") --------------------------------
    MOV  AX, [dt_year]
    CALL PrintYear
    MOV  AL, ' '               ; two spaces to separate date from time
    MOV  AH, 0Eh
    INT  10h
    MOV  AL, ' '
    MOV  AH, 0Eh
    INT  10h

    ;--- Print HH:MM:SS time -----------------------------------------------
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
