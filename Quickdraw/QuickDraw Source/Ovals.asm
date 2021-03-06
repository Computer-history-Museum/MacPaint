        .INCLUDE  GRAFTYPES.TEXT
;-----------------------------------------------------------
;
;
;      ***   *   *    *    *      ***
;     *   *  *   *   * *   *     *   *
;     *   *  *   *  *   *  *     *
;     *   *  *   *  *   *  *      ***
;     *   *  *   *  *****  *         *
;     *   *   * *   *   *  *     *   *
;      ***     *    *   *  *****  ***
;
;
;
        .PROC StdOval,2
        .REF  CheckPic,PutPicVerb,PutPicRect
        .REF  PutOval,PushVerb,DrawArc
;---------------------------------------------------------------
;
;  PROCEDURE StdOval(verb: GrafVerb; r: Rect);
;
;  A6 OFFSETS OF PARAMS AFTER LINK:
;
PARAMSIZE       .EQU    6
VERB            .EQU    PARAMSIZE+8-2           ;GRAFVERB
RECT            .EQU    VERB-4                  ;LONG, ADDR OF RECT

OVWD            .EQU    -2                      ;WORD
OVHT            .EQU    OVWD-2                  ;WORD
VARSIZE         .EQU    OVHT                    ;TOTAL BYTES OF LOCALS


        LINK    A6,#VARSIZE                     ;ALLOCATE STACK FRAME
        MOVEM.L D7/A3-A4,-(SP)                  ;SAVE REGS
        MOVE.B  VERB(A6),D7                     ;GET VERB
        JSR     CHECKPIC                        ;SET UP A4,A3 AND CHECK PICSAVE
        BLE.S   NOTPIC                          ;BRANCH IF NOT PICSAVE

        MOVE.B  D7,-(SP)
        JSR     PutPicVerb                      ;PUT ADDIONAL PARAMS TO THEPIC
        MOVEQ   #$50,D0                         ;PUT OVALNOUN IN HI NIBBLE
        ADD     D7,D0                           ;PUT VERB IN LO NIBBLE
        MOVE.B  D0,-(SP)                        ;PUSH OPCODE
        MOVE.L  RECT(A6),-(SP)                  ;PUSH ADDR OF RECT
        JSR     PutPicRect                      ;PUT OPCODE AND RECTANGLE

NOTPIC  MOVE.L  RECT(A6),A0                     ;POINT TO RECT
        MOVE    RIGHT(A0),D0
        SUB     LEFT(A0),D0
        MOVE    D0,OVWD(A6)                     ;OVWD := R.RIGHT - R.LEFT
        MOVE    BOTTOM(A0),D0
        SUB     TOP(A0),D0
        MOVE    D0,OVHT(A6)                     ;OVHT := R.BOTTOM - R.TOP

        MOVE.L  A0,-(SP)                        ;PUSH ADDR OF RECT
        TST.B   D7                              ;IS VERB FRAME ?
        BNE.S   NOTFR                           ;NO, CONTINUE
        TST.L   RGNSAVE(A3)                     ;YES, IS RGNSAVE TRUE ?
        BEQ.S   NOTRGN                          ;NO, CONTINUE

        MOVE.L  A0,-(SP)                        ;YES, PUSH ADDR OF RECT
        MOVE.L  OVHT(A6),-(SP)                  ;PUSH OVWD, OVHT
        MOVE.L  RGNBUF(A4),-(SP)                ;PUSH RGNBUF
        PEA     RGNINDEX(A4)                    ;PUSH VAR RGNINDEX
        PEA     RGNMAX(A4)                      ;PUSH VAR RGNMAX
        JSR     PutOval                         ;ADD AN OVAL TO THERGN

NOTRGN  MOVE.B  #1,-(SP)                        ;PUSH HOLLOW = TRUE
        BRA.S   DOIT
