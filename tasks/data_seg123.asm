; this file contains the data segment of the 3 first tasks


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