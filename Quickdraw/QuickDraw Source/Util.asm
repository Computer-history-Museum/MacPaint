        .INCLUDE GRAFTYPES.TEXT
;-------------------------------------------------------------
;
;  --> UTIL.TEXT
;
;  SMALL UTILITY ROUTINES USED BY QuickDraw.
;


        .FUNC BitNot,1
;-----------------------------------------------------------
;
;  Function BitNot(long: LongInt): LongInt;
;
        MOVE.L  (SP)+,A0                        ;POP RETURN ADDR
        NOT.L   (SP)                            ;INVERT LONG
        MOVE.L  (SP)+,(SP)                      ;STORE INTO RESULT
        JMP     (A0)                            ;AND RETURN


        .FUNC BitAnd,2
        .DEF  BitXor,BitOr,BitShift
;-----------------------------------------------------------
;
;  Function BitAnd(long1,long2: LongInt): LongInt;
;
        MOVE.L  (SP)+,A0                        ;POP RETURN ADDR
        MOVE.L  (SP)+,D0                        ;GET ONE LONG
        AND.L   (SP)+,D0                        ;AND IT WITH THE OTHER
        BRA.S   DONE                            ;AND STORE RESULT


;-----------------------------------------------------------
;
;  Function BitXor(long1,long2: LongInt): LongInt;
;
BitXor  MOVE.L  (SP)+,A0                        ;POP RETURN ADDR
        MOVE.L  (SP)+,D0                        ;GET ONE LONG
        MOVE.L  (SP)+,D1                        ;GET THE SECOND
        EOR.L   D1,D0                           ;XOR BOTH
        BRA.S   DONE                            ;AND STORE RESULT


;-----------------------------------------------------------
;
;  Function BitOr(long1,long2: LongInt): LongInt;
;
BitOr   MOVE.L  (SP)+,A0                        ;POP RETURN ADDR
        MOVE.L  (SP)+,D0                        ;GET ONE LONG
        OR.L    (SP)+,D0                        ;OR IT WITH THE OTHER
        BRA.S   DONE                            ;AND STORE RESULT


;-----------------------------------------------------------
;
;  Function BitShift(long: LongInt; count: INTEGER): LongInt;
;
;  positive count --> shift left.
;  negative count --> shift right.
;
BitShift MOVE.L (SP)+,A0                        ;POP RETURN ADDR
        MOVE    (SP)+,D1                        ;GET COUNT
        BPL.S   SHLEFT                          ;SHIFT LEFT IF POSITIVE
        NEG     D1                              ;MAKE COUNT POSITIVE
        MOVE.L  (SP)+,D0                        ;GET LONG
        LSR.L   D1,D0                           ;SHIFT IT RIGHT
        BRA.S   DONE                            ;AND STORE RESULT
SHLEFT  MOVE.L  (SP)+,D0                        ;GET LONG
        LSL.L   D1,D0                           ;SHIFT IT LEFT
DONE    MOVE.L  D0,(SP)                         ;STORE THE RESULT
        JMP     (A0)                            ;AND RETURN


        .FUNC BitTst,2
        .DEF  BitSet,BitClr
;---------------------------------------------------------
;
;   FUNCTION BitTst(bytePtr: Ptr; bitNum: LongInt): BOOLEAN;
;
        BSR.S   SHARE
        MOVE.L  (SP)+,A1                        ;GET PTR
        BTST    D0,0(A1,D1.L)                   ;TEST THE BIT
        SNE     (SP)                            ;SET OR CLEAR RESULT
        NEG.B   (SP)                            ;CONVERT -1 TO 1
        JMP     (A0)                            ;RETURN


;---------------------------------------------------------
;
;   PROCEDURE BitSet(bytePtr: Ptr; bitNum: LongInt);
;
BitSet  BSR.S   SHARE
        MOVE.L  (SP)+,A1                        ;GET PTR
        BSET    D0,0(A1,D1.L)                   ;SET THE BIT
        JMP     (A0)


;---------------------------------------------------------
;
;   PROCEDURE BitClr(bytePtr: Ptr; bitNum: LongInt);
;
BitClr  BSR.S   SHARE
        MOVE.L  (SP)+,A1                        ;GET PTR
        BCLR    D0,0(A1,D1.L)                   ;SET THE BIT
        JMP     (A0)
;
;
;
SHARE   MOVE.L  (A7)+,A1
        MOVE.L  (SP)+,A0                        ;POP RETURN ADDR
        MOVE.L  (SP)+,D1                        ;GET BITNUM
        MOVE    D1,D0                           ;COPY IT
        ASR.L   #3,D1                           ;CONVERT BITS TO BYTES
        NOT     D0                              ;REVERSE BIT SENSE
        JMP     (A1)



        .FUNC Random,0
;--------------------------------------------------------------
;
;  FUNCTION Random: INTEGER;
;
;  returns a signed 16 bit number, and updates unsigned 32 bit randSeed.
;
;  recursion is randSeed := (randSeed * 16807) MOD 2147483647.
;
;  See paper by Linus Schrage, A More Portable Fortran Random Number Generator
;  ACM Trans Math Software Vol 5, No. 2, June 1979, Pages 132-138.
;
;  Clobbers D0-D2, A0
;
;
;  GET LO 16 BITS OF SEED AND FORM LO PRODUCT
;  xalo := A * LoWord(seed)
;
        MOVE.L  GRAFGLOBALS(A5),A0      ;POINT TO QuickDraw GLOBALS
        MOVE    #16807,D0               ;GET A = 7^5
        MOVE    D0,D2                   ;GET A = 7^5
        MULU    RANDSEED+2(A0),D0       ;CALC LO PRODUCT = XALO
