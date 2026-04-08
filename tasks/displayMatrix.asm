
;===========================================================================
; DisplayYourMatrix
;   Clears the screen, prints the date/time header, the task subtitle,
;   and then dumps Your_matrix row by row in WHITE_ON_BLACK colour.
;
;   To reuse this pattern for another task, copy the proc, rename it
;   (e.g. DisplayYourMatrix), and change:
;       - LEA  SI, [normalized_matrix]  ->  LEA  SI, [your_matrix]
;       - LEA  SI, [str_t3_sub]         ->  LEA  SI, [str_yourTask_sub]
;===========================================================================
PROC DisplayYourMatrix

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
    LEA  SI, [str_yourTask_sub]
    CALL PrintString

    MOV  DH, 4
    LEA  SI, [your_matrix]
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