NOTFR   CLR.B   -(SP)                           ;PUSH HOLLOW = FALSE
DOIT    MOVE.L  OVHT(A6),-(SP)                  ;PUSH OVWD,OVHT
        JSR     PushVerb                        ;PUSH MODE AND PATTERN
        CLR     -(SP)                           ;PUSH STARTANGLE = 0
        MOVE    #360,-(SP)                      ;PUSH ARCANGLE = 360

;  DrawArc(r,hollow,ovWd,ovHt,mode,pat,startAng,arcAng);

        JSR     DrawArc
        MOVEM.L (SP)+,D7/A3-A4                  ;RESTORE REGS
        UNLINK  PARAMSIZE,'STDOVAL '



        .PROC FrameOval,1
        .DEF  CallOval,PaintOval,EraseOval,InvertOval,FillOval
        .REF  StdOval
;-----------------------------------------------------
;
;  PROCEDURE FrameOval(* r: Rect *);
;
        MOVEQ   #FRAME,D0                       ;VERB = FRAME
        BRA.S   CallOval                        ;SHARE COMMON CODE


;-----------------------------------------------------
;
;  PROCEDURE PaintOval(* r: Rect *);
;
PaintOval
        MOVEQ   #PAINT,D0                       ;VERB = PAINT
        BRA.S   CallOval                        ;SHARE COMMON CODE


;--------------------------------------------------------
;
;  PROCEDURE EraseOval(* r: Rect *);
;
EraseOval
        MOVEQ   #ERASE,D0                       ;VERB = ERASE
        BRA.S   CallOval                        ;SHARE COMMON CODE


;--------------------------------------------------------
;
;  PROCEDURE InvertOval(* r: Rect *);
;
InvertOval
        MOVEQ   #INVERT,D0                      ;VERB = INVERT
        BRA.S   CallOval                        ;SHARE COMMON CODE


;--------------------------------------------------------
;
;  PROCEDURE FillOval(* r: Rect; pat: Pattern *);
;
FillOval
        MOVE.L  (SP)+,A0                        ;POP RETURN ADDR
        MOVE.L  (SP)+,A1                        ;POP ADDR OF PATTERN
        MOVE.L  A0,-(SP)                        ;PUT RETURN ADDR BACK
        MOVE.L  GRAFGLOBALS(A5),A0              ;POINT TO LISAGRAF GLOBALS
        MOVE.L  THEPORT(A0),A0                  ;GET CURRENT GRAFPORT
        LEA     FILLPAT(A0),A0                  ;POINT TO FILLPAT
        MOVE.L  (A1)+,(A0)+                     ;COPY PAT INTO FILLPAT
        MOVE.L  (A1)+,(A0)+                     ;ALL EIGHT BYTES
        MOVEQ   #FILL,D0                        ;VERB = FILL
        BRA.S   CallOval                        ;SHARE COMMON CODE



;---------------------------------------------------------------
;
;  PROCEDURE CallOval(r: Rect);
;
;  code shared by FrameOval, PaintOval, EraseOval, InvertOval, and FillOval.
;  enter with verb in D0.
;
CallOval
        MOVE.L  (SP)+,A0                        ;POP RETURN ADDR
        MOVE.L  (SP)+,A1                        ;POP ADDR OF RECT
        MOVE.B  D0,-(SP)                        ;PUSH VERB
        MOVE.L  A1,-(SP)                        ;PUSH ADDR OF RECT
        MOVE.L  A0,-(SP)                        ;RESTORE RETURN ADDR
        MOVE.L  GRAFGLOBALS(A5),A0              ;POINT TO LISAGRAF GLOBALS
        MOVE.L  THEPORT(A0),A0                  ;GET CURRENT GRAFPORT
        MOVE.L  GRAFPROCS(A0),D0                ;IS GRAFPROCS NIL ?
        LEA     STDOVAL,A0
        BEQ.S   USESTD                          ;YES, USE STD PROC
        MOVE.L  D0,A0
        MOVE.L  OVALPROC(A0),A0                 ;NO, GET PROC PTR
USESTD  JMP     (A0)                            ;GO TO IT


        .END