;
;  FORM 31 HIGHEST BITS OF LO PRODUCT
;  fhi:=HiWord(seed) * ORD4(a) + HiWord(xalo);
;
        MOVE.L  D0,D1                   ;COPY xalo
        CLR.W   D1
        SWAP    D1                      ;GET HiWord(xalo) as a long
        MULU    RANDSEED(A0),D2         ;MULT BY HiWord(seed)
        ADD.L   D1,D2                   ;ADD LEFTLO = FHI
;
;  GET OVERFLOW PAST 31ST BIT OF FULL PRODUCT
;  k:=fhi DIV 32768;
;
        MOVE.L  D2,D1                   ;COPY FHI
        ADD.L   D1,D1                   ;CALC 2 TIMES FHI
        CLR.W   D1
        SWAP    D1                      ;CALC FHI SHIFTED RIGHT 15 FOR K
;
;  ASSEMBLE ALL THE PARTS AND PRE-SUBTRACT P
;  seed:=((BitAnd(XALO,$0000FFFF) - P) + BitAnd(fhi,$00007FFF) * b16) + K;
;
        AND.L   #$0000FFFF,D0           ;GET LO WORD XALO
        SUB.L   #$7FFFFFFF,D0           ;SUBTRACT P = 2^31-1
        AND.L   #$00007FFF,D2           ;BitAnd(fhi,$00007FFF)
        SWAP    D2                      ;TIMES 64K
        ADD.L   D1,D2                   ;PLUS K
        ADD.L   D2,D0                   ;CALC TOTAL
;
;  IF seed < 0 THEN seed:=seed+p;
;
        BPL.S   UPDATE
        ADD.L   #$7FFFFFFF,D0
UPDATE  MOVE.L  D0,RANDSEED(A0)         ;UPDATE SEED
        CMP.W   #$8000,D0               ;IS NUMBER -32768 ?
        BNE.S   NUMOK                   ;NO, CONTINUE
        CLR     D0                      ;YES, RETURN ZERO INSTEAD
NUMOK   MOVE.W  D0,4(SP)                ;RETURN LO WORD AS RESULT
        RTS



        .PROC ForeColor,1
        .DEF  BackColor,PortLong,ColorBit,PortWord
;--------------------------------------------------------------
;
;  PROCEDURE ForeColor(color: LongInt);
;
        MOVEQ   #FGCOLOR,D0                     ;GET OFFSET TO FGCOLOR
        BRA.S   PortLong                        ;INSTALL A LONG



;--------------------------------------------------------------
;
;  PROCEDURE BackColor(color: LongInt);
;
BackColor
        MOVEQ   #BKCOLOR,D0                     ;GET OFFSET TO FGCOLOR
;
;  FALL THRU INTO PORTLONG
;
;-------------------------------------------------------
;
;  PROCEDURE PortLong(long: LongInt);
;  INSTALL A LONG INTO CURRENT GRAFPORT.  ENTER WITH OFFSET IN D0
;
PortLong
        MOVE.L  (SP)+,A1                        ;POP RETURN ADDR
        MOVE.L  GRAFGLOBALS(A5),A0              ;POINT TO QuickDraw GLOBALS
        MOVE.L  THEPORT(A0),A0                  ;POINT TO THEPORT
        MOVE.L  (SP)+,0(A0,D0)                  ;INSTALL WORD INTO THEPORT
        JMP     (A1)                            ;AND RETURN


;--------------------------------------------------------------
;
;  PROCEDURE ColorBit(whichBit: INTEGER);
;
ColorBit
        MOVEQ   #COLRBIT,D0                     ;GET OFFSET TO COLRBIT
                                                ;FALL THRU INTO PORTWORD

;-------------------------------------------------------
;
;  PROCEDURE PortWord(word: INTEGER);
;  INSTALL A WORD INTO CURRENT GRAFPORT.  ENTER WITH OFFSET IN D0
;
PortWord
        MOVE.L  (SP)+,A1                        ;POP RETURN ADDR
        MOVE.L  GRAFGLOBALS(A5),A0              ;POINT TO QuickDraw GLOBALS
        MOVE.L  THEPORT(A0),A0                  ;POINT TO THEPORT
        MOVE.W  (SP)+,0(A0,D0)                  ;INSTALL WORD INTO THEPORT
        JMP     (A1)                            ;AND RETURN



        .PROC GetMaskTab,0
        .DEF  LeftMask,RightMask,BitMask,MaskTab
;----------------------------------------------------------
;
;  ASSEMBLY LANGUAGE CALLABLE PROCEDURES LEFTMASK, RIGHTMASK, AND BITMASK:
;
;  ENTER WITH COORDINATE IN D0, RETURNS WITH 16 BIT MASK IN D0
;  NO OTHER REGISTERS ALTERED.
;
        LEA   MaskTab,A0                        ;POINT TO MASK TABLE
        RTS                                     ;AND RETURN

