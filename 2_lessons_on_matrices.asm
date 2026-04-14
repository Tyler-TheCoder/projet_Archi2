;===========================================================================
; Program  : 2_lessons_on_matrices.asm  (Tasks 1, 2, 3)
; Course   : ARCHI II  -  L2 ACAD A  2025-2026  (USTHB, FI)
;
; What this program does:
;   Task 1 - shows the original matrix, non-digit chars highlighted in red
;   Task 2 - cleans the matrix by replacing non-digits with '0' (red)
;   Task 3 - normalizes the matrix: digits < 5 become 0, digits >= 5 become 1
;
; Each task waits for a keypress before moving to the next one.
;===========================================================================

.MODEL SMALL        ; one code segment + one data segment (standard for DOS)
.STACK 200h         ; reserve 512 bytes for the stack

;===========================================================================
; DATA SEGMENT  -  all variables and constants live here
;===========================================================================
.DATA 

    ; The matrix is stored row by row in memory (4 rows x 7 cols = 28 bytes).
    ; Some cells are non-digit characters on purpose (letters, symbols).
    ; We write special chars as hex to avoid encoding issues in the editor:
    ;   9Ch = ??    2Dh = -    26h = &    2Fh = /    2Ah = *    3Dh = =
    original_matrix   DB '9',40h,9Ch,'2','1',2Dh,'2'   ; row 0
                      DB '4','M','8','3','6','9','F'    ; row 1
                      DB '4','u',9Ch,'4',26h,40h,'7'   ; row 2
                      DB '1',2Fh,'6','2',2Ah,3Dh,'8'  ; row 3

    cleaned_matrix    DB 28 DUP(0)   ; filled by Task 2 (non-digits -> '0')
    normalized_matrix DB 28 DUP(0)   ; filled by Task 3 (values -> '0'/'1')
    reflected_matrix  DB 28 DUP(0)   ; filled by Task 6 (flip horizontal)
    vert_reflected_matrix  DB 28 DUP(0)  ; filled by Task 7 (flip vertical)


    ; These are compile-time constants, not memory variables.
    ; EQU just tells the assembler to substitute the value wherever the name appears.
    ROWS        EQU 4
    COLS        EQU 7
    TOTAL_CELLS EQU 28   ; 4 * 7, written as a literal to avoid a TASM bug
                         ; with expressions like ROWS * COLS inside MOV
    col_sums        DB 7 DUP(0)

    ; Color byte format for INT 10h: high nibble = background, low = foreground
    ; 0 = black background, 7 = white text, C = bright red text
    WHITE_ON_BLACK EQU 07h
    RED_ON_BLACK   EQU 0Ch
    GREEN_ON_BLACK EQU 0Ah
    YELLOW_ON_BLACK EQU 0Eh

    ; Null-terminated strings (the 0 at the end tells PrintString to stop)
    str_header DB 'MATRIX PREPROCESSING',0
    str_process DB 'MATRIX PROCESSING',0
    str_t1_sub DB '__Step 1 :Original Matrix_____________',0
    str_t2_sub DB '__Step 2 : Matrix Data Cleaning________',0
    str_t3_sub DB '__Step 3 : Matrix Data Normalization______',0
    str_t4_sub DB '__Step 4 : Matrix Reduction on Rows______',0
    str_t5_sub DB '__Step 5 : Matrix Reduction on Rows and Columns_',0
    str_t6_sub DB '__Step 6 : Horizontal Reflexion of the Matrix_____',0
    str_t7_sub DB '__Step 7 : Vertical Reflexion of the Matrix___',0

    ; Day and month name tables for the date display.
    ; Each entry is exactly 3 bytes, so to get entry N we just do: base + N*3
    day_names   DB 'Sun','Mon','Tue','Wed','Thu','Fri','Sat'
    month_names DB 'Jan','Feb','Mar','Apr','May','Jun'
                DB 'Jul','Aug','Sep','Oct','Nov','Dec'

    ; PrintDateTime reads the system date/time into these variables first,
    ; then prints from them. This avoids register corruption between INT calls.
    dt_dow  DB 0   ; day of week  (0=Sunday .. 6=Saturday)
    dt_day  DB 0   ; day of month (1-31)
    dt_mon  DB 0   ; month        (1-12)
    dt_year DW 0   ; full year    (e.g. 2026) - needs a word, not a byte
    dt_hour DB 0
    dt_min  DB 0
    dt_sec  DB 0

    ; this section is for the wait30sec 
    tick_counter  DW 546      ; 91 = 5sec  , 546 = 30sec  . for tests
    old_1ch_off   DW 0
    old_1ch_seg   DW 0


    ; this section is for the supplement segment 
    total_sum     DB 0
    str_ext_title DB 'EXTENSION : Conditional Task Execution',0
    str_sum_label DB 'Total matrix sum = ',0
    str_ext_run   DB 'Sum >= 10 : Running Tasks 6 and 7 again...',0
    str_ext_skip  DB 'Sum < 10  : Tasks 6 and 7 skipped.',0

