data segment 
 MAT db 0, 0, 0, 0, 1, 1, 1 
     db 0, 0, 0, 0, 1, 1, 1
     db 2, 3, 4, 0, 5, 6, 7
     db 2, 3, 4, 0, 5, 6, 7
        
    lg db 4 ;4 lignes 
    cn db 7 ;7 colonnes
    msg  db '-----tache 7 : reflexion verticale de la matrice-----','$'
data ends

code segment 
 assume cs: code , ds: data
start : 
  mov ax, data 
  mov ds, ax 
  
  ;affihcher le msg
  mov ah, 9 
  mov dx, offset msg 
  int 21h
  
  mov dl, 0Dh ;retourner au debut de la ligne 
  mov ah, 2
  int 21h 
  
  mov dl, 0Ah ;sauter la ligne
  int 21h  
  
  ;initaliser un cpt a 4 (nb lignes)
  mov dh, lg
  xor si, si ;equivalent a mov si,0 pour mettre si au debut de la ligne actuelle
  
  ;boucle pour les lignes 
boucle_lignes :
  mov di, si ;on met 2 index un sur la gauche (di) et l'autre sur la droite ou na la fin de la ligne (dx)
             ;di va poiter sur le 1er element de la ligne actuelle
  mov bx, si
  add bx, 7 ;ajouter le nbr de colonnes pour ce mettre a la fin de la ligne
  dec bx 
  mov cx , 3 ;intialiser un autre cpt avec le nbr de permutaions entre les elements de la ligne qui est 3
  
permut_colonnes:
  mov al, [di] ;charger l'@ de l\'element a gauche dans al
  mov dl, [bx] ;charger l'@ de l\'element a droite dans dl
  
  ;permuter 
  mov [di], dl 
  mov [bx], al
   
  inc di ;pour aller au suivant
  dec bx ;pour revenir a l'avant dernier
  
  loop permut_colonnes ;boucler jusqu'a premuter tout les element de la premiere ligne
  ;sauter a la ligne suivante
  add si,7 
  
  dec dh ;decrementer jusqu'a la derniere ligne ou ch=0
  jnz boucle_lignes ; si on est par ex ch=3 donc on refait la permutation des elements de la ligne 2 etc
  
  
  ;afficher la matrice apres reflexion
  
  ;d'abord initialiser ch et si de nouveau car il ont été utilisés
 
  mov dh, lg ;on utilise le ch car on va le decrementer et faire une istructio de branchement , parcontre cx dans le cas d'une loop
  xor si, si ;se mettre a la premiere ligne
  
  ;on doit d'abord parcourir chaque ligne pour afficher chaque elmnt
aff_lignes:
  mov cx ,7
  
aff_colonnes:
  mov al, [si] ;charger dans al la premiere valeure a gauche de la ligne
  
  add al, 30h ; pour convertir les nrb en caracteres ascii
  
  ;affichage des caracteres a l'aide de l\'int 02h
  mov dl, al ;al contien un caractere
  mov ah, 2
  int 21h 
  
  
  ;laisser un espace entre les caracteres
  mov dl, ' '
  mov ah, 2
  int 21h
  
  
  inc si ; pour avancer au prochain elmnt
  loop aff_colonnes
  
  
  
 
  mov dl, 0Dh ;retourner au debut de la ligne 
  mov ah, 2
  int 21h  
  
  mov dl, 0Ah ;faire un saut de ligne , cela pour avoir la bonne forme matricielle dans l'affichage
  int 21h 
  
  dec dh 
  jnz aff_lignes
  
          
  mov ax, 4c00h
  int 21h 
  
  
  
  
  
code ends 
 end start





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
    LEA  SI, [str_yourTask_sub]      ; set your task header here
    CALL PrintString

    MOV  DH, 4
    LEA  SI, [your_matrix]           ; set your matrix here
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