LeftMask
        AND   #$F,D0                            ;TREAT MOD 16
        ADD   D0,D0                             ;DOUBLE FOR TABLE
        MOVE  MASKTAB+32(D0),D0                 ;GET LEFTMASK
        RTS

RIGHTMASK
        AND   #$F,D0                            ;TREAT MOD 16
        ADD   D0,D0                             ;DOUBLE FOR TABLE
        MOVE  MASKTAB(D0),D0                    ;GET RIGHT MASK
        RTS

BITMASK AND   #$F,D0                            ;TREAT MOD 16
        ADD   D0,D0                             ;DOUBLE FOR TABLE
        MOVE  MASKTAB+64(D0),D0                 ;GET BITMASK
        RTS

MASKTAB .WORD    $0000,$8000,$C000,$E000        ;TABLE OF 16 RIGHT MASKS
        .WORD    $F000,$F800,$FC00,$FE00
        .WORD    $FF00,$FF80,$FFC0,$FFE0
        .WORD    $FFF0,$FFF8,$FFFC,$FFFE

        .WORD    $FFFF,$7FFF,$3FFF,$1FFF        ;TABLE OF 16 LEFT MASKS
        .WORD    $0FFF,$07FF,$03FF,$01FF
        .WORD    $00FF,$007F,$003F,$001F
        .WORD    $000F,$0007,$0003,$0001

        .WORD    $8000,$4000,$2000,$1000        ;TABLE OF 16 BIT MASKS
        .WORD    $0800,$0400,$0200,$0100
        .WORD    $0080,$0040,$0020,$0010
        .WORD    $0008,$0004,$0002,$0001




        .PROC PatExpand,0
;----------------------------------------------------------
;
;  EXPAND AN 8 BYTE PATTERN OUT TO 16 LONGS.
;
;  CALLED ONLY FROM BITBLT,RGNBLT,DRAWLINE,DRAWARC.
;
;  INPUTS:   A0: POINTS TO 8 BYTE PATTERN
;            A1: POINTS TO 16 LONGS OF DESTINATION
;            A5: PASCAL GLOBAL PTR
;            D2: HORIZONTAL GLOBAL-LOCAL OFFSET USED FOR PRE-ROTATE
;            D7: -1 TO INVERT, ELSE 0
;            patStretch AND PATALIGN
;
;  OUTPUTS:  16 LONGS OF EXPANDED PATTERN
;
;  CLOBBERS: D0,D1,D2,A0,A1
;
PARAMSIZE       .EQU    0
TWOPAT          .EQU    -16                     ;ROOM FOR TWO COPIES OF PAT
VARSIZE         .EQU    TWOPAT                  ;TOTAL BYTES OF LOCAL VARS


        LINK    A6,#VARSIZE                     ;ALLOCATE STACK FRAME
        MOVE.L  A4,-(SP)                        ;SAVE REGS
        MOVE.L  GRAFGLOBALS(A5),A4              ;POINT TO QUICKDRAW GLOBALS
;
;  IF PATALIGN VERT NON-ZERO, COPY PAT TWICE AND REPLACE A0
;
        MOVEQ   #7,D0
        AND     PATALIGN(A4),D0                 ;GET PATALIGN MOD 8
        BEQ.S   VERTOK                          ;SKIP IF ZERO
        MOVE.L  (A0),TWOPAT(A6)                 ;MAKE TWO COPIES OF PATTERN
        MOVE.L  (A0)+,TWOPAT+8(A6)
        MOVE.L  (A0),TWOPAT+4(A6)
        MOVE.L  (A0),TWOPAT+12(A6)
        LEA     TWOPAT(A6),A0
        ADD     D0,A0
VERTOK
        ADD     PATALIGN+H(A4),D2               ;ADJUST FOR PATALIGN HORIZ
        MOVEQ   #7,D1                           ;INIT COUNT OF 8 BYTES
        AND     D1,D2                           ;TREAT SHIFTCOUNT MOD 8
        MOVE.L  THEPORT(A4),A4                  ;GET CURRENT GRAFPORT
        MOVE    patStretch(A4),D0               ;GET patStretch
        CMP     #2,D0                           ;IS patStretch = 2 ?
        BEQ.S   DOUBLE                          ;YES, DOUBLE
        CMP     #-2,D0                          ;IS PAT STRETCH = -2 ?
        BEQ.S   THIN                            ;YES, STRETCH THIN
                                                ;ANY OTHER, USE NORMAL

;---------------------------------------------------------
;
;  NORMAL PATTERN.  SIMPLY REPLICATE THE 8 BY 8 PATTERN.
;
NORMAL  MOVE.B  (A0)+,D0                        ;GET A BYTE OF PATTERN
        EOR.B   D7,D0                           ;INVERT IT IF MODE BIT 2
        ROL.B   D2,D0                           ;ALIGN TO LOCAL COORDS
        MOVE.B  D0,(A1)+                        ;PUT ONE BYTE
        MOVE.B  D0,(A1)+                        ;PUT ANOTHER TO MAKE A WORD
        MOVE.W  -2(A1),(A1)+                    ;STRETCH WORD OUT TO LONG
        MOVE.L  -4(A1),32-4(A1)                 ;DUPLICATE 8 SCANS LATER
        DBRA    D1,NORMAL                       ;LOOP ALL 8 INPUT BYTES
        BRA.S   DONE