;===========================================================================
; CODE SEGMENT  -  all procedures go here
;===========================================================================
.CODE 

;---------------------------------------------------------------------------
; MAIN
;---------------------------------------------------------------------------
MAIN PROC

    ; Point DS and ES to our data segment.
    ; We can't write  MOV DS, immediate  directly (8086 rule),
    ; so we go through AX as a middleman.
    ; SEG original_matrix gives the segment address where our data lives.
    MOV  AX, SEG original_matrix
    MOV  DS, AX
    MOV  ES, AX   ; ES must also point to data because STOSB writes to ES:DI

    MOV CX,2
lesson1Loop:
    PUSH CX                 ; the interruption function will use cx , so to prevent the loss of it 
                            ; we need to store it in the stack in each loop
    CALL Task1_DisplayOriginal
    CALL Wait30Sec

    CALL Task2_CleanMatrix
    CALL Wait30Sec

    CALL Task3_NormalizeMatrix
    CALL Wait30Sec

    CALL Task4_RowReduction      
    CALL Wait30Sec

    CALL Task5_ColReduction
    CALL Wait30Sec

    POP CX
    LOOP lesson1Loop

    MOV CX, 3
lesson2Loop:
    PUSH CX

    CALL Task6_HorizReflect
    CALL Wait30Sec

    CALL Task7_VertReflect
    CALL Wait30Sec

    POP CX
    LOOP lesson2Loop

    ; the supplement task
    CALL ComputeTotalSum
    CALL RunExtension

    MOV  AH, 4Ch  ; DOS function: terminate program
    MOV  AL, 00h  ; exit code 0 (no error)
    INT  21h

MAIN ENDP



;===========================================================================
; Wait30Sec  -  waits approximately 30 seconds using INT 1Ch
;
; How it works:
;   INT 1Ch is a software interrupt that the BIOS timer fires automatically
;   18.2 times per second (every ~55ms). By default it does nothing, so we
;   can safely hijack it for our own timing.
;
;   18.2 ticks/sec x 30 sec = 546 ticks = 30 seconds
;
;   The procedure:
;     1. Saves the original INT 1Ch vector (whatever was there before us)
;     2. Installs our own handler TIMER_TICK as the new INT 1Ch handler
;     3. Sets tick_counter to 546
;     4. Sits in an empty loop doing nothing until tick_counter reaches 0
;        (TIMER_TICK decrements it on every tick)
;     5. Restores the original INT 1Ch vector and returns
;
; Usage in MAIN  (replace every  MOV AH,00h / INT 16h  with this):
;
;     CALL Task1_DisplayOriginal
;     CALL Wait30Sec
;
;     CALL Task2_CleanMatrix
;     CALL Wait30Sec
;     ... and so on
;
; Data to add in .DATA:
;     tick_counter  DW 546
;     old_1ch_off   DW 0
;     old_1ch_seg   DW 0
;===========================================================================

