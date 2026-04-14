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
    MOV  tick_counter, 546

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
; Updated MAIN  -  replace INT 16h waits with CALL Wait30Sec
;===========================================================================
;
; MAIN PROC
;
;     MOV  AX, SEG original_matrix
;     MOV  DS, AX
;     MOV  ES, AX
;
;     CALL Task1_DisplayOriginal
;     CALL Wait30Sec
;
;     CALL Task2_CleanMatrix
;     CALL Wait30Sec
;
;     CALL Task3_NormalizeMatrix
;     CALL Wait30Sec
;
;     CALL Task4_RowReduction
;     CALL Wait30Sec
;
;     CALL Task5_ColReduction
;     CALL Wait30Sec
;
;     CALL Task6_HorizReflect
;     CALL Wait30Sec
;
;     CALL Task7_VertReflect
;     CALL Wait30Sec
;
;     MOV  AH, 4Ch
;     MOV  AL, 00h
;     INT  21h
;
; MAIN ENDP
;
;===========================================================================
; Add to .DATA:
;
;     tick_counter  DW 546   ; 18.2 ticks/sec x 30sec = 546
;     old_1ch_off   DW 0     ; saved INT 1Ch offset
;     old_1ch_seg   DW 0     ; saved INT 1Ch segment
;===========================================================================