;-----------------------------------------------------------
;
;  STRETCHED BY TWO: DOUBLE EACH BIT HORIZONTALLY AND VERTICALLY
;
DOUBLE  CLR     D0                              ;CLEAR OUT HI BYTE
DLOOP   MOVE.B  (A0)+,D0                        ;GET A BYTE OF PATTERN
        EOR.B   D7,D0                           ;INVERT IT IF MODE BIT 2
        ROL.B   D2,D0                           ;ALIGN TO LOCAL COORDS
        MOVE.B  D0,-(SP)                        ;STASH FOR A WHILE
        LSR.B   #4,D0                           ;GET HI NIBBLE
        MOVE.B  STRETCH(D0),(A1)+               ;PUT ONE BYTE
        MOVEQ   #$F,D0                          ;MASK FOR LO NIBBLE
        AND.B   (SP)+,D0                        ;GET THE LO NIBBLE
        MOVE.B  STRETCH(D0),(A1)+               ;PUT ANOTHER TO MAKE A WORD
        MOVE.W  -2(A1),(A1)+                    ;STRETCH WORD OUT TO LONG
        MOVE.L  -4(A1),(A1)+                    ;STRETCH LONG TO TWO LONGS
        DBRA    D1,DLOOP                        ;LOOP ALL 8 INPUT BYTES
        BRA.S   DONE


;-----------------------------------------------------------
;
;  STRETCH BY TWO AND THIN OUT THE BITS.  ADD EXTRA WHITE DOTS.
;
THIN    CLR     D0                              ;CLEAR OUT HI BYTE
THINLP  MOVE.B  (A0)+,D0                        ;GET A BYTE OF PATTERN
        EOR.B   D7,D0                           ;INVERT IT IF MODE BIT 2
        ROL.B   D2,D0                           ;ALIGN TO LOCAL COORDS
        MOVE.B  D0,-(SP)                        ;STASH FOR A WHILE
        LSR.B   #4,D0                           ;GET HI NIBBLE
        MOVE.B  THINSTR(D0),(A1)+               ;PUT ONE BYTE
        MOVEQ   #$F,D0                          ;MASK FOR LO NIBBLE
        AND.B   (SP)+,D0                        ;GET THE LO NIBBLE
        MOVE.B  THINSTR(D0),(A1)+               ;PUT ANOTHER TO MAKE A WORD
        MOVE.W  -2(A1),(A1)+                    ;STRETCH WORD OUT TO LONG
        CLR.L   (A1)+                           ;STRETCH LONG TO TWO LONGS
        DBRA    D1,THINLP                       ;LOOP ALL 8 INPUT BYTES

DONE    MOVE.L  (SP)+,A4                        ;RESTORE REG
        UNLINK  PARAMSIZE,'PATEXPAN'


;----------------------------------------------------------------
;
;  BIT DOUBLING TABLE FOR 0..15 INPUT --> BYTE OUTPUT
;
STRETCH .BYTE $00,$03,$0C,$0F,$30,$33,$3C,$3F
        .BYTE $C0,$C3,$CC,$CF,$F0,$F3,$FC,$FF
;
;  TABLE FOR THIN DOUBLING.
;
THINSTR .BYTE $00,$01,$04,$05,$10,$11,$14,$15
        .BYTE $40,$41,$44,$45,$50,$51,$54,$55




        .PROC ColorMap,2
;----------------------------------------------------------------
;
;  PROCEDURE ColorMap(mode: INTEGER, pat: Pattern);
;
;  ADJUST INPUT MODE AND PATTERN TO ACCOMPLISH COLOR SEPARATION.
;  Returns (altered) mode and pat on the stack where they were.
;  PRESERVES ALL REGISTERS.
;
        MOVEM.L D0-D3/A0,-(SP)                  ;SAVE REGS
        MOVE.L  GRAFGLOBALS(A5),A0              ;POINT TO QuickDraw GLOBALS
        MOVE.L  THEPORT(A0),A0                  ;GET CURRENT GRAFPORT
        MOVE.L  A0,D0                           ;IS THEPORT NIL ?
        BEQ.S   COLOROK                         ;YES, LEAVE COLOR ALONE
        BTST    #0,D0                           ;IS THEPORT ODD ?
        BNE.S   COLOROK                         ;YES, LEAVE COLOR ALONE
        MOVE    COLRBIT(A0),D2                  ;GET COLOR BIT SELECT
        BEQ.S   COLOROK                         ;COLORBIT = 0 MEANS NO COLOR
        MOVE    28(SP),D3                       ;GET INPUT MODE
        MOVEQ   #3,D0                           ;MASK FOR BOTTOM 2 BITS
        AND     D3,D0                           ;GET 2 BITS OF MODE
        BEQ.S   COPY                            ;BR IF COPY MODE
;
;  THE XOR MODES DEPEND ON NEITHER FOREGROUND OR BACKGROUND COLOR
;
        CMP     #2,D0                           ;IS IT SOME KIND OF XOR ?
        BEQ.S   COLOROK                         ;YES, THEY DON'T CHANGE
        BGT.S   BICMODE                         ;BRANCH IF BIC
                                                ;ELSE MUST BE OR