;---------------------------------------------------------------------------
; TIMER_TICK  -  the INT 1Ch handler
;
; Called automatically by the BIOS ~18.2 times per second.
; All it does is decrement tick_counter.
; IRET is mandatory at the end of any interrupt handler -- it restores
; the flags register in addition to CS:IP, which a normal RET does not.
;
; IMPORTANT: this procedure must be defined BEFORE Wait30Sec in the source
; file so that OFFSET TIMER_TICK resolves correctly at assembly time.
;---------------------------------------------------------------------------
TIMER_TICK PROC

    PUSH AX
    PUSH DS

    ; The handler runs with whatever DS the interrupted code had,
    ; so we must reload DS ourselves to access our own variables.
    MOV  AX, SEG tick_counter
    MOV  DS, AX

    DEC  tick_counter          ; one tick closer to zero

    POP  DS
    POP  AX
    IRET                       ; return from interrupt (restores CS:IP + FLAGS)

TIMER_TICK ENDP

;---------------------------------------------------------------------------
; Wait30Sec  -  waits ~30 seconds then returns
; All registers preserved.
;---------------------------------------------------------------------------
Wait30Sec PROC

    PUSH AX
    PUSH BX
    PUSH DX
    PUSH DS
    PUSH ES

    ; --- reset the counter to 546 before each wait ---
    ; (so every call waits a fresh 30 seconds)
    MOV  tick_counter, 546          ; old value is 546 = 30 sec  

    ; --- save the current INT 1Ch vector (INT 21h / AH=35h) ---
    ; Returns: ES = segment of current handler, BX = offset
    MOV  AH, 35h
    MOV  AL, 1Ch
    INT  21h
    MOV  old_1ch_off, BX
    MOV  old_1ch_seg, ES

    ; restore ES to our data segment (INT 21h changed it)
    MOV  AX, SEG tick_counter
    MOV  ES, AX

    ; --- install TIMER_TICK as the new INT 1Ch handler (INT 21h / AH=25h) ---
    ; DS:DX must point to the new handler.
    ; TIMER_TICK is in the code segment, so we temporarily point DS to CS.
    PUSH DS
    MOV  AX, CS
    MOV  DS, AX
    MOV  DX, OFFSET TIMER_TICK
    MOV  AH, 25h
    MOV  AL, 1Ch
    INT  21h
    POP  DS                    ; restore DS back to our data segment

    ; --- wait loop: do nothing until TIMER_TICK counts down to 0 ---
WaitLoop:
    CMP  tick_counter, 0
    JG   WaitLoop              ; JG = jump if greater than zero (signed)

    ; --- restore the original INT 1Ch vector ---
    ; DS must point to the segment of the old handler for INT 25h
    MOV  DX, old_1ch_off
    MOV  AX, old_1ch_seg
    PUSH DS
    MOV  DS, AX
    MOV  AH, 25h
    MOV  AL, 1Ch
    INT  21h
    POP  DS

    POP  ES
    POP  DS
    POP  DX
    POP  BX
    POP  AX
    RET

Wait30Sec ENDP




;===========================================================================
; TASK 1  -  Display original matrix
;   Loops over every cell. Digits get printed in white, everything else red.
;===========================================================================
Task1_DisplayOriginal PROC

    ; Save all registers we use so the caller gets them back unchanged
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    CALL ClearScreen

    ; Print date/time on row 0, title on row 1, subtitle on row 2
    MOV  DH, 0
    MOV  DL, 1
    CALL SetCursorPos
    CALL PrintDateTime

    MOV  DH, 1
    MOV  DL, 10
    CALL SetCursorPos
    LEA  SI, str_header   ; LEA loads the ADDRESS of str_header into SI
    CALL PrintString      ; (not the value at that address)

    MOV  DH, 2
    MOV  DL, 5
    CALL SetCursorPos
    LEA  SI, str_t1_sub
    CALL PrintString

    ; Start printing the matrix at screen row 4
    MOV  DH, 4
    LEA  SI, original_matrix   ; SI now points to the first byte of the matrix
    MOV  CX, ROWS              ; outer loop counter = 4 rows

