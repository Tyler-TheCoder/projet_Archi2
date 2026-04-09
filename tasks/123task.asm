SEGMENT .DATA

    ;-----------------------------------------------------------------------
    ; Original matrix  4 rows x 7 columns = 28 bytes
    ; Mix of digits and non-digit characters / symbols
    ; Special chars given as hex literals for safe TASM parsing:
    ;   9Ch = ??    2Dh = -    26h = &    2Fh = /    2Ah = *    3Dh = =
    ;-----------------------------------------------------------------------
    original_matrix   DB '9','7',9Ch,'2','1',2Dh,'2'
                      DB '4','M','8','2','6','3','F'
                      DB '9','u',9Ch,'4',26h,'6','7'
                      DB '0',2Fh,'6','2',2Ah,3Dh,'8'

    cleaned_matrix    DB 28 DUP(0)    ; populated by Task2
    normalized_matrix DB 28 DUP(0)   ; populated by Task3

    ;--- Compile-time constants (EQU is safe; avoids expression-in-MOV) ---
    ROWS        EQU 4
    COLS        EQU 7
    TOTAL_CELLS EQU 28       ; = ROWS * COLS  (literal avoids TASM bug)

    ;--- Video color attributes for INT 10h / AH=09h ----------------------
    WHITE_ON_BLACK EQU 07h
    RED_ON_BLACK   EQU 0Ch

    ;--- Null-terminated strings for screen headers -----------------------
    str_header DB 'MATRIX PREPROCESSING',0
    str_t1_sub DB '______________Step 1 :Original Matrix_____________',0
    str_t2_sub DB '__________Step 2: Matrix Data Cleaning________',0
    str_t3_sub DB '________Step 3: Matrix Data Normalization______',0

    ;--- Day name table  (3 bytes per entry, 0=Sun .. 6=Sat) --------------
    day_names  DB 'Sun','Mon','Tue','Wed','Thu','Fri','Sat'

    ;--- Month name table (3 bytes per entry, index 0=Jan .. 11=Dec) ------
    month_names DB 'Jan','Feb','Mar','Apr','May','Jun'
                DB 'Jul','Aug','Sep','Oct','Nov','Dec'

    ;--- Date/time scratch variables written by PrintDateTime -------------
    dt_dow  DB 0        ; day of week   0-6   (0=Sunday)
    dt_day  DB 0        ; day           1-31
    dt_mon  DB 0        ; month         1-12
    dt_year DW 0        ; year          e.g. 2026
    dt_hour DB 0        ; hour          0-23
    dt_min  DB 0        ; minute        0-59
    dt_sec  DB 0        ; second        0-59

ENDS .DATA

SEGMENT .CODE 

    ASSUME CS:.CODE, DS:.DATA


;=======================================================================
; MAIN PROGRAM
    
    CALL Task1_DisplayOriginal

    MOV  AH, 00h             ; wait for keypress (testing convenience)
    INT  16h

    CALL Task2_CleanMatrix

    MOV  AH, 00h
    INT  16h

    CALL Task3_NormalizeMatrix

    MOV  AH, 00h
    INT  16h

    MOV  AH, 4Ch             ; terminate program (DOS exit)
    MOV  AL, 00h
    INT  21h


;===========================================================================
; TASK 1  -  Display original matrix
;   Digits     -> printed in WHITE
;   Non-digits -> printed in RED
;===========================================================================
PROC Task1_DisplayOriginal

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    CALL ClearScreen

    ;-- row 0: date and time --
    MOV  DH, 0
    MOV  DL, 1
    CALL SetCursorPos
    CALL PrintDateTime

    ;-- row 1: title --
    MOV  DH, 1
    MOV  DL, 10
    CALL SetCursorPos
    LEA  SI, [str_header]
    CALL PrintString

    ;-- row 2: subtitle --
    MOV  DH, 2
    MOV  DL, 5
    CALL SetCursorPos
    LEA  SI, [str_t1_sub]
    CALL PrintString

    ;-- rows 4+: matrix body --
    MOV  DH, 4
    LEA  SI, [original_matrix]
    MOV  CX, ROWS

@T1RowLoop:
    PUSH CX
    MOV  DL, 18
    CALL SetCursorPos
    MOV  CX, COLS

@T1ColLoop:
    LODSB                    ; AL = current matrix byte, SI advances

    CMP  AL, '0'
    JB   @T1NotDigit
    CMP  AL, '9'
    JA   @T1NotDigit
    MOV  BL, WHITE_ON_BLACK
    JMP  @T1Print

@T1NotDigit:
    MOV  BL, RED_ON_BLACK