;
; THE OR MODES DEPEND ONLY ON THE FOREGROUND COLOR
;
ORMODE  MOVE.L  FGCOLOR(A0),D1                  ;GET FOREGROUND COLOR
SHARE   BTST    D2,D1                           ;TEST FOREGROUND COLOR BIT
        BNE.S   COLOROK                         ;NO CHANGE IF FG TRUE
        EOR     #2,D3                           ;ELSE INVERT MODE BIT 2
        BRA.S   NEWMODE                         ;UPDATE MODE AND QUIT

;
;  THE BIC MODES DEPEND ONLY ON THE BACKGROUND COLOR
;
BICMODE MOVE.L  BKCOLOR(A0),D1                  ;GET BACKGROUND COLOR
        NOT.L   D1                              ;INVERT IT
        BRA     SHARE                           ;AND SHARE CODE

;
;  THE COPY MODES DEPEND ON BOTH FOREGOUND AND BACKGROUND
;
COPY    MOVE.L  FGCOLOR(A0),D0                  ;GET FOREGROUND COLOR
        MOVE.L  BKCOLOR(A0),D1                  ;GET BACKGROUND COLOR
        BTST    D2,D0                           ;TEST FOREGROUND COLOR BIT
        BEQ.S   FORE0                           ;BRANCH IF IT'S ZERO

FORE1   BTST    D2,D1                           ;TEST BACKGROUND COLOR BIT
        BEQ.S   COLOROK                         ;NO CHANGE IF BKGND FALSE
        MOVEQ   #8,D3                           ;ELSE REPLACE MODE = PAT COPY
USEPAT  MOVE.L  GRAFGLOBALS(A5),A0              ;POINT TO QuickDraw GLOBALS
        LEA     BLACK(A0),A0                    ;POINT TO BLACK PATTERN
        MOVE.L  A0,24(SP)                       ;REPLACE PATTERN WITH BLACK
        BRA.S   NEWMODE                         ;UPDATE MODE AND QUIT

FORE0   BTST    D2,D1                           ;TEST BACKGROUND COLOR BIT
        BNE.S   INVMODE                         ;IF BK TRUE, INVERT MODE
        MOVEQ   #12,D3                          ;ELSE REPLACE MODE = NOTPAT COPY
        BRA.S   USEPAT                          ;AND PATTERN WITH BLACK

INVMODE EOR     #4,D3                           ;USE INVERSE OF MODE
NEWMODE MOVE    D3,28(SP)                       ;CHANGE INPUT MODE
COLOROK MOVEM.L (SP)+,D0-D3/A0                  ;RESTORE REGS
        RTS                                     ;AND RETURN


        .FUNC GetPixel,2
        .REF  HideCursor,ShowCursor
;---------------------------------------------------------
;
;  FUNCTION GetPixel(h,v: INTEGER): BOOLEAN;
;
;  Returns TRUE if the pixel at (h,v) is set to black.
;  h and v are in local coords of the current grafport.
;
;  CLOBBERS A0,A1,D0,D1,D2
;
        JSR     HIDECURSOR                      ;GET RID OF CURSOR
        MOVE.L  (SP)+,D2                        ;POP RETURN ADDR
        MOVE.L  GRAFGLOBALS(A5),A1              ;POINT TO QuickDraw GLOBALS
        MOVE.L  THEPORT(A1),A1                  ;GET THEPORT
        MOVE    (SP)+,D0                        ;GET VERT COORD
        SUB     PORTBITS+BOUNDS+TOP(A1),D0      ;CONVERT TO GLOBAL COORDS
        MOVE    (SP)+,D1                        ;GET HORIZ COORD
        SUB     PORTBITS+BOUNDS+LEFT(A1),D1     ;CONVERT TO GLOBAL
        MULU    PORTBITS+ROWBYTES(A1),D0        ;CALC VERT * ROWBYTES
        MOVE.L  PORTBITS+BASEADDR(A1),A1        ;GET BASEADDR
        ADD.L   D0,A1                           ;ADD VERTICAL OFFSET
        MOVE    D1,D0                           ;COPY HORIZ
        NOT     D0                              ;INVERT FOR BIT INDEX
        LSR     #3,D1                           ;CONVERT DOTS TO BYTES
        BTST    D0,0(A1,D1)                     ;TEST ONE SCREEN BIT
        SNE     (SP)                            ;SET BOOLEAN RESULT
        NEG.B   (SP)                            ;MAKE $FF --> $01
        MOVE.L  D2,-(SP)                        ;PUSH RETURN ADDR
        JMP     SHOWCURSOR                      ;RESTORE CURSOR AND RETURN



        .PROC StuffHex,2
;-------------------------------------------------------
;
;  PROCEDURE STUFFHEX(THINGPTR: WORDPTR; S: STR255);
;
;  CONVENIENCE ROUTINE TO STUFF HEX INTO ANY VARIABLE.
;  BEWARE, NO RANGE-CHECKING.
;
        MOVE.L  4(SP),A0                        ;A0:=ADDR OF STRING
        MOVE.L  8(SP),A1                        ;A1:=THINGPTR
        MOVE.L  (SP),8(SP)                      ;CLEAN OFF STACK
        ADD     #8,SP                           ;POINT TO RETURN ADDR
        MOVE.B  (A0)+,D2                        ;GET STRING LENGTH
        AND     #$00FE,D2                       ;TRUNCATE LENGTH TO EVEN
        BEQ.S   ENDHEX                          ;QUIT IF LENGTH = 0