T1RowLoop:
    PUSH CX          ; save row counter because the inner loop overwrites CX
    MOV  DL, 18      ; start each row at column 18 (roughly centered)
    CALL SetCursorPos
    MOV  CX, COLS    ; inner loop counter = 7 columns

T1ColLoop:
    LODSB   ; loads byte at DS:SI into AL, then increments SI automatically
            ; so each call reads the next cell of the matrix

    ; Check if AL is between '0' (ASCII 48) and '9' (ASCII 57)
    CMP  AL, '0'
    JB   T1NotDigit   ; JB = jump if below (unsigned less-than)
    CMP  AL, '9'
    JA   T1NotDigit   ; JA = jump if above (unsigned greater-than)
    MOV  BL, WHITE_ON_BLACK
    JMP  T1Print

T1NotDigit:
    MOV  BL, RED_ON_BLACK

T1Print:
    CALL DisplayColorChar   ; prints AL with color BL, then moves cursor right
    MOV  AL, ' '
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar   ; print a space to separate cells visually

    LOOP T1ColLoop   ; decrements CX, jumps back if CX != 0

    INC  DH    ; move down to the next screen row
    POP  CX    ; restore the row counter we saved at the top
    LOOP T1RowLoop

    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

Task1_DisplayOriginal ENDP

;===========================================================================
; TASK 2  -  Clean matrix
;   First pass: copy original -> cleaned, replacing non-digits with '0'.
;   Second pass: display the cleaned matrix (via DisplayT2Matrix).
;===========================================================================
Task2_CleanMatrix PROC

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    ; Set SI to read from original_matrix, DI to write to cleaned_matrix
    LEA  SI, original_matrix
    LEA  DI, cleaned_matrix
    MOV  CX, TOTAL_CELLS   ; we process all 28 cells in one flat loop

T2CleanLoop:
    LODSB          ; AL = next byte from original_matrix, SI++
    CMP  AL, '0'
    JB   T2Replace
    CMP  AL, '9'
    JA   T2Replace
    STOSB          ; STOSB stores AL into ES:DI, then increments DI
                   ; digit is fine, keep it as-is
    JMP  T2Next

T2Replace:
    MOV  AL, '0'
    STOSB          ; overwrite the non-digit with character '0'

T2Next:
    LOOP T2CleanLoop

    CALL DisplayT2Matrix   ; show the result on screen

    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

Task2_CleanMatrix ENDP

;---------------------------------------------------------------------------
; DisplayT2Matrix
;   Walks original_matrix and cleaned_matrix side by side.
;   If a cell changed (original != cleaned), it was replaced -> print RED.
;   If it stayed the same, it was already a digit -> print WHITE.
;---------------------------------------------------------------------------
DisplayT2Matrix PROC

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
    LEA  SI, str_header
    CALL PrintString

    MOV  DH, 2
    MOV  DL, 5
    CALL SetCursorPos
    LEA  SI, str_t2_sub
    CALL PrintString

    MOV  DH, 4
    LEA  SI, original_matrix
    LEA  DI, cleaned_matrix
    ; We use BH as the outer row counter instead of CX
    ; because the inner LOOP instruction needs CX for itself
    MOV  BH, ROWS

T2DispRow:
    MOV  DL, 18
    CALL SetCursorPos
    MOV  CX, COLS

T2DispCol:
    PUSH CX            ; protect CX from being changed by CALL instructions
    MOV  AH, [SI]      ; read original char into AH
    INC  SI
    MOV  AL, [DI]      ; read cleaned char into AL
    INC  DI

    ; If original == cleaned, the cell was already a digit, no change needed
    CMP  AL, AH
    JE   T2White
    MOV  BL, RED_ON_BLACK    ; they differ, meaning this '0' was substituted
    JMP  T2Print