@T1Print:
    CALL DisplayColorChar    ; prints AL with attribute BL, advances cursor
    MOV  AL, ' '
    MOV  BL, WHITE_ON_BLACK
    CALL DisplayColorChar    ; space separator between elements

    LOOP @T1ColLoop

    INC  DH                  ; move down one screen row
    POP  CX
    LOOP @T1RowLoop

    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

ENDP Task1_DisplayOriginal


;===========================================================================
; TASK 2  -  Clean matrix
;   Non-digit characters replaced by ASCII '0'
;   Replaced cells shown in RED, unchanged digits in WHITE
;===========================================================================
PROC Task2_CleanMatrix

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    ; copy original , replace non-digits with '0' 
    LEA  SI, [original_matrix]
    LEA  DI, [cleaned_matrix]
    MOV  CX, TOTAL_CELLS

@T2CleanLoop:
    LODSB                    ; load single byte from original matrix , ( AL = DS:SI )
    CMP  AL, '0'
    JB   @T2Replace          ; if al < 0  => not a digit
    CMP  AL, '9'
    JA   @T2Replace          ; if al > 9  => not a digit
        
        ; this section handles digits
    STOSB                    ; store single byte to the cleaned matrix .   
    JMP  @T2Next
        
        ; this label handles non digits (replace characters with '0')
@T2Replace:
    MOV  AL, '0'
    STOSB                    ; not a digit: store '0'

@T2Next:
    LOOP @T2CleanLoop


    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

ENDP Task2_CleanMatrix


  ; display procedure for task 2


PROC DisplayT2Matrix

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
    LEA  SI, [str_2_sub]
    CALL PrintString

    MOV  DH, 4
    LEA  SI, [cleaned_matrix]    
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



;===========================================================================
; UTILITY PROCEDURES
;===========================================================================

;---------------------------------------------------------------------------
; ClearScreen
;   Clears the full 80x25 screen via INT 10h / AH=06h (scroll-up, 0 lines).
;   Homes cursor to (0,0) afterwards.
;   No inputs.  All registers preserved.
;---------------------------------------------------------------------------
PROC ClearScreen

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV  AH, 06h
    MOV  AL, 00h             ; 0 lines = blank whole window
    MOV  BH, WHITE_ON_BLACK  ; fill attribute
    MOV  CX, 0000h           ; top-left corner (row=0, col=0)
    MOV  DH, 24              ; bottom-right row
    MOV  DL, 79              ; bottom-right col
    INT  10h

    MOV  AH, 02h             ; position cursor at (0,0)
    MOV  BH, 0
    MOV  DX, 0
    INT  10h

    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

ENDP ClearScreen

;---------------------------------------------------------------------------
; SetCursorPos
;   Positions the cursor at a given row and column.
;   Input:  DH = row (0-24),   DL = column (0-79)
;   All registers preserved.
;---------------------------------------------------------------------------
PROC SetCursorPos

    PUSH AX
    PUSH BX

    MOV  AH, 02h
    MOV  BH, 0               ; video page 0
    INT  10h

    POP  BX
    POP  AX
    RET

ENDP SetCursorPos

;---------------------------------------------------------------------------
; DisplayColorChar
;   Writes one character with a color attribute at the current cursor,
;   then moves the cursor one column to the right.
;   Input:  AL = ASCII character to print
;           BL = color attribute  (e.g. 07h=white, 0Ch=red)
;   All registers preserved.
;---------------------------------------------------------------------------
PROC DisplayColorChar

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV  AH, 09h             ; write character + attribute
    MOV  BH, 0               ; page 0
    MOV  CX, 1               ; print exactly 1 copy
    INT  10h                 ; cursor does NOT advance after INT 09h

    MOV  AH, 03h             ; get cursor position -> DH:DL
    MOV  BH, 0
    INT  10h
    INC  DL                  ; advance one column
    MOV  AH, 02h
    INT  10h                 ; set new cursor position

    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

ENDP DisplayColorChar

;---------------------------------------------------------------------------
; PrintString
;   Prints a null-terminated string pointed to by SI using TTY output.
;   Input:  SI = near offset of string in _DATA
;   All registers preserved.
;---------------------------------------------------------------------------
PROC PrintString

    PUSH AX
    PUSH BX
    PUSH SI

@PSLoop:
    LODSB                    ; AL = next character
    CMP  AL, 0
    JE   @PSDone
    MOV  AH, 0Eh             ; TTY write (auto-advances cursor)
    MOV  BH, 0
    INT  10h
    JMP  @PSLoop

@PSDone:
    POP  SI
    POP  BX
    POP  AX
    RET

