;===========================================================================
; Program  : 123tsk3.asm
; Course   : ARCHI II  -  L2 ACAD A  2025-2026  (USTHB, FI)
; Tasks    : 1 - Display original matrix  (non-digits in RED)
;            2 - Clean matrix             (replaced zeros in RED)
;            3 - Normalize matrix         (digit<5->0 , digit>=5->1)
; Tool     : GUI Turbo Assembler x64  (TASM 4.1 / TLINK)
; Mode     : MASM-compatible (works on TASM, MASM, emu8086, EMU, DOSBox)
;
; Changes from IDEAL version:
;   - Removed IDEAL directive  -> now uses standard MASM syntax
;   - .MODEL/.STACK/.DATA/.CODE simplified directives replace SEGMENT/ENDS
;   - PROC Name / ENDP Name  ->  Name PROC / Name ENDP
;   - MOV AX, _DATA          ->  MOV AX, @DATA
;   - @@local labels          ->  unique global labels (MASM has no @@ locals)
;   - [var] brackets on direct mem refs removed where MASM doesn't need them
;===========================================================================

MASM
.MODEL SMALL
.STACK 200h

;===========================================================================
; DATA SEGMENT
;===========================================================================
.DATA

    ;--- Original matrix  4 rows x 7 columns = 28 bytes -------------------
    ; Special chars as hex: 9Ch=pound  2Dh=-  26h=&  2Fh=/  2Ah=*  3Dh==
    original_matrix   DB '9','7',9Ch,'2','1',2Dh,'2'
                      DB '4','M','8','2','6','3','F'
                      DB '9','u',9Ch,'4',26h,'6','7'
                      DB '0',2Fh,'6','2',2Ah,3Dh,'8'

    cleaned_matrix    DB 28 DUP(0)   ; populated by Task2
    normalized_matrix DB 28 DUP(0)   ; populated by Task3

    ;--- Compile-time constants -------------------------------------------
    ROWS        EQU 4
    COLS        EQU 7
    TOTAL_CELLS EQU 28

    ;--- Color attributes  (INT 10h / AH=09h) -----------------------------
    WHITE_ON_BLACK EQU 07h
    RED_ON_BLACK   EQU 0Ch

    ;--- Null-terminated display strings ----------------------------------
    str_header DB 'MATRIX PREPROCESSING',0
    str_t1_sub DB '______________Step 1 :Original Matrix_____________',0
    str_t2_sub DB '__________Step 2: Matrix Data Cleaning________',0
    str_t3_sub DB '________Step 3: Matrix Data Normalization______',0

    ;--- Day name table (3 bytes per entry, 0=Sun..6=Sat) -----------------
    day_names  DB 'Sun','Mon','Tue','Wed','Thu','Fri','Sat'

    ;--- Month name table (3 bytes per entry, 0=Jan..11=Dec) --------------
    month_names DB 'Jan','Feb','Mar','Apr','May','Jun'
                DB 'Jul','Aug','Sep','Oct','Nov','Dec'

    ;--- Date/time scratch variables (written by PrintDateTime) -----------
    dt_dow  DB 0
    dt_day  DB 0
    dt_mon  DB 0
    dt_year DW 0
    dt_hour DB 0
    dt_min  DB 0
    dt_sec  DB 0


;===========================================================================
; CODE SEGMENT
;===========================================================================
.CODE

;---------------------------------------------------------------------------
; MAIN  -  entry point
;---------------------------------------------------------------------------
MAIN PROC

    MOV  AX, SEG original_matrix           ; MASM: use @DATA not segment name
    MOV  DS, AX
    MOV  ES, AX              ; ES=DS required for STOSB

    CALL Task1_DisplayOriginal

    MOV  AH, 00h
    INT  16h                 ; wait for keypress

    CALL Task2_CleanMatrix

    MOV  AH, 00h
    INT  16h

    CALL Task3_NormalizeMatrix

    MOV  AH, 00h
    INT  16h

    MOV  AH, 4Ch             ; exit to DOS
    MOV  AL, 00h
    INT  21h

MAIN ENDP

;===========================================================================
; TASK 1  -  Display original matrix
;   Digits -> WHITE  /  non-digits -> RED
;===========================================================================
Task1_DisplayOriginal PROC

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
    LEA  SI, str_t1_sub
    CALL PrintString

    MOV  DH, 4
    LEA  SI, original_matrix
    MOV  CX, ROWS

T1RowLoop:
    PUSH CX
    MOV  DL, 18
    CALL SetCursorPos
    MOV  CX, COLS

T1ColLoop:
    LODSB

    CMP  AL, '0'
    JB   T1NotDigit
    CMP  AL, '9'
    JA   T1NotDigit
    MOV  BL, WHITE_ON_BLACK
    JMP  T1Print

T1NotDigit:
    MOV  BL, RED_ON_BLACK

T1Print:
    CALL DisplayColorChar
    MOV  AL, ' '
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar

    LOOP T1ColLoop

    INC  DH
    POP  CX
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
;   Copies original_matrix -> cleaned_matrix, replacing non-digits with '0'.
;   Then displays: replaced zeros RED, kept digits WHITE.
;===========================================================================
Task2_CleanMatrix PROC

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    ;-- Step A: build cleaned_matrix --------------------------------------
    LEA  SI, original_matrix
    LEA  DI, cleaned_matrix
    MOV  CX, TOTAL_CELLS

T2CleanLoop:
    LODSB
    CMP  AL, '0'
    JB   T2Replace
    CMP  AL, '9'
    JA   T2Replace
    STOSB                    ; digit: keep
    JMP  T2Next