HEXLOOP BSR.S   NEXTHEX                         ;GET HEX DIGIT AND CONVERT TO BINARY
        MOVE.B  D0,D1                           ;SAVE MOST SIG DIGIT
        BSR.S   NEXTHEX                         ;GET HEX DIGIT AND CONVERT TO BINARY
        LSL.B   #4,D1                           ;SHIFT MOST SIG INTO PLACE
        ADD.B   D0,D1                           ;FILL IN LS NIBBLE
        MOVE.B  D1,(A1)+                        ;STUFF BYTE INTO THING
        SUB     #2,D2                           ;2 LESS CHARS TO GO
        BNE.S   HEXLOOP                         ;LOOP FOR STRING LENGTH
ENDHEX  RTS                                     ;RETURN TO PASCAL
;
;  LOCAL ROUTINE TO GET NEXT HEX DIGIT AND CONVERT ASCII TO BINARY
;
NEXTHEX MOVE.B  (A0)+,D0                        ;GET HEX DIGIT FROM STRING
        CMP.B   #$39,D0                         ;IS IT GTR THAN '9' ?
        BLE.S   SMALL                           ;NO, DO IT
        ADD.B   #9,D0                           ;YES, ADD CORRECTION
SMALL   AND.B   #$F,D0                          ;TREAT MOD 16, EVEN LOWER CASE OK
        RTS



        .PROC XorSlab
        .REF  MaskTab
;-----------------------------------------------------------
;
;  LOCAL PROCEDURE XorSlab(bufAddr: Ptr; left,right: INTEGER);
;
;  Enter with:
;
;       A0:  bufAddr
;       D3:  left coord
;       D4:  right coord
;
;  Clobbers:  A0,D0,D1,D3,D4,D5,D6
;
;
;  GET LEFTMASK AND RIGHTMASK
;
        MOVE.L  A0,D1                           ;save bufAddr
        LEA     MASKTAB,A0                      ;point to mask table
        MOVEQ   #$F,D0                          ;get mask for 4 lo bits

        MOVE    D3,D5                           ;COPY LEFT COORD
        AND     D0,D5                           ;CALC LEFT MOD 16
        ADD     D5,D5                           ;DOUBLE FOR TABLE INDEX
        MOVE    0(A0,D5),D5                     ;GET MASK FROM TABLE
        NOT     D5                              ;INVERT FOR LEFTMASK

        MOVE    D4,D6                           ;COPY RIGHT COORD
        AND     D0,D6                           ;TREAT RIGHT MOD 16
        ADD     D6,D6                           ;DOUBLE FOR TABLE INDEX
        MOVE    0(A0,D6),D6                     ;GET RIGHTMASK IN D6
        MOVE.L  D1,A0                           ;RESTORE SAVED bufAddr

;
;  CALC LEFTWORD, BUFPTR, WORDCOUNT
;
        ASR     #4,D3                           ;CONVERT DOTS TO WORDS
        ADD     D3,A0                           ;ADD TO bufAddr
        ADD     D3,A0                           ;TWICE FOR BYTE OFFSET
        ASR     #4,D4                           ;CALC RIGHT DIV 16
        SUB     D3,D4                           ;WORDCOUNT:=RIGHTWORD-LEFTWORD
        BGT.S   NOTIN1                          ;BR IF NOT ALL IN ONE
;
;  LEFT AND RIGHT ARE ALL IN ONE WORD
;
        AND     D5,D6                           ;COMBINE LEFT AND RIGHT MASKS
        EOR     D6,(A0)                         ;XOR RIGHTMASK INTO BUFFER
        RTS                                     ;AND RETURN
;
;  NOT ALL IN ONE WORD.  DO LEFT, MIDDLE IF ANY, THEN RIGHT
;
NOTIN1  EOR     D5,(A0)+                        ;XOR LEFTMASK INTO BUFFER
        BRA.S   TEST                            ;SEE IF ANY FULL WORDS
INVLONG NOT.L   (A0)+                           ;INVERT 2 WHOLE WORDS
TEST    SUBQ    #2,D4                           ;ANY FULL WORDS LEFT ?
        BGT     INVLONG                         ;YES, AT LEAST 2
        BLT.S   ENDWORD                         ;NO, FINISH UP LAST WITH MASK
        NOT     (A0)+                           ;YES, DO LAST FULL WORD
ENDWORD EOR     D6,(A0)                         ;XOR RIGHTMASK INTO BUFFER
        RTS


        .PROC DrawSlab,0
        .DEF  SlabMode,FastSlabMode
        .REF  MaskTab
