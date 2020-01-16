MXEEOTXR TITLE 'MXE COMMON END OF TASK EXIT ROUTINE'
*--------+---------+---------+---------+---------+---------+---------+-
* Name            : MXEEOTXR
*
* Function        : General purpose end of task exit routine
*
*                 : Lookup the MXETASK control block for the related
*                   terminating TCB. The MXETASK is anchored by a
*                   name/token using a known label suffixed by the
*                   TCB address as the name. The MXETASK control
*                   block is the first doubleword in the token.
*
*
* Register Usage  :
* r1  - parameter passed : TCB
* r2  -
* r3  -
* r4  -
* r5  -
* r6  -
* r7  -
* r8  -
* r9  - TCB
* r10 - MXETASK
* r11 -
* r12 - Data
* r13 -
*
*--------+---------+---------+---------+---------+---------+---------+-
* Changes
* 2019/01/09   RDS    Code Written
*--------+---------+---------+---------+---------+---------+---------+-
MXEEOTXR MXEMAIN DATAREG=(R12),PARMS=(R9)
         USING TCB,R9
         TESTAUTH FCTN=1               Are we auth ?
         IF (LTR,R15,R15,Z)            ..yes flip to supervisor
           MODESET MODE=SUP,KEY=NZERO
         ENDIF
*--------+---------+---------+---------+---------+---------+---------+-
* Grab a small workarea
*--------+---------+---------+---------+---------+---------+---------+-
         STORAGE OBTAIN,LENGTH=WA@LEN,                                 +
               SP=WA@SP,KEY=WA@KEY,                                    +
               ADDR=(R13),                                             +
               COND=NO
         USING WA,R13
         MXEMAC INIT,WA,LENGTH==AL4(WA@LEN)      Clear
         MXEMAC SET_ID,WA                        Init block
         USING SAVF4SA,WA_SAVEAREA
         MVC   SAVF4SAID,=A(SAVF4SAID_VALUE)
*--------+---------+---------+---------+---------+---------+---------+-
* Attempt to find the MXETASK address for this TCB
* (o) Build the "name"
* (o) Locate the EPA of IEANTRT via macro assist
* (o) Call IEANTRT to retrieve the token
*--------+---------+---------+---------+---------+---------+---------+-
         DO    ,
           MXETASK REQ=SET_NAME,NAME=WA_NAME,TCB=(R9)
           MXEMAC GET_IEANTRT,R15
           CALL (R15),(=AL4(IEANT_HOME_LEVEL),                         +
               WA_NAME,                                                +
               WA_TOKEN,                                               +
               WA_RC),                                                 +
               MF=(E,WA_PLIST)
           DOEXIT (CLC,WA_RC,NE,=F'0')
*--------+---------+---------+---------+---------+---------+---------+-
* (o) We have a token, valid the address and eye-catcher
*--------+---------+---------+---------+---------+---------+---------+-
           DOEXIT (LTG,R10,WA_TOKEN_ADDR,Z)
           USING MXETASK,R10
           MXEMAC VER_ID,MXETASK                  valid eye-catcher?
           DOEXIT (LTR,R15,R15,NZ)               No - badness
           DETACH MXETASK_TCB                    DETACH TCB
           POST  MXETASK_DETACH_ECB              and tell mother
           MXEMAC ZERO,(R9)                      Zero TCB address
         ENDDO
*--------+---------+---------+---------+---------+---------+---------+-
* (o) If validation fails, we just DETACH with no MXETASK
*--------+---------+---------+---------+---------+---------+---------+-
         IF (LTR,R9,R9,NZ)
           DETACH (R9)
         ENDIF
*--------+---------+---------+---------+---------+---------+---------+-
* Release workarea
*--------+---------+---------+---------+---------+---------+---------+-
         STORAGE RELEASE,LENGTH=WA@LEN,ADDR=(R13),                     +
               SP=WA@SP,KEY=WA@KEY,                                    +
               COND=NO
         MXEMAIN RETURN
         MXEMAIN END
*--------+---------+---------+---------+---------+---------+---------+-
*--------+---------+---------+---------+---------+---------+---------+-
* DSECTS
*--------+---------+---------+---------+---------+---------+---------+-
*--------+---------+---------+---------+---------+---------+---------+-
WA                   DSECT
WA_SAVEAREA          DS    XL(SAVF4SA_LEN)
WA_ID                DS    CL8                   Eye-catcher
WA_VER               DS    X                     Version
WA@VER_CURRENT       EQU   X'01'
WA_FLG1              DS    X
WA_FLG2              DS    X
WA_FLG3              DS    X
WA_LEN               DS    F
WA_WA                DS    AD                    Self
WA_STCK              DS    XL8                   Obtained STCK
WA_RC                DS    F
WA_RSN               DS    F
WA_NAME              DS    CL16                  Name/token "NAME"
                     DS    0D
WA_TOKEN             DS    0CL16                 Name/token "TOKEN"
WA_TOKEN_ADDR        DS    CL8
WA_TOKEN_SEQ         DS    XL8
                     DS    0D
WA_PLIST             DS    XL(8*4)               General PLIST
                     DS    0D
WA@LEN               EQU   *-WA
WA@SP                EQU   230
WA@KEY               EQU   KEY@2
*
         MXEGBVT
         MXETASK DSECT=YES
         MXEMAC  REG_EQU
*
         IKJTCB
         IHASAVER
         IEANTASM
*
         END