T2White:
    MOV  BL, WHITE_ON_BLACK

T2Print:
    CALL DisplayColorChar
    MOV  AL, ' '
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar
    POP  CX
    LOOP T2DispCol

    INC  DH
    DEC  BH        ; manually decrement our outer row counter
    JNZ  T2DispRow ; JNZ = jump if not zero (BH still has rows left)

    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

DisplayT2Matrix ENDP

;===========================================================================
; TASK 3  -  Normalize matrix
;   Reads from cleaned_matrix, writes to normalized_matrix.
;   Rule: digit value < 5 -> store '0',  digit value >= 5 -> store '1'
;===========================================================================
Task3_NormalizeMatrix PROC

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    LEA  SI, cleaned_matrix
    LEA  DI, normalized_matrix
    MOV  CX, TOTAL_CELLS

T3NormLoop:
    LODSB              ; AL = next ASCII digit from cleaned_matrix
    SUB  AL, '0'       ; convert ASCII to numeric: '0'->0, '5'->5, '9'->9
    CMP  AL, 5
    JAE  T3SetOne      ; JAE = jump if above or equal (i.e. value >= 5)
    MOV  AL, '0'       ; value was 0-4, store ASCII '0'
    JMP  T3Store

T3SetOne:
    MOV  AL, '1'       ; value was 5-9, store ASCII '1'

T3Store:
    STOSB              ; write AL to normalized_matrix at ES:DI, DI++
    LOOP T3NormLoop

    CALL DisplayT3Matrix

    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

Task3_NormalizeMatrix ENDP

;---------------------------------------------------------------------------
; DisplayT3Matrix  -  shows normalized_matrix, all cells in white
;---------------------------------------------------------------------------
DisplayT3Matrix PROC

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
    LEA  SI, str_header
    CALL PrintString

    MOV  DH, 2
    MOV  DL, 5
    CALL SetCursorPos
    LEA  SI, str_t3_sub
    CALL PrintString

    MOV  DH, 4
    LEA  SI, normalized_matrix
    MOV  BH, ROWS

T3DispRow:
    MOV  DL, 18
    CALL SetCursorPos
    MOV  CX, COLS

T3DispCol:
    LODSB
    PUSH CX
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar
    MOV  AL, ' '
    CALL DisplayColorChar
    POP  CX
    LOOP T3DispCol

    INC  DH
    DEC  BH
    JNZ  T3DispRow

    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

DisplayT3Matrix ENDP



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
;   sum in GREEN. Does NOT clear the screen or print the header ??? the caller
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

    ; DH is passed in by the caller
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




;===========================================================================
; UTILITY PROCEDURES
;===========================================================================

;---------------------------------------------------------------------------
; ClearScreen
;   INT 10h / AH=06h scrolls a region of the screen upward.
;   When AL=0 (scroll 0 lines), it clears the entire region instead.
;   We use it to blank the whole 80x25 screen, then home the cursor.
;---------------------------------------------------------------------------
ClearScreen PROC

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV  AH, 06h         ; BIOS video: scroll window up
    MOV  AL, 00h         ; 0 lines = clear the whole window
    MOV  BH, WHITE_ON_BLACK  ; fill cleared area with this attribute
    MOV  CX, 0000h       ; top-left corner: row 0, col 0
    MOV  DH, 24          ; bottom-right row
    MOV  DL, 79          ; bottom-right col
    INT  10h

    MOV  AH, 02h         ; BIOS video: set cursor position
    MOV  BH, 0           ; page 0
    MOV  DX, 0           ; DH=row 0, DL=col 0
    INT  10h

    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

ClearScreen ENDP

;---------------------------------------------------------------------------
; SetCursorPos
;   Input: DH = row (0-24),  DL = column (0-79)
;---------------------------------------------------------------------------
SetCursorPos PROC

    PUSH AX
    PUSH BX

    MOV  AH, 02h   ; BIOS: set cursor position
    MOV  BH, 0     ; video page 0
    INT  10h       ; DH:DL already set by caller

    POP  BX
    POP  AX
    RET