;--------------------------------------------------------------
;
; LOCAL PROCEDURE DRAWSLAB
;
;  INPUTS:
;
;    D0: scratch                A0: MASKTAB
;    D1: left                   A1: DSTLEFT, clobbered
;    D2: right                  A2: MASKBUF, clobbered
;    D3:                        A3: MINRECT
;    D4:                        A4: MODECASE
;    D5:                        A5:
;    D6: pattern                A6:
;    D7:                        A7: stack
;
;  CLOBBERS: D0-D3,A1,A2
;
;
;
;  CLIP LEFT AND RIGHT TO MINRECT:
;
        CMP     LEFT(A3),D1                     ;IS LEFT < MINRECT.LEFT ?
        BGE.S   LEFTOK                          ;NO, CONTINUE
        MOVE    LEFT(A3),D1                     ;YES, LEFT := MINRECT.LEFT
LEFTOK  CMP     RIGHT(A3),D2                    ;IS RIGHT > MINRECT.RIGHT ?
        BLE.S   RIGHTOK                         ;NO, CONTINUE
        MOVE    RIGHT(A3),D2                    ;YES, RIGHT := MINRECT.RIGHT
RIGHTOK CMP     D2,D1                           ;IS LEFT >= RIGHT ?
        BGE.S   DONESLAB                        ;YES, QUIT

;
;  SET UP LEFTMASK AND RIGHTMASK:   (A0 already points to MaskTab)
;
        MOVEQ   #$F,D3                          ;get mask for 4 lo bits
        MOVE    D1,D0                           ;COPY LEFT
        AND     D3,D1                           ;TREAT LEFT MOD 16
        ADD     D1,D1                           ;DOUBLE FOR TABLE
        MOVE    32(A0,D1),D1                    ;GET LEFTMASK IN D1
        AND     D2,D3                           ;GET RIGHT MOD 16
        ADD     D3,D3                           ;DOUBLE FOR TABLE
        MOVE    0(A0,D3),D3                     ;GET RIGHTMASK IN D3

;
;  CALC WORDCOUNT, DSTPTR, MASKPTR, AND TAKE CASE JUMP
;
        ASR     #4,D2                           ;CONVERT RIGHT TO WORDS
        ASR     #4,D0                           ;CONVERT LEFT TO WORDS
        SUB     D0,D2                           ;CALC WORD COUNT
        ADD     D0,D0                           ;DOUBLE FOR BYTES
        ADD     D0,A1                           ;OFFSET DSTPTR
        ADD     D0,A2                           ;OFFSET MASKPTR
        TST     D2                              ;SET Z-FLAG BASED ON WORDCOUNT
        JMP     (A4)                            ;TAKE MODECASE TO DRAW SLAB
DONESLAB RTS




;---------------------------------------------------------
;
;  INTERFACE TO EACH SCAN LINE ROUTINE:
;
;  ENTER WITH Z-FLAG SET IF ALL IN ONE WORD
;
;  INPUTS:      A1: DSTPTR
;               A2: MASKPTR
;               D1: LEFTMASK
;               D2: WORDCNT
;               D3: RIGHTMASK
;               D6: PATTERN
;
;  CLOBBERS:    D0,D1,D2,A1,A2
;

;-------------------------------------------------------
;
;  MODE 8 OR 12: PATTERN --> DST
;
END8    AND     D3,D1           ;COMBINE RIGHT AND LEFT MASK
NEXT8   MOVE    D6,D0           ;GET PATTERN DATA
        AND     (A2)+,D1        ;MERGE MASK AND CLIPRGN MASK
        AND     D1,D0           ;MASK PATTERN DATA
        NOT     D1              ;MAKE NOTMASK
        AND     (A1),D1         ;AND NOTMASK WITH OLD DST
        OR      D0,D1           ;FILL HOLE WITH PATTERN
        MOVE    D1,(A1)+        ;UPDATE DST
        MOVEQ   #-1,D1          ;FLUSH MASK
        SUB     #1,D2           ;DEC WORD COUNT
MASK8   BGT     NEXT8           ;LOOP FOR ALL WORDS IN ROW
        BEQ     END8            ;DO LAST WORD WITH MASK
        RTS


;-------------------------------------------------------
;
;  MODE 9 OR 13: PATTERN OR DST --> DST
;
END9    AND     D3,D1           ;COMBINE RIGHT AND LEFT MASK
NEXT9   AND     D6,D1           ;GET PATTERN DATA
        AND     (A2)+,D1        ;MERGE MASK AND CLIPRGN MASK
        OR      D1,(A1)+        ;OR RESULT INTO DST
        MOVEQ   #-1,D1          ;FLUSH MASK
        SUB     #1,D2           ;DEC WORD COUNT
MASK9   BGT     NEXT9           ;LOOP FOR ALL WORDS IN ROW
        BEQ     END9            ;DO LAST WORD WITH MASK
        RTS


;-------------------------------------------------------
;
;  MODE 10 OR 14: PATTERN XOR DST --> DST
;
END10   AND     D3,D1           ;COMBINE RIGHT AND LEFT MASK
NEXT10  AND     D6,D1           ;GET PATTERN DATA
        AND     (A2)+,D1        ;MERGE MASK AND CLIPRGN MASK
        EOR     D1,(A1)+        ;XOR RESULT INTO DST
        MOVEQ   #-1,D1          ;FLUSH MASK
        SUB     #1,D2           ;DEC WORD COUNT
MASK10  BGT     NEXT10          ;LOOP FOR ALL WORDS IN ROW
        BEQ     END10           ;DO LAST WORD WITH MASK
        RTS


