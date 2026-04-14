.MODEL SMALL
.STACK 100h

.DATA
    COMPTEUR DW 546
    OLD_OFF  DW ?
    OLD_SEG  DW ?

.CODE
START:
    MOV AX, @DATA
    MOV DS, AX

    ; --- 1. SAUVEGARDER L'ANCIEN VECTEUR (AH=35h) ---
    MOV AH, 35h
    MOV AL, 1Ch
    INT 21h
    MOV [OLD_OFF], BX
    MOV [OLD_SEG], ES

    ; --- 2. INSTALLER LA ROUTINE  (AH=25h) ---
    PUSH DS
    MOV AX, CS
    MOV DS, AX
    MOV DX, OFFSET TIMER_TICK
    MOV AH, 25h
    MOV AL, 1Ch
    INT 21h
    POP DS

    ; --- 3. BOUCLE D'ATTENTE ---
WAIT_LOOP:
    CMP [COMPTEUR], 0    
    JG WAIT_LOOP

    ; --- 4. RESTAURER LE VECTEUR D'ORIGINE 
    MOV DX, [OLD_OFF]
    MOV AX, [OLD_SEG]
    MOV DS, AX
    
    MOV AH, 25h
    MOV AL, 1Ch
    INT 21h

    ; --- FIN DU PROGRAMME ---
    MOV AX, 4C00h
    INT 21h

;hadiya la proc tji 9bl fin programme ---------------------------------------------------------
; ROUTINE TIMER_TICK
; ---------------------------------------------------------
TIMER_TICK PROC
    PUSH AX
    PUSH DS
    
    MOV AX, @DATA
    MOV DS, AX
    
    DEC [COMPTEUR]
    
    POP DS
    POP AX
    IRET
TIMER_TICK ENDP

END START