SetCursorPos ENDP

;---------------------------------------------------------------------------
; DisplayColorChar
;   Prints one character at the current cursor position with a given color,
;   then manually moves the cursor one step to the right.
;
;   Input: AL = character to print,  BL = color attribute
;
;   Note: INT 10h / AH=09h writes the char+color but does NOT move the
;   cursor, so we have to do that ourselves with a get+increment+set sequence.
;---------------------------------------------------------------------------
DisplayColorChar PROC

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV  AH, 09h   ; BIOS: write character and attribute at cursor
    MOV  BH, 0     ; page 0
    MOV  CX, 1     ; print it once
    INT  10h       ; cursor stays in place after this

    MOV  AH, 03h   ; BIOS: get current cursor position -> returned in DH:DL
    MOV  BH, 0
    INT  10h
    INC  DL        ; move one column to the right
    MOV  AH, 02h   ; BIOS: set cursor to the new position
    INT  10h

    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

DisplayColorChar ENDP

;---------------------------------------------------------------------------
; PrintString
;   Prints a null-terminated string. SI must point to the first character.
;   Reads one byte at a time until it hits the 0 terminator.
;---------------------------------------------------------------------------
PrintString PROC

    PUSH AX
    PUSH BX
    PUSH SI

PSLoop:
    LODSB            ; AL = next char, SI++
    CMP  AL, 0       ; is it the null terminator?
    JE   PSDone
    MOV  AH, 0Eh     ; BIOS TTY output: prints AL and advances cursor
    MOV  BH, 0
    INT  10h
    JMP  PSLoop

PSDone:
    POP  SI
    POP  BX
    POP  AX
    RET

PrintString ENDP

