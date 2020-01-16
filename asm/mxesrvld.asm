MXESRVLD TITLE 'MXE - SERVER LOGDATA TASK'
*--------+---------+---------+---------+---------+---------+---------+-
* Name            : MXESRVLD
*
* Function        : MXE Server LogData task
*
*                   Wake up periodically and drain the LOGDATA queue
*                   and WTO the results
*
*                   Uses the MXETASK two-ECB phase subtask start
*                   logic
*
* Notes           :
*                   Example subtask of the MXE server.
*
*                   Example consumer of the PLO-serialized queue
*
* Register Usage  :
* r1  - Parameters passed : +00 MXETASK
* r2  -
* r3  -
* r4  -
* r5  -
* r6  -
* r7  -
* r8  -
* r9  -
* r10 - MXETASK
* r11 - MXEGBVT
* r12 - Data
* r13 - work area
*
*
*--------+---------+---------+---------+---------+---------+---------+-
* Changes
* 2019/01/09   RDS    Code Written
*--------+---------+---------+---------+---------+---------+---------+-
MXESRVLD MXEMAIN DATAREG=(R12),PARMS=(R3)
*--------+---------+---------+---------+---------+---------+---------+-
* Grab the storage for the workarea
*--------+---------+---------+---------+---------+---------+---------+-
     STORAGE OBTAIN,LENGTH=WA@LEN,                                     +
               ADDR=(R13),                                             +
               SP=WA@SP,                                               +
               COND=NO
     USING WA,R13
     MXEMAC INIT,WA,LENGTH==AL4(WA@LEN)      Clear storage
     MXEMAC SET_ID,WA                        and init
     USING SAVF4SA,WA_SAVEAREA
     MVC   SAVF4SAID,=A(SAVF4SAID_VALUE)
*--------+---------+---------+---------+---------+---------+---------+-
* Init code - locate MXETASK and MXEGBVT
*--------+---------+---------+---------+---------+---------+---------+-
     LLGT  R10,0(,R3)                        Load parms
     USING MXETASK,R10                       Address
     MXEMAC VER_ID,MXETASK                   Validate
     IF (LTR,R15,R15,NZ)
       MXEMAC ABEND,MXEEQU@RSN_MXETASK
     ENDIF
     LG    R11,MXETASK_MXEGBVT               Trusted pointer
     USING MXEGBVT,R11
     MXEMAC VER_ID,MXEGBVT                   Validate anyway
     IF (LTR,R15,R15,NZ)
       MXEMAC ABEND,MXEEQU@RSN_MXEGBVT
     ENDIF
     LAE   R1,WA                             Remember ..
     STG   R1,MXETASK_WORKAREA               Debugging purposes
*--------+---------+---------+---------+---------+---------+---------+-
* Execution shell
*--------+---------+---------+---------+---------+---------+---------+-
     DO    ,
*--------+---------+---------+---------+---------+---------+---------+-
* (o) Cover by ESTAE
* (o) Init the environment
* (o) Tell mother task we are ready
*--------+---------+---------+---------+---------+---------+---------+-
       MXECATCH ON,RETRY=MXESRVLD_RECOVERY,                            +
               MF=(E,MXETASK_MXECATCH)
       MXECALL INIT_ENVIRONMENT
       MXETASK REQ=START
       MXEMSG  0004,PARAM==CL8'LOGDATA',OUTPUT=WA_MESSAGE
       WTO   TEXT=WA_MESSAGE,MF=(E,WA_WTO_PLIST)
*--------+---------+---------+---------+---------+---------+---------+-
* Main processing
* (o) Every second, wake up and drain the LOGDATA queue
* (o) Terminate if the MXETASK_TERM_ECB has been posted
*--------+---------+---------+---------+---------+---------+---------+-
       USING MXETIMER,MXETASK_MXETIMER
       DO INF ,
*--------+---------+---------+---------+---------+---------+---------+-
* Build ECB list containing timer ECB and subtask terminate ECB
*--------+---------+---------+---------+---------+---------+---------+-
         MXEMAC VAR_LIST,MXETASK_ECBLIST,                              +
               LIST=(MXETASK_TERM_ECB,MXETIMER_ECB)
*--------+---------+---------+---------+---------+---------+---------+-
* Establish timer and wait to see who pops
*--------+---------+---------+---------+---------+---------+---------+-
         MXETIMER REQ=START,BINTVL==AL4(LC@TIMER_BINTVL)
         WAIT 1,ECBLIST=MXETASK_ECBLIST
*--------+---------+---------+---------+---------+---------+---------+-
* TERM ECB posted ? - We need to stop this subtask
*--------+---------+---------+---------+---------+---------+---------+-
         IF (TM,MXETASK_TERM_ECB,ECBPOST,O)
           MXETIMER REQ=STOP
           DOEXIT ,
         ENDIF
*--------+---------+---------+---------+---------+---------+---------+-
* Drained all ITEMs in the queue and loop back round
*--------+---------+---------+---------+---------+---------+---------+-
         MXECALL DRAIN_LOGDATA_QUEUE
       ENDDO
     ENDDO