ENDP PrintString

;---------------------------------------------------------------------------
; PrintTwoDigits
;   Prints a byte value (0-99) as exactly two decimal ASCII digits.
;   Input:  AL = value (0..99)
;   Key fix: units digit saved in CL BEFORE INT 10h, because INT 10h
;            modifies AH, which would corrupt the remainder from DIV.
;   All registers preserved.
;---------------------------------------------------------------------------
PROC PrintTwoDigits

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV  AH, 0
    MOV  BL, 10
    DIV  BL                  ; AL = tens digit,  AH = units digit
    MOV  CL, AH              ; save units in CL BEFORE INT 10h corrupts AH

    ADD  AL, '0'             ; tens -> ASCII
    MOV  AH, 0Eh
    MOV  BH, 0
    INT  10h                 ; print tens  (AH is now clobbered - that's ok)

    MOV  AL, CL              ; recover units from CL
    ADD  AL, '0'             ; units -> ASCII
    MOV  AH, 0Eh
    MOV  BH, 0
    INT  10h                 ; print units

    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

ENDP PrintTwoDigits

;---------------------------------------------------------------------------
; PrintYear
;   Prints a 16-bit year (e.g. 2026) as four decimal digits.
;   Input:  AX = year value
;   All registers preserved.
;---------------------------------------------------------------------------
PROC PrintYear

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV  BX, 100
    MOV  DX, 0
    DIV  BX                  ; AX = century (e.g. 20),  DX = year-in-century (26)
    MOV  CX, DX              ; save year-in-century in CX

    CALL PrintTwoDigits      ; print century  (AX = 20 -> prints "20")

    MOV  AX, CX
    CALL PrintTwoDigits      ; print year-in-century  (AX = 26 -> prints "26")

    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

ENDP PrintYear

;---------------------------------------------------------------------------
; PrintDateTime
;   Reads system date and time, then prints:
;       DayName  DD Mon YYYY  HH:MM:SS
;   at the current cursor position.
;
;   Uses dt_* data-segment variables to store values before printing,
;   avoiding any risk of register/stack corruption across INT calls.
;
;   INT 21h / AH=2Ah  returns CX=year, DH=month(1-12), DL=day, AL=dow(0=Sun)
;   INT 21h / AH=2Ch  returns CH=hour, CL=minute, DH=second
;   All registers preserved.
;---------------------------------------------------------------------------
PROC PrintDateTime

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    ;-- read date from DOS and store in memory --
    MOV  AH, 2Ah
    INT  21h
    MOV  [dt_dow],  AL
    MOV  [dt_day],  DL
    MOV  [dt_mon],  DH
    MOV  [dt_year], CX

    ;-- read time from DOS and store in memory --
    MOV  AH, 2Ch
    INT  21h
    MOV  [dt_hour], CH
    MOV  [dt_min],  CL
    MOV  [dt_sec],  DH

    ;-- print day-of-week name (3 chars from day_names table) --
    MOV  BL, [dt_dow]
    MOV  BH, 0
    MOV  AL, 3
    MUL  BL                  ; AX = dow * 3  (byte offset into day_names)
    LEA  SI, [day_names]
    ADD  SI, AX
    MOV  CX, 3
@PDDayLoop:
    LODSB
    MOV  AH, 0Eh
    MOV  BH, 0
    INT  10h
    LOOP @PDDayLoop

    MOV  AL, ' '             ; space after day name
    MOV  AH, 0Eh
    INT  10h

    ;-- print day number (two digits) --
    MOV  AL, [dt_day]
    CALL PrintTwoDigits

    MOV  AL, ' '
    MOV  AH, 0Eh
    INT  10h

    ;-- print month name (3 chars from month_names table) --
    MOV  BL, [dt_mon]
    DEC  BL                  ; make 0-based  (Jan=0 .. Dec=11)
    MOV  BH, 0
    MOV  AL, 3
    MUL  BL
    LEA  SI, [month_names]
    ADD  SI, AX
    MOV  CX, 3
@PDMonLoop:
    LODSB
    MOV  AH, 0Eh
    MOV  BH, 0
    INT  10h
    LOOP @PDMonLoop

    MOV  AL, ' '
    MOV  AH, 0Eh
    INT  10h

    ;-- print year (four digits) --
    MOV  AX, [dt_year]
    CALL PrintYear

    ;-- two spaces before time --
    MOV  AL, ' '
    MOV  AH, 0Eh
    INT  10h
    MOV  AL, ' '
    MOV  AH, 0Eh
    INT  10h

    ;-- print HH:MM:SS --
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


ENDS .CODE
