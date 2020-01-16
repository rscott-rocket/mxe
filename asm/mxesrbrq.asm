MXESRBRQ TITLE 'MXE - SRB ROUTINE'
*--------+---------+---------+---------+---------+---------+---------+-
* Name            : MXESRBRQ
*
* Function        : MXE SRB routine to perform data discovery services
*
*                   Routine passed MXEREQPM structure as parameters
*                   by the code in MXESRVPC.
*
*                   MXEREQPM is small block in E-CSA and contains
*                   all information needed by this SRB to perform
*                   the data discovery and pass back the results.
*
*                   MXEREQPM contains a token that is used to
*                   correlate the data passed back by this SRB to
*                   the original caller.
*
* Register Usage  :
* r1  -
* r2  -
* r3  -
* r4  -
* r5  - ASCB
* r6  - MXEREQPM
* r7  -
* r8  -
* r9  -
* r10 -
* r11 - MXEGBVT
* r12 - Data
* r13 - work area
*
*
*--------+---------+---------+---------+---------+---------+---------+-
* Changes
* 2019/01/09   RDS    Code Written
*--------+---------+---------+---------+---------+---------+---------+-
MXESRBRQ MXEMAIN DATAREG=(R12),PARMS=(R6)
*--------+---------+---------+---------+---------+---------+---------+-
* Establish parameters
*--------+---------+---------+---------+---------+---------+---------+-
     USING MXEREQPM,R6                       Get parameters
     LR    R10,R2                            Copy FRR parm address
     STORAGE OBTAIN,LENGTH=WA@LEN,                                     +
               SP=WA@SP,KEY=WA@KEY,                                    +
               ADDR=(R13),                                             +
               COND=NO
     USING WA,R13
     MXEMAC INIT,WA,LENGTH==AL4(WA@LEN)      Clear
     MXEMAC SET_ID,WA                        Init block
     USING SAVF4SA,WA_SAVEAREA
     MVC   SAVF4SAID,=A(SAVF4SAID_VALUE)
     LLGT  R5,PSAAOLD-PSA(,R0)               Get ASCB
     USING ASCB,R5
*--------+---------+---------+---------+---------+---------+---------+-
* Setup recovery (FRR) - R10 contains FRR parm address.
* MXEGBVT_FRR has EPA of FRR covering this SRB (see the IEAMSCHD
* statements in MXESRVPC).
*--------+---------+---------+---------+---------+---------+---------+-
     MXECATCH ON,MODE=FRR,FRR_PARM=(R10),                              +
               RETRY=MXESRBRQ_RECOVERY,                                +
               MF=(E,WA_MXECATCH_PLIST)
*--------+---------+---------+---------+---------+---------+---------+-
* Main execution shell
* (o) Validate the MXEREQPM structure
* (o) The MXESRVPC routine populates MXEREQPM with the MXEGBVT address
*     and we can trust it as it comes from authorized environment.
* (o) For the indicated query "type", invoke the associated routine
* (o) Use MXEREQ REQ=DATA to pass any results back to the MXE
*     server.
* (o) Pass back the success/failure via RC+RSN
*--------+---------+---------+---------+---------+---------+---------+-
     DO    ,
       MXEMAC SET_RC,WA_RETINFO_RC,MXEEQU@RC_SEVERE
       MXEMAC SET_RSN,WA_RETINFO_RSN,MXEEQU@RSN_BAD_ENV
       MXEMAC VER_ID,MXEREQPM                    Validate block
       DOEXIT (LTR,R15,R15,NZ)
       MXEMAC ADD,MXEREQPM_DIAG,=F'1'            Diagnosis word
       LG    R11,MXEREQPM_MXEGBVT                Trusted address
       USING MXEGBVT,R11
       MXEMAC VER_ID,MXEGBVT                     Validate it
       MXEMAC ADD,MXEREQPM_DIAG,=F'1'            Diagnosis
       SELECT CLC,MXEREQPM_TYPE,EQ               Query type
         WHEN (LC_QUERY_GETACEE)
           MXECALL PROCESS_GETACEE,              Get the ACEE          +
               RC=WA_RETINFO_RC,                                       +
               RSN=WA_RETINFO_RSN
           MXEMAC ADD,MXEREQPM_DIAG,=F'1'
         OTHRWISE
           MXEMAC SET_RC,WA_RETINFO_RC,MXEEQU@RC_ERROR
           MXEMAC SET_RSN,WA_RETINFO_RSN,MXEEQU@RSN_BAD_TYPE
       ENDSEL
       MXEMAC ADD,MXEREQPM_DIAG,=F'1'            Diagnosis
     ENDDO