*--------+---------+---------+---------+---------+---------+---------+-
* Termination (normal and abnormal)
* Note that MXECATCH will override the RC+RSN only *if* the recovery
* routine was invoked.
*--------+---------+---------+---------+---------+---------+---------+-
     MXECATCH OFF,LABEL=MXESRVLD_RECOVERY,MF=(E,MXETASK_MXECATCH)
     MXEMSG  0005,PARAM==CL8'LOGDATA',OUTPUT=WA_MESSAGE
     WTO   TEXT=WA_MESSAGE,MF=(E,WA_WTO_PLIST)
     MXECALL TERM_ENVIRONMENT
     STORAGE RELEASE,LENGTH=WA@LEN,ADDR=(R13),SP=WA@SP
     MXEMAC ZERO,(R15)
     MXEMAIN RETURN
*--------+---------+---------+---------+---------+---------+---------+-
* Constants and LTORGs
*--------+---------+---------+---------+---------+---------+---------+-
LC@TIMER_BINTVL    EQU   100
     MXEMAC X2C_TABLE
     MXEMAIN END
*
*
*--------+---------+---------+---------+---------+---------+---------+-
*--------+---------+---------+---------+---------+---------+---------+-
* Subroutines
*--------+---------+---------+---------+---------+---------+---------+-
*--------+---------+---------+---------+---------+---------+---------+-
*
*
*
DRAIN_LOGDATA_QUEUE MXEPROC DATAREG=(R12)
*--------+---------+---------+---------+---------+---------+---------+-
* Remove items from the LOGDATA queue and WTO out the contents
*--------+---------+---------+---------+---------+---------+---------+-
     USING WA,R13
     USING MXEGBVT,R11
     USING MXETASK,R10
     MXEMAC AMODE,64
     DO INF
*--------+---------+---------+---------+---------+---------+---------+-
* Remove any ITEM from the head of the queue and place its 64-bit
* address in R5
*--------+---------+---------+---------+---------+---------+---------+-
       MXEQUEUE REQ=POP_HEAD,                                          +
               ITEM=(R5),                                              +
               NEXT_OFFSET=MXEREQDA_NEXT-MXEREQDA,                     +
               QUEUE=MXEGBVT_LOGDATA_QUEUE,                            +
               MF=(E,WA_MXEQUEUE_PLIST)
*--------+---------+---------+---------+---------+---------+---------+-
* Process the MXEREQDA block ?
*--------+---------+---------+---------+---------+---------+---------+-
       DOEXIT (LTGR,R5,R5,Z)
       USING MXEREQDA,R5
       MXECALL PROCESS_MXEREQDA,AMODE=64,                              +
               PARAM=(MXEREQDA),                                       +
               MF=(E,MXETASK_PLIST)
     ENDDO
     MXEMAC AMODE,31
     MXEPROC RETURN
*--------+---------+---------+---------+---------+---------+---------+-
* Local constants (LTORG etc)
*--------+---------+---------+---------+---------+---------+---------+-
     MXEPROC END
*
*
*
PROCESS_MXEREQDA MXEPROC DATAREG=(R12),AMODE=64
*--------+---------+---------+---------+---------+---------+---------+-
* Process the MXEREQDA contents
*--------+---------+---------+---------+---------+---------+---------+-
     USING WA,R13
     USING MXEGBVT,R11
     USING MXETASK,R10
     DO    ,
       DOEXIT (LTGR,R1,R1,Z)
       LG    R5,0(,R1)                 Get the passed parm
       USING MXEREQDA,R5               Should be MXEREQDA
       MXEMAC VER_ID,MXEREQDA
       DOEXIT (LTR,R15,R15,NZ)
*--------+---------+---------+---------+---------+---------+---------+-
* Point R6 at the data payload and WTO out the contents
*--------+---------+---------+---------+---------+---------+---------+-
       LAE   R6,MXEREQDA
       ALGF  R6,MXEREQDA_DATA_OFF
       MVC   WA_DATA_LEFT,MXEREQDA_DATA_LEN      Payload length
       DO UNTIL=(CLC,WA_DATA_LEFT,EQ,=F'0')
*--------+---------+---------+---------+---------+---------+---------+-
* Copy chunks of the payload and use MXEMAC X2C to convert to
* printable characters
*--------+---------+---------+---------+---------+---------+---------+-
         MXEMAC ZERO,WA_DATA_HEX                 Zero out chunk
         LLGT  R14,WA_DATA_LEFT                  Bytes left to process
         IF (CHI,R14,GT,LC@CHUNK_LEN)            more than 16
           LHI   R14,LC@CHUNK_LEN
           MXEMAC SUB,WA_DATA_LEFT,=AL4(LC@CHUNK_LEN)
         ELSE ,                                  Last time thru
           MXEMAC ZERO,WA_DATA_LEFT
         ENDIF
         AHI   R14,-1                            Adjust for execute
         EX    R14,LC_COPY_DATA                  Copy from payload
         MXEMAC X2C,WA_DATA_CHARS,WA_DATA_HEX,   make printable        +
               LENGTH==AL4(LC@CHUNK_LEN)