T2Replace:
    MOV  AL, '0'
    STOSB                    ; non-digit: store '0'

T2Next:
    LOOP T2CleanLoop

    ;-- Step B: display ---------------------------------------------------
    CALL DisplayT2Matrix

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
;   Walks original and cleaned in parallel.
;   Replaced zeros -> RED  /  original digits -> WHITE
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
    MOV  BH, ROWS

T2DispRow:
    MOV  DL, 18
    CALL SetCursorPos
    MOV  CX, COLS

T2DispCol:
    PUSH CX
    MOV  AH, [SI]            ; AH = original char
    INC  SI
    MOV  AL, [DI]            ; AL = cleaned char
    INC  DI

    CMP  AL, AH              ; same -> was digit -> white
    JE   T2White
    MOV  BL, RED_ON_BLACK
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
    DEC  BH
    JNZ  T2DispRow

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
;   Source: cleaned_matrix  /  Destination: normalized_matrix
;   digit < 5 -> '0'  /  digit >= 5 -> '1'
;===========================================================================
Task3_NormalizeMatrix PROC

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    ;-- Step A: build normalized_matrix -----------------------------------
    LEA  SI, cleaned_matrix
    LEA  DI, normalized_matrix
    MOV  CX, TOTAL_CELLS

T3NormLoop:
    LODSB
    SUB  AL, '0'             ; ASCII -> numeric 0..9
    CMP  AL, 5
    JAE  T3SetOne
    MOV  AL, '0'
    JMP  T3Store

T3SetOne:
    MOV  AL, '1'

T3Store:
    STOSB
    LOOP T3NormLoop

    ;-- Step B: display ---------------------------------------------------
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
; DisplayT3Matrix  -  displays normalized_matrix in WHITE
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
; UTILITY PROCEDURES
;===========================================================================

;---------------------------------------------------------------------------
; ClearScreen  -  blanks 80x25, homes cursor to (0,0)
;---------------------------------------------------------------------------
ClearScreen PROC

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

ClearScreen ENDP

;---------------------------------------------------------------------------
; SetCursorPos  -  Input: DH=row, DL=col
;---------------------------------------------------------------------------
SetCursorPos PROC

    PUSH AX
    PUSH BX

    MOV  AH, 02h
    MOV  BH, 0
    INT  10h

    POP  BX
    POP  AX
    RET

SetCursorPos ENDP

;---------------------------------------------------------------------------
; DisplayColorChar  -  AL=char, BL=attr, advances cursor after printing
;---------------------------------------------------------------------------
DisplayColorChar PROC

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

DisplayColorChar ENDP

;---------------------------------------------------------------------------
; PrintString  -  prints null-terminated string at DS:SI (TTY mode)
;---------------------------------------------------------------------------
PrintString PROC

    PUSH AX
    PUSH BX
    PUSH SI

PSLoop:
    LODSB
    CMP  AL, 0
    JE   PSDone
    MOV  AH, 0Eh
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
; PrintTwoDigits  -  AL=value 0-99, prints two ASCII digits
;   Saves units in CL before INT 10h corrupts AH.
;---------------------------------------------------------------------------
PrintTwoDigits PROC

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV  AH, 0
    MOV  BL, 10
    DIV  BL                  ; AL=tens, AH=units
    MOV  CL, AH              ; save units before INT 10h kills AH

    ADD  AL, '0'
    MOV  AH, 0Eh
    MOV  BH, 0
    INT  10h

    MOV  AL, CL
    ADD  AL, '0'
    MOV  AH, 0Eh
    MOV  BH, 0
    INT  10h

    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

PrintTwoDigits ENDP

;---------------------------------------------------------------------------
; PrintYear  -  AX=year (e.g. 2026), prints four digits
;---------------------------------------------------------------------------
PrintYear PROC

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV  BX, 100
    MOV  DX, 0
    DIV  BX                  ; AX=century(20), DX=yy(26)
    MOV  CX, DX              ; save yy

    CALL PrintTwoDigits      ; print "20"
    MOV  AX, CX
    CALL PrintTwoDigits      ; print "26"

    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

PrintYear ENDP

;---------------------------------------------------------------------------
; PrintDateTime  -  prints "DayName DD Mon YYYY  HH:MM:SS" at cursor
;---------------------------------------------------------------------------
PrintDateTime PROC

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    MOV  AH, 2Ah             ; get date
    INT  21h
    MOV  dt_dow,  AL
    MOV  dt_day,  DL
    MOV  dt_mon,  DH
    MOV  dt_year, CX

    MOV  AH, 2Ch             ; get time
    INT  21h
    MOV  dt_hour, CH
    MOV  dt_min,  CL
    MOV  dt_sec,  DH

    ;-- day name ----------------------------------------------------------
    MOV  BL, dt_dow
    MOV  BH, 0
    MOV  AL, 3
    MUL  BL
    LEA  SI, day_names
    ADD  SI, AX
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

    ;-- day number --------------------------------------------------------
    MOV  AL, dt_day
    CALL PrintTwoDigits
    MOV  AL, ' '
    MOV  AH, 0Eh
    INT  10h

    ;-- month name --------------------------------------------------------
    MOV  BL, dt_mon
    DEC  BL
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

    ;-- year --------------------------------------------------------------
    MOV  AX, dt_year
    CALL PrintYear
    MOV  AL, ' '
    MOV  AH, 0Eh
    INT  10h
    MOV  AL, ' '
    MOV  AH, 0Eh
    INT  10h

    ;-- HH:MM:SS ----------------------------------------------------------
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

END MAIN