;---------------------------------------------------------------------------
; PrintTwoDigits
;   Prints a value 0-99 as exactly two decimal digits (e.g. 7 -> "07").
;   Input: AL = value
;
;   DIV BL divides AX by BL.  Result: AL = quotient,  AH = remainder.
;   So  37 / 10  gives  AL=3 (tens),  AH=7 (units).
;
;   Important: we save AH into CL BEFORE calling INT 10h, because INT 10h
;   uses AH for its own function code and would overwrite our units digit.
;---------------------------------------------------------------------------
PrintTwoDigits PROC

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV  AH, 0     ; clear AH so the division is  AX / BL  not garbage
    MOV  BL, 10
    DIV  BL        ; AL = tens digit,  AH = units digit
    MOV  CL, AH    ; save units in CL now, before INT 10h destroys AH

    ADD  AL, '0'   ; convert numeric digit to its ASCII character
    MOV  AH, 0Eh
    MOV  BH, 0
    INT  10h       ; print tens digit  (AH is now clobbered, that's fine)

    MOV  AL, CL    ; recover units from CL
    ADD  AL, '0'
    MOV  AH, 0Eh
    MOV  BH, 0
    INT  10h       ; print units digit

    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

PrintTwoDigits ENDP

;---------------------------------------------------------------------------
; PrintYear
;   Prints a 16-bit year (e.g. 2026) as four digits.
;   Input: AX = year
;
;   Strategy: split into two 2-digit parts.
;   2026 / 100 = 20 remainder 26  ->  print "20" then "26"
;
;   DIV BX divides DX:AX by BX.  Result: AX = quotient,  DX = remainder.
;   We zero DX first so there's no garbage in the high part of the dividend.
;---------------------------------------------------------------------------
PrintYear PROC

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV  BX, 100
    MOV  DX, 0     ; DX:AX is the dividend; clear DX so it doesn't interfere
    DIV  BX        ; AX = century part (20),  DX = year-in-century (26)
    MOV  CX, DX    ; save the remainder before PrintTwoDigits overwrites DX

    CALL PrintTwoDigits   ; prints the century ("20")
    MOV  AX, CX
    CALL PrintTwoDigits   ; prints the year-in-century ("26")

    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

PrintYear ENDP

;---------------------------------------------------------------------------
; PrintDateTime
;   Reads the system date and time from DOS, then prints:
;       DayName  DD Mon YYYY  HH:MM:SS
;
;   We store everything into the dt_* variables right after the INT calls,
;   because subsequent INT calls would overwrite the registers.
;
;   INT 21h / AH=2Ah  returns: CX=year, DH=month, DL=day, AL=day-of-week
;   INT 21h / AH=2Ch  returns: CH=hour, CL=minute, DH=second
;---------------------------------------------------------------------------
PrintDateTime PROC

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    MOV  AH, 2Ah
    INT  21h
    MOV  dt_dow,  AL   ; save before the next INT call overwrites everything
    MOV  dt_day,  DL
    MOV  dt_mon,  DH
    MOV  dt_year, CX

    MOV  AH, 2Ch
    INT  21h
    MOV  dt_hour, CH
    MOV  dt_min,  CL
    MOV  dt_sec,  DH

    ; --- print day name (e.g. "Mon") ---
    ; day_names has 7 entries of 3 bytes each.
    ; To get entry N: SI = base + N*3
    MOV  BL, dt_dow
    MOV  BH, 0
    MOV  AL, 3
    MUL  BL            ; AX = dt_dow * 3  (byte offset into the table)
    LEA  SI, day_names
    ADD  SI, AX        ; SI now points to the right 3-char entry
    MOV  CX, 3
PDDayLoop:
    LODSB
    MOV  AH, 0Eh
    MOV  BH, 0
    INT  10h
    LOOP PDDayLoop

    MOV  AL, ' '
    MOV  AH, 0Eh
    INT  10h

    ; --- print day number ---
    MOV  AL, dt_day
    CALL PrintTwoDigits
    MOV  AL, ' '
    MOV  AH, 0Eh
    INT  10h

    ; --- print month name (same table-lookup trick as day name) ---
    MOV  BL, dt_mon
    DEC  BL            ; month is 1-based, table is 0-based, so subtract 1
    MOV  BH, 0
    MOV  AL, 3
    MUL  BL
    LEA  SI, month_names
    ADD  SI, AX
    MOV  CX, 3
PDMonLoop:
    LODSB
    MOV  AH, 0Eh
    MOV  BH, 0
    INT  10h
    LOOP PDMonLoop

    MOV  AL, ' '
    MOV  AH, 0Eh
    INT  10h

    ; --- print year (4 digits) ---
    MOV  AX, dt_year
    CALL PrintYear

    ; two spaces between date and time
    MOV  AL, ' '
    MOV  AH, 0Eh
    INT  10h
    MOV  AL, ' '
    MOV  AH, 0Eh
    INT  10h

    ; --- print HH:MM:SS ---
    MOV  AL, dt_hour
    CALL PrintTwoDigits
    MOV  AL, ':'
    MOV  AH, 0Eh
    INT  10h
    MOV  AL, dt_min
    CALL PrintTwoDigits
    MOV  AL, ':'
    MOV  AH, 0Eh
    INT  10h
    MOV  AL, dt_sec
    CALL PrintTwoDigits

    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

PrintDateTime ENDP


;===========================================================================================
;           THE ADDITIONAL TASK 
;===========================================================================================

;---------------------------------------------------------------------------
; ComputeTotalSum
;   Sums all 28 cells of normalized_matrix ('0'/'1') into total_sum.
;   Since each cell is ASCII '0' or '1', we subtract '0' to get 0 or 1.
;   All registers preserved.
;---------------------------------------------------------------------------
ComputeTotalSum PROC

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

ComputeTotalSum ENDP

;---------------------------------------------------------------------------
; RunExtension
;   Checks total_sum. If >= 10, runs Task 6 + Task 7 with 30sec waits.
;   Displays a message either way so the user knows what happened.
;   All registers preserved.
;---------------------------------------------------------------------------
RunExtension PROC

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

RunExtension ENDP


END MAIN