;-------------------------------------------------------
;
;  MODE 11 OR 15: PATTERN BIC DST --> DST
;
END11   AND     D3,D1           ;COMBINE RIGHT AND LEFT MASK
NEXT11  AND     D6,D1           ;GET PATTERN DATA
        AND     (A2)+,D1        ;MERGE MASK AND CLIPRGN MASK
        NOT     D1              ;INVERT FOR BIC
        AND     D1,(A1)+        ;BIC RESULT INTO DST
        MOVEQ   #-1,D1          ;FLUSH MASK
        SUB     #1,D2           ;DEC WORD COUNT
MASK11  BGT     NEXT11          ;LOOP FOR ALL WORDS IN ROW
        BEQ     END11           ;DO LAST WORD WITH MASK
        RTS

;--------------------------------------------
;
;  PROCEDURE SlabMode
;
;  INPUT:    D2: MODE, CLOBBERED
;  OUTPUT:   A4: MODECASE
;
SlabMode
        AND    #$3,D2                           ;GET LO 2 BITS OF MODE
        LEA     MODETAB,A4                      ;POINT TO MODE TABLE
        MOVE.B  0(A4,D2),D2                     ;GET OFFSET FROM MODETAB
        SUB     D2,A4                           ;GET CASE JUMP ADDRESS
        RTS

MODETAB .BYTE    MODETAB-MASK8
        .BYTE    MODETAB-MASK9
        .BYTE    MODETAB-MASK10
        .BYTE    MODETAB-MASK11


;---------------------------------------------------------------
;
;  FAST LOOPS, OPTIMIZED FOR BLACK PATTERN AND RECTANGLE CLIPPED
;
;  FAST BLACK SLAB:
;
FAST8   BEQ.S   MERGE8                          ;BR IF ALL IN ONE WORD
        OR      D1,(A1)+                        ;OR LEFTMASK INTO DST
        SUB     #2,D2                           ;ADJUST WORDCOUNT FOR DBRA
        BLT.S   LAST8                           ;BR IF NO UNMASKED WORDS
        MOVEQ   #-1,D1                          ;GET SOME BLACK
LOOP8   MOVE    D1,(A1)+                        ;WRITE A WORD OF BLACK
        DBRA    D2,LOOP8                        ;LOOP ALL UNMASKED WORDS
MERGE8  AND     D1,D3                           ;COMBINE LEFTMASK AND RIGHTMASK
LAST8   OR      D3,(A1)+                        ;OR RIGHTMASK INTO DST
        RTS                                     ;AND RETURN

;
;  FAST XOR SLAB:
;
FAST10  BEQ.S   MERGE10                         ;BR IF ALL IN ONE WORD
        EOR     D1,(A1)+                        ;XOR LEFTMASK INTO DST
        SUB     #2,D2                           ;ADJUST WORDCOUNT FOR DBRA
        BLT.S   LAST10                          ;BR IF NO UNMASKED WORDS
LOOP10  NOT     (A1)+                           ;INVERT A WORD OF DST
        DBRA    D2,LOOP10                       ;LOOP ALL UNMASKED WORDS
        BRA.S   LAST10                          ;THEN FINISH UP LAST WITH MASK
MERGE10 AND     D1,D3                           ;COMBINE LEFTMASK AND RIGHTMASK
LAST10  EOR     D3,(A1)+                        ;XOR RIGHTMASK INTO DST
        RTS                                     ;AND RETURN

;
;  FAST WHITE SLAB:
;
FAST11  BEQ.S   MERGE11                         ;BR IF ALL IN ONE WORD
        NOT     D1                              ;FORM NOT LEFTMASK
        AND     D1,(A1)+                        ;AND NOT LEFTMASK INTO DST
        SUB     #2,D2                           ;ADJUST WORDCOUNT FOR DBRA
        BLT.S   LAST11                          ;BR IF NO UNMASKED WORDS
LOOP11  CLR     (A1)+                           ;CLEAR A WORD OF DST
        DBRA    D2,LOOP11                       ;LOOP ALL UNMASKED WORDS
        BRA.S   LAST11                          ;THEN FINISH UP LAST WITH MASK
MERGE11 AND     D1,D3                           ;COMBINE LEFTMASK AND RIGHTMASK
LAST11  NOT     D3                              ;FORM NOT RIGHTMASK
        AND     D3,(A1)+                        ;AND NOT RIGHTMASK INTO DST
        RTS                                     ;AND RETURN


;--------------------------------------------------------------------
;
;  PROCEDURE FastSlabMode,  Call when rect clipped and pattern black.
;
;  INPUT:    D2: MODE, CLOBBERED  mode 0=black, 1=xor, 2=white
;  OUTPUT:   A4: MODECASE
;
FastSlabMode
        AND    #$3,D2                           ;GET LO 2 BITS OF MODE
        LEA     FASTTAB,A4                      ;POINT TO MODE TABLE
        MOVE.B  0(A4,D2),D2                     ;GET OFFSET FROM FASTTAB
        SUB     D2,A4                           ;GET CASE JUMP ADDRESS
        RTS

FASTTAB .BYTE    FASTTAB-FAST8                  ;BLACK
        .BYTE    FASTTAB-FAST10                 ;XOR
        .BYTE    FASTTAB-FAST11                 ;WHITE


        .END