*--------+---------+---------+---------+---------+---------+---------+-
* Format the message we are going to send out :
*--------+---------+---------+---------+---------+---------+---------+-
         MXEMSG  0003,                                                 +
               PARAM=(WA_DATA_CHARS_WORD_1,                            +
               WA_DATA_CHARS_WORD_2,                                   +
               WA_DATA_CHARS_WORD_3,                                   +
               WA_DATA_CHARS_WORD_4,                                   +
               WA_DATA_HEX),                                           +
               OUTPUT=WA_MESSAGE
         WTO   TEXT=WA_MESSAGE,MF=(E,WA_WTO_PLIST)
         LAE   R6,LC@CHUNK_LEN(,R6)
       ENDDO
*--------+---------+---------+---------+---------+---------+---------+-
* All done with payload - release the cell from the bufferpool
*--------+---------+---------+---------+---------+---------+---------+-
       IARCP64 REQUEST=FREE,CELLNAME=(R5),REGS=SAVE
     ENDDO
     MXEPROC RETURN
*--------+---------+---------+---------+---------+---------+---------+-
* Local constants (LTORG etc)
*--------+---------+---------+---------+---------+---------+---------+-
LC_COPY_DATA       MVC   WA_DATA_HEX(0),0(R6)
LC@CHUNK_LEN       EQU   L'WA_DATA_HEX
     MXEPROC END
*
*
*
INIT_ENVIRONMENT MXEPROC DATAREG=(R12)
*--------+---------+---------+---------+---------+---------+---------+-
* Init the environment
*--------+---------+---------+---------+---------+---------+---------+-
     USING WA,R13
     USING MXEGBVT,R11
     USING MXETASK,R10
     DO    ,
       MVC   WA_WTO_PLIST,LC_WTO_PLIST
     ENDDO
     MXEPROC RETURN
*--------+---------+---------+---------+---------+---------+---------+-
* Local constants (LTORG etc)
*--------+---------+---------+---------+---------+---------+---------+-
LC_WTO_PLIST       WTO   TEXT=((R2)),MF=L
LC@WTO_LEN         EQU   *-LC_WTO_PLIST
     MXEPROC END
*
*
*
TERM_ENVIRONMENT MXEPROC DATAREG=(R12)
*--------+---------+---------+---------+---------+---------+---------+-
* Terminate the server
*--------+---------+---------+---------+---------+---------+---------+-
     USING WA,R13
     USING MXEGBVT,R11
     USING MXETASK,R10
     DO    ,
       DOEXIT (LTR,R11,R11,Z)                    Ensure MXEGBVT
       MXEMAC VER_ID,MXEGBVT
       DOEXIT (LTR,R15,R15,NZ)
*--------+---------+---------+---------+---------+---------+---------+-
* Room for any code required at termination
*--------+---------+---------+---------+---------+---------+---------+-
     ENDDO
     MXEPROC RETURN
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
*
                     SYSSTATE AMODE64=YES
*
WA                   DSECT
WA_SAVEAREA          DS    XL(SAVF4SA_LEN)
                     DS    0D
WA_ID                DS    CL8                   Eye-catcher
WA_VER               DS    X                     Version
WA@VER_CURRENT       EQU   X'01'
WA_FLG1              DS    X
WA_FLG2              DS    X
WA_FLG3              DS    X
WA_LEN               DS    F
WA_WA                DS    AD                    Self
WA_STCK              DS    XL8                   Obtained STCK
WA_RC                DS    F                     Return code
WA_RSN               DS    0F                    Reason code
WA_RSN_COMPID        DS    XL2                   ..comp id
WA_RSN_CODE          DS    XL2                   ..code
                     DS    0D
WA_WORK_D            DS    D
                     DS    0D
WA_ECBLIST           DS    0XL(4*4)              Room for 4 ECBs
WA_ECBLIST_1         DS    A
WA_ECBLIST_2         DS    A
WA_ECBLIST_3         DS    A
WA_ECBLIST_4         DS    A
                     DS    0D
WA_DATA_LEFT         DS    F
                     DS    0D
WA_DATA_HEX          DS    XL16
WA_DATA_CHARS        DS    0CL32
WA_DATA_CHARS_WORD_1 DS    CL8
WA_DATA_CHARS_WORD_2 DS    CL8
WA_DATA_CHARS_WORD_3 DS    CL8
WA_DATA_CHARS_WORD_4 DS    CL8
                     DS    0D
WA_MESSAGE           DS    XL128
                     DS    0D
WA_WTO_PLIST         DS    XL(LC@WTO_LEN)
                     DS    0D
                     MXEQUEUE MF=(L,WA_MXEQUEUE_PLIST)
                     DS    0D
WA@LEN               EQU   *-WA
WA@SP                EQU   50
*
*
*
*
         MXEGBVT
         MXETASK  DSECT=YES
         MXEREQ   DSECT=YES
         MXEMSGDF DSECT=YES
*
         CVT      DSECT=YES
         IEANTASM
         IHASAVER
         IHAECB
*
*
         MXEMAC   REG_EQU
         END