*--------+---------+---------+---------+---------+---------+---------+-
* Termination (normal and abnormal)
* Note that MXECATCH will override the RC+RSN only *if* the recovery
* routine was invoked.
*--------+---------+---------+---------+---------+---------+---------+-
     MXECATCH OFF,                                                     +
               LABEL=MXESRBRQ_RECOVERY,                                +
               RC=WA_RETINFO_RC,                                       +
               RSN=WA_RETINFO_RSN,                                     +
               MF=(E,WA_MXECATCH_PLIST)
     MXEMAIN RETINFO,RC=WA_RETINFO_RC,RSN=WA_RETINFO_RSN
     STORAGE RELEASE,LENGTH=WA@LEN,ADDR=(R13),                         +
               SP=WA@SP,KEY=WA@KEY,                                    +
               COND=NO
     MXEMAIN RETURN
*--------+---------+---------+---------+---------+---------+---------+-
* Mainline constants
*--------+---------+---------+---------+---------+---------+---------+-
LC_QUERY_GETACEE   DC    CL8'GETACEE'
     MXEMAIN END
*
*
*--------+---------+---------+---------+---------+---------+---------+-
*--------+---------+---------+---------+---------+---------+---------+-
* Subroutines
*--------+---------+---------+---------+---------+---------+---------+-
*--------+---------+---------+---------+---------+---------+---------+-
*
PROCESS_GETACEE MXEPROC DATAREG=(R12)
*--------+---------+---------+---------+---------+---------+---------+-
* Handle the request to return the ACEE block for the address space
*--------+---------+---------+---------+---------+---------+---------+-
     USING WA,R13
     USING MXEGBVT,R11
     USING MXEREQPM,R6                           Get parameters
     USING ASCB,R5
     DO   ,
       LLGT  R9,ASCBASXB                         Get the ASXB
       LLGT  R9,ASXBSENV-ASXB(,R9)               Get the ACEE
       USING ACEE,R9                             Address the ACEE
       MXEMAC ZERO,(R14)
       ICM   R14,B'0111',ACEELEN                 Get the length
       ST    R14,WA_PAYLOAD_LEN
*--------+---------+---------+---------+---------+---------+---------+-
* Validate ACEE length within bounds
*--------+---------+---------+---------+---------+---------+---------+-
       MXEMAC SET_RC,WA_RC,MXEEQU@RC_ERROR
       MXEMAC SET_RSN,WA_RSN,MXEEQU@RSN_BAD_LENGTH
       DOEXIT (CLC,WA_PAYLOAD_LEN,EQ,=AL4(0))
       DOEXIT (CLC,WA_PAYLOAD_LEN,GT,=AL4(L'WA_PAYLOAD))
*--------+---------+---------+---------+---------+---------+---------+-
* Copy the ACEE from Key0 storage to Key2 workarea
*--------+---------+---------+---------+---------+---------+---------+-
       MXEMAC MOVE_SRC_KEY,WA_PAYLOAD,ACEE,                            +
               LENGTH=WA_PAYLOAD_LEN,                                  +
               KEY==AL4(KEY@ZERO)
*--------+---------+---------+---------+---------+---------+---------+-
* Use MXEREQ to transfer the ACEE as payload into a 64-bit cell in
* one of MXE's bufferpools. The MXEREQPM_CORID provides a method
* to correlate this data with the original caller.
*--------+---------+---------+---------+---------+---------+---------+-
       MXEREQ REQ=DATA,                                                +
               CORID=MXEREQPM_CORID,                                   +
               ANSAREA=WA_PAYLOAD,                                     +
               ANSLEN=WA_PAYLOAD_LEN,                                  +
               RC=WA_RC,                                               +
               RSN=WA_RSN,                                             +
               MF=(E,WA_MXEREQ_PLIST)
     ENDDO
     MXEPROC RETURN,RC=WA_RC,RSN=WA_RSN
*--------+---------+---------+---------+---------+---------+---------+-
* Local constants (LTORG etc)
*--------+---------+---------+---------+---------+---------+---------+-
     MXEPROC END
*
*
*
*
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
WA_RC                DS    F                     subroutine RC+RSN
WA_RSN               DS    F
WA_RETINFO_RC        DS    F                     SRB RC+RSN
WA_RETINFO_RSN       DS    F
                     DS    0D
                     MXEREQ MF=(L,WA_MXEREQ_PLIST)
                     DS    0D
                     MXECATCH MF=(L,WA_MXECATCH_PLIST)
                     DS    0D
WA_PAYLOAD_LEN       DS    F                     Payload length
WA_PAYLOAD           DS    CL4096                Payload data
                     DS    0D
WA@LEN               EQU   *-WA
WA@SP                EQU   230
WA@KEY               EQU   KEY@2
*
         MXEGBVT
         MXECATCH DSECT=YES
         MXEREQ   DSECT=YES
*
         IHASAVER
         IHAPSA
         IHAASCB
         IHAASXB
         IHAACEE
         CVT    DSECT=YES
*
         MXEMAC REG_EQU
         END
