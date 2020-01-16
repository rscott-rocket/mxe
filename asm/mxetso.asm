MXETSO TITLE 'MXE - TSO CLIENT PROGRAM'
*--------+---------+---------+---------+---------+---------+---------+-
* Name            : MXETSO
*
* Function        : MXE Client TSO Program
*
*                   (o) Locate the MXEGBVT via name/token lookup
*
*                   (o) Issue MXE QUERY request to get the ACEE for
*                       the passed jobname (using first-found logic)
*
*                   (o) Dump the ANSAREA that contains the data
*                       returned by the QUERY service.
*
*                   (o) If LOG(YES), copy the ANSAREA data to the MXE
*                       LOGDATA queue so that it is WTO'ed out
*
*                   The processing flow for the REQ=QUERY is as
*                   follows :
*
*                   (o) Format MXEREQ parameter list
*                   (o) Locate MXE server PC routine number in
*                       MXEGBVT and invoke PC passing MXEREQ as
*                       parameter via R1.
*                   (o) MXESRVPC gains control and builds a MXEREQPM
*                       structure in E-CSA and schedules MXESRBRQ as
*                       an SRB into the target address space.
*                   (o) MXESRBRQ locates the ACEE and uses its own
*                       MXEREQ REQ=DATA call to copy the ACEE to
*                       a cell in the MXE server bufferpool.
*                   (o) MXESRVPC gains control after MXESRBRQ ends and
*                       copies the contents of the bufferpool cell back
*                       to the ANSAREA provided by this program
*
*
*                   The processing flow for the REQ=LOGDATA is as
*                   follows :
*
*                   (o) Format MXEREQ parameter list
*                   (o) Locate MXE server PC routine number in
*                       MXEGBVT and invoke PC passing MXEREQ as
*                       parameter via R1.
*                   (o) MXESRVPC gains control and copies the ANSAREA
*                       data into a cell in the MXE server bufferpool.
*                   (o) MXESRVPC adds the cell to the LOGDATA queue
*                       using the MXEQUEUE macro (PLO).
*                   (o) Control to passed back to this program
*                   (o) Asynchrously, the MXESRVLD subtask running in
*                       the MXE server drains the data from the LOGDATA
*                       queue and WTOs the contents.
*
*
*
* Register Usage  :
* r1  -
* r2  -
* r3  -
* r4  -
* r5  -
* r6  -
* r7  -
* r8  -
* r9  -
* r10 - CPPL
* r11 - MXEGBVT
* r12 - Data
* r13 - work area
*
*
*--------+---------+---------+---------+---------+---------+---------+-
* Changes
* 2019/01/09   RDS    Code Written
*--------+---------+---------+---------+---------+---------+---------+-
MXETSO MXEMAIN DATAREG=(R12),PARMS=(R10)
*--------+---------+---------+---------+---------+---------+---------+-
* Grab the storage for the workarea
*--------+---------+---------+---------+---------+---------+---------+-
     STORAGE OBTAIN,LENGTH=WA@LEN,                                     +
               ADDR=(R13),                                             +
               SP=WA@SP,                                               +
               COND=NO
     USING WA,R13
     USING CPPL,R10
     MXEMAC INIT,WA,LENGTH==AL4(WA@LEN)      Clear storage
     MXEMAC SET_ID,WA                        and init
     USING SAVF4SA,WA_SAVEAREA
     MVC   SAVF4SAID,=A(SAVF4SAID_VALUE)
*--------+---------+---------+---------+---------+---------+---------+-
* Execution shell
*--------+---------+---------+---------+---------+---------+---------+-
     DO    ,
*--------+---------+---------+---------+---------+---------+---------+-
* Process parameters
*--------+---------+---------+---------+---------+---------+---------+-
       MXECALL PARSE_COMMAND_TEXT            Parse using IKJPARS
       DOEXIT (LTR,R15,R15,NZ)
*--------+---------+---------+---------+---------+---------+---------+-
* Locate MXE server
*--------+---------+---------+---------+---------+---------+---------+-
       MXEREQ  REQ=GETTOKEN,                 Get MXEGBVT anchor        +
               TOKEN=WA_TOKEN,                                         +
               RC=WA_RC,                                               +
               MF=(E,WA_MXEREQ_PLIST)
       MXECALL REPORT_MXEREQ
       DOEXIT (LTR,R15,R15,NZ)
       LTG   R11,WA_TOKEN                    First dword = address
       DOEXIT (Z)
       USING MXEGBVT,R11                     Validate eye-catcher
       MXEMAC VER_ID,MXEGBVT
       DOEXIT (LTR,R15,R15,NZ)
*--------+---------+---------+---------+---------+---------+---------+-
* Issue query request to copy data into WA_ANSAREA
*--------+---------+---------+---------+---------+---------+---------+-
       MXEREQ  REQ=QUERY,                                              +
               TYPE=WA_QUERY,                                          +
               JOBNAME=WA_JOBNAME,                                     +
               ANSAREA=WA_ANSAREA,                                     +
               ANSLEN==AL4(L'WA_ANSAREA),                              +
               RC=WA_RC,                                               +
               RSN=WA_RSN,                                             +
               OUTPUT=WA_ANSLEN,                                       +
               MF=(E,WA_MXEREQ_PLIST)
       MXECALL REPORT_MXEREQ
       DOEXIT (LTR,R15,R15,NZ)
*--------+---------+---------+---------+---------+---------+---------+-
* Report on contents of ANSAREA
*--------+---------+---------+---------+---------+---------+---------+-
       MXECALL DUMP_ANSWER_AREA
*--------+---------+---------+---------+---------+---------+---------+-
* Copy the ANSAREA back over to the LOGDATA queue in the MXE server
* address space.
*--------+---------+---------+---------+---------+---------+---------+-
       IF (CLC,WA_LOG,EQ,=C'YES')
         MXEREQ  REQ=LOGDATA,                                          +
               ANSAREA=WA_ANSAREA,                                     +
               ANSLEN=WA_ANSLEN,                                       +
               RC=WA_RC,                                               +
               RSN=WA_RSN,                                             +
               MF=(E,WA_MXEREQ_PLIST)
         MXECALL REPORT_MXEREQ
         DOEXIT (LTR,R15,R15,NZ)
       ENDIF
     ENDDO
*--------+---------+---------+---------+---------+---------+---------+-
* Termination
*--------+---------+---------+---------+---------+---------+---------+-
     MXEMAIN RETINFO,RC=WA_RC
     STORAGE RELEASE,LENGTH=WA@LEN,ADDR=(R13),SP=WA@SP
     MXEMAIN RETURN
*--------+---------+---------+---------+---------+---------+---------+-
* Constants and LTORGs
*--------+---------+---------+---------+---------+---------+---------+-
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
DUMP_ANSWER_AREA MXEPROC DATAREG=(R12)
*--------+---------+---------+---------+---------+---------+---------+-
* Dump the answer area
*--------+---------+---------+---------+---------+---------+---------+-
     USING WA,R13
     USING MXEGBVT,R11
     USING CPPL,R10
     USING MXEREQ,WA_MXEREQ_PLIST
     DO   ,
       MXEMAC ZERO,WA_BYTES_DUMPED
       DO WHILE=(CLC,WA_BYTES_DUMPED,LT,WA_ANSLEN)
         LAE   R6,WA_ANSAREA
         AL    R6,WA_BYTES_DUMPED
         MVC   WA_MESSAGE_CHUNK,0(R6)
         MXEMAC X2C,WA_MESSAGE_HEX,WA_MESSAGE_CHUNK
         MXEMSG 0003,TYPE=PUTLINE,                                     +
               PARAM=(WA_MESSAGE_W1,                                   +
               WA_MESSAGE_W2,                                          +
               WA_MESSAGE_W3,                                          +
               WA_MESSAGE_W4,                                          +
               WA_MESSAGE_CHUNK),                                      +
               OUTPUT=WA_MESSAGE
         MXECALL ISSUE_PUTLINE,                                        +
               PARAM=(WA_MESSAGE),                                     +
               MF=(E,WA_MXECALL_PLIST)
         MXEMAC ADD,WA_BYTES_DUMPED,=AL4(LC@CHUNK_SIZE)
       ENDDO
     ENDDO
     MXEPROC RETURN
*--------+---------+---------+---------+---------+---------+---------+-
* Local constants (LTORG etc)
*--------+---------+---------+---------+---------+---------+---------+-
LC@CHUNK_SIZE      EQU   16
     MXEPROC END
*
*
*
PARSE_COMMAND_TEXT MXEPROC DATAREG=(R12)
*--------+---------+---------+---------+---------+---------+---------+-
* Parse the command text
*--------+---------+---------+---------+---------+---------+---------+-
     USING WA,R13
     USING MXEREQ,WA_MXEREQ_PLIST                Get parameters
     USING CPPL,R10
     DO   ,
*--------+---------+---------+---------+---------+---------+---------+-
* Generates a Parse Parameter List
*--------+---------+---------+---------+---------+---------+---------+-
       USING PPL,WA_PPL
       MVC   PPLUPT,CPPLUPT             Move in UPT address
       MVC   PPLECT,CPPLECT             move in ECT address
       MVC   PPLCBUF,CPPLCBUF           move in CBUF address
       LA    R15,WA_IOPL_ECB            load attn ECB address
       ST    R15,PPLECB                 and store in PPL
       LA    R15,WA_PDLP_ADDR           load PDL pointer address
       ST    R15,PPLANS                 and store in PPL
       LLGT  R15,=V(MXETSOPM)           load PCL address
       ST    R15,PPLPCL                 and store in PPL
*--------+---------+---------+---------+---------+---------+---------+-
* Call IKJPARS and process the results
*--------+---------+---------+---------+---------+---------+---------+-
       L     R15,CVTPTR                 load CVT address
       USING CVTMAP,R15                 address it
       L     R15,CVTPARS                load address of IKJPARS
       LAE   R1,PPL
       MXECALL (R15),AMODE=31
       ST    R15,WA_PARSE_RC
*--------+---------+---------+---------+---------+---------+---------+-
* If Parse fails, issue error message via PUTLINE and exit
*--------+---------+---------+---------+---------+---------+---------+-
       IF (CLC,WA_PARSE_RC,NE,=F'0')
         MXEMSG 0001,TYPE=PUTLINE,OUTPUT=WA_MESSAGE
         MXECALL ISSUE_PUTLINE,                                        +
               PARAM=(WA_MESSAGE),                                     +
               MF=(E,WA_MXECALL_PLIST)
         DOEXIT ,
       ENDIF
*--------+---------+---------+---------+---------+---------+---------+-
* Capture target jobname (default= caller)
*--------+---------+---------+---------+---------+---------+---------+-
       LLGT  R7,WA_PDLP_ADDR
       USING IKJPARMD,R7
       MXEMAC BLANK,WA_JOBNAME
       MXEMAC ZERO,(R14)
       IF (LT,R3,JOBNAME,NZ),AND,(ICM,R14,B'0011',JOBNAME+4,NZ)
         AHI   R14,-1
         EX    R14,LC_COPY_JOBNAME
       ELSE
         MXEMAC GET_JOBNAME,WA_JOBNAME
       ENDIF
*--------+---------+---------+---------+---------+---------+---------+-
* Capture query type (default = GETACEE)
*--------+---------+---------+---------+---------+---------+---------+-
       MXEMAC BLANK,WA_QUERY
       MXEMAC ZERO,(R14)
       IF (LT,R3,QUERYVAL,NZ),AND,(ICM,R14,B'0011',QUERYVAL+4,NZ)
         AHI   R14,-1
         EX    R14,LC_COPY_QUERY
       ELSE
         MXEMAC MOVE_2ND_LEN,WA_QUERY,=C'GETACEE'
       ENDIF
*--------+---------+---------+---------+---------+---------+---------+-
* Capture LOG option (default = NO)
*--------+---------+---------+---------+---------+---------+---------+-
       MXEMAC BLANK,WA_LOG
       MXEMAC ZERO,(R14)
       IF (LT,R3,LOGVAL,NZ),AND,(ICM,R14,B'0011',LOGVAL+4,NZ)
         AHI   R14,-1
         EX    R14,LC_COPY_LOG
       ELSE
         MXEMAC MOVE_2ND_LEN,WA_LOG,=C'NO'
       ENDIF
     ENDDO
     MXEPROC RETURN,RC=WA_PARSE_RC
*--------+---------+---------+---------+---------+---------+---------+-
* Local constants (LTORG etc)
*--------+---------+---------+---------+---------+---------+---------+-
LC_COPY_JOBNAME    MVC   WA_JOBNAME(0),0(R3)
LC_COPY_QUERY      MVC   WA_QUERY(0),0(R3)
LC_COPY_LOG        MVC   WA_LOG(0),0(R3)
     MXEPROC END
*
*
*
ISSUE_PUTLINE MXEPROC DATAREG=(R12)
*--------+---------+---------+---------+---------+---------+---------+-
* Issue a PUTLINE message to the terminal
*--------+---------+---------+---------+---------+---------+---------+-
     USING WA,R13
     USING MXEREQ,WA_MXEREQ_PLIST                Get parameters
     USING CPPL,R10
     DO   ,
*--------+---------+---------+---------+---------+---------+---------+-
* Examine passed parm and remove any unprintables from the text
*--------+---------+---------+---------+---------+---------+---------+-
       DOEXIT (LTR,R1,R1,Z)
       DOEXIT (LT,R4,0(,R1),Z)                   Any parms
       MVC   WA_PUTLINE_DESC,=F'1'               One message
       ST    R4,WA_PUTLINE_ADDR                  Remember addr
       MXEMAC ZERO,(R14)
       DOEXIT (ICM,R14,B'0011',0(R4),Z)          Length of message
       DOEXIT (CHI,R14,LE,4)                     at least 5 chars
       LAE   R1,4(,R4)                           Start of text
       AHI   R14,-4                              Remove length of RDW
       AHI   R14,-1                              -1 for EX
       EX    R14,LC_REMOVE_UNPRINT               Remove unprintables
*--------+---------+---------+---------+---------+---------+---------+-
* Generate an I/O Service Routine Parameter List and issue PUTLINE
*--------+---------+---------+---------+---------+---------+---------+-
       USING IOPL,WA_IOPL
       MVC   IOPLUPT,CPPLUPT           move in address of UPT
       MVC   IOPLECT,CPPLECT           move in address of ECT
       LA    R15,WA_IOPL_ECB           load address of attn ECB
       ST    R15,IOPLECB               and store in IOPL
       MXEMAC ZERO,WA_IOPL_ECB
       PUTLINE PARM=WA_PUTLINE_PTPB,             Output to screen      +
               OUTPUT=WA_PUTLINE_DESC,                                 +
               MF=(E,WA_IOPL)
     ENDDO
     MXEPROC RETURN
*--------+---------+---------+---------+---------+---------+---------+-
* Local constants (LTORG etc)
*--------+---------+---------+---------+---------+---------+---------+-
LC_REMOVE_UNPRINT  TR    0(0,R1),LC_CHAR_UNPRINT
                   DS    0D
LC_CHAR_UNPRINT    DS    0CL256
                   DC    X'4B4B4B4B4B4B4B4B4B4B4B4B4B4B4B4B'
                   DC    X'4B4B4B4B4B4B4B4B4B4B4B4B4B4B4B4B'
                   DC    X'4B4B4B4B4B4B4B4B4B4B4B4B4B4B4B4B'
                   DC    X'4B4B4B4B4B4B4B4B4B4B4B4B4B4B4B4B'
                   DC    X'404142434445464748494A4B4C4D4E4F'
                   DC    X'505152535455565758595A5B5C5D5E5F'
                   DC    X'606162636465666768696A6B6C6D6E6F'
                   DC    X'707172737475767778797A7B7C7D7E7F'
                   DC    X'808182838485868788898A8B8C8D8E8F'
                   DC    X'909192939495969798999A9B9C9D9E9F'
                   DC    X'A0A1A2A3A4A5A6A7A8A9AAABACADAEAF'
                   DC    X'B0B1B2B3B4B5B6B7B8B9BABBBCBDBEBF'
                   DC    X'C0C1C2C3C4C5C6C7C8C94BCBCCCDCECF'
                   DC    X'D0D1D2D3D4D5D6D7D8D9DADBDCDDDEDF'
                   DC    X'E0E1E2E3E4E5E6E7E8E9EAEBECEDEEEF'
                   DC    X'F0F1F2F3F4F5F6F7F8F9FAFBFCFDFE4B'
                   DS    0D
     MXEPROC END
*
*
*
REPORT_MXEREQ MXEPROC DATAREG=(R12)
*--------+---------+---------+---------+---------+---------+---------+-
* Report the success/failure of the MXEREQ service
*--------+---------+---------+---------+---------+---------+---------+-
     USING WA,R13
     USING MXEREQ,WA_MXEREQ_PLIST                Get parameters
     DO   ,
       MXEMAC BLANK,WA_MESSAGE_SRV
       SELECT CLI,MXEREQ_REQ,EQ
         WHEN (MXEREQ@REQ_QUERY)
           MXEMAC MOVE_2ND_LEN,WA_MESSAGE_SRV,=C'QUERY'
         WHEN (MXEREQ@REQ_DATA)
           MXEMAC MOVE_2ND_LEN,WA_MESSAGE_SRV,=C'DATA'
         WHEN (MXEREQ@REQ_LOGDATA)
           MXEMAC MOVE_2ND_LEN,WA_MESSAGE_SRV,=C'LOGDATA'
         WHEN (MXEREQ@REQ_GETTOKEN)
           MXEMAC MOVE_2ND_LEN,WA_MESSAGE_SRV,=C'GETTOKEN'
         WHEN (MXEREQ@REQ_PUTTOKEN)
           MXEMAC MOVE_2ND_LEN,WA_MESSAGE_SRV,=C'PUTTOKEN'
         OTHRWISE
           MXEMAC MOVE_2ND_LEN,WA_MESSAGE_SRV,=C'UNKNOWN'
       ENDSEL
       MXEMAC X2C,WA_MESSAGE_RC,MXEREQ_RETINFO_RC
       MXEMAC X2C,WA_MESSAGE_RSN,MXEREQ_RETINFO_RSN
       MXEMSG 0002,TYPE=PUTLINE,                                       +
               PARAM=(WA_MESSAGE_SRV,                                  +
               WA_MESSAGE_RC,                                          +
               WA_MESSAGE_RSN),                                        +
               OUTPUT=WA_MESSAGE
       MXECALL ISSUE_PUTLINE,                                          +
               PARAM=WA_MESSAGE,                                       +
               MF=(E,WA_MXECALL_PLIST)
     ENDDO
     MXEPROC RETURN,RC=MXEREQ_RETINFO_RC,RSN=MXEREQ_RETINFO_RSN
*--------+---------+---------+---------+---------+---------+---------+-
* Local constants (LTORG etc)
*--------+---------+---------+---------+---------+---------+---------+-
     MXEPROC END
*
*
*
*--------+---------+---------+---------+---------+---------+---------+-
*--------+---------+---------+---------+---------+---------+---------+-
* DSECTS
*--------+---------+---------+---------+---------+---------+---------+-
*--------+---------+---------+---------+---------+---------+---------+-
*
*                    SYSSTATE AMODE64=YES
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
WA_PARSE_RC          DS    F                     Parse RC
WA_BYTES_DUMPED      DS    F
                     DS    0D
WA_PUTLINE_PTPB      DS    XL12
WA_PUTLINE_DESC      DS    F
WA_PUTLINE_ADDR      DS    A
                     DS    0D
WA_WORK_D            DS    D
                     DS    0D
WA_TOKEN             DS    XL16                  Token for MXEGBVT
WA_JOBNAME           DS    CL8                   Target jobname
WA_QUERY             DS    CL8                   Query
WA_LOG               DS    CL3                   Query
                     DS    0D
WA_MESSAGE           DS    XL80                  Message to PUTLINE
                     DS    0D
WA_MESSAGE_SRV       DS    CL8                   Message overlays
WA_MESSAGE_RC        DS    CL8
WA_MESSAGE_RSN       DS    CL8
WA_MESSAGE_HEX       DS    0C
WA_MESSAGE_W1        DS    CL8
WA_MESSAGE_W2        DS    CL8
WA_MESSAGE_W3        DS    CL8
WA_MESSAGE_W4        DS    CL8
WA_MESSAGE_CHUNK     DS    XL(LC@CHUNK_SIZE)
                     DS    0D
WA_CPPL_ADDR         DS    A
WA_PDLP_ADDR         DS    A
WA_IOPL_ECB          DS    XL4
WA_IOPL_PARM         DS    XL12
                     DS    0D
WA_IOPL              DS    XL(IOPL@LEN)
WA_PPL               DS    XL(PPL@LEN)
                     DS    0D
WA_MXECALL_PLIST     DS    8A
                     DS    0D
                     MXEREQ MF=(L,WA_MXEREQ_PLIST)
                     DS    0D
                     MXECATCH MF=(L,WA_MXECATCH_PLIST)
                     DS    0D
WA_ANSLEN            DS    F                     Buffer len
WA_ANSAREA           DS    XL4096                Buffer area
                     DS    0D
WA@LEN               EQU   *-WA
WA@SP                EQU   50
*
*
         MXEGBVT
         MXEREQ   DSECT=YES
         MXEMSGDF DSECT=YES
*
         CVT      DSECT=YES
         IEANTASM
         IHASAVER
         IHAECB
*
         IKJUPT
         IKJCPPL
         IKJIOPL
IOPL@LEN EQU   *-IOPL
         IKJPPL
PPL@LEN  EQU   *-PPL
*
         MXECATCH DSECT=YES
         MXEMAC   REG_EQU
*
*--------+---------+---------+---------+---------+---------+---------+-
* MXETSO COMMAND SYNTAX DEFINITIONS
*
* MXETSO jobname QUERY(query_type) LOG(YES/NO)
*                Q(query_type)
*
*--------+---------+---------+---------+---------+---------+---------+-
MXETSO       CSECT
MXETSOPM     IKJPARM
JOBNAME      IKJPOSIT JOBNAME,                                         +
               PROMPT='JOBNAME'
QUERY        IKJKEYWD
             IKJNAME  'QUERY',                                         +
               SUBFLD=QUERYSUB,                                        +
               ALIAS='Q'
LOG          IKJKEYWD
             IKJNAME  'LOG',                                           +
               SUBFLD=LOGSUB
QUERYSUB     IKJSUBF
QUERYVAL     IKJIDENT 'VALUE',                                         +
               MAXLNTH=8,                                              +
               FIRST=ALPHA,                                            +
               OTHER=ALPHA,                                            +
               DEFAULT='GETACEE'
LOGSUB       IKJSUBF
LOGVAL       IKJIDENT 'VALUE',                                         +
               MAXLNTH=3,                                              +
               FIRST=ALPHA,                                            +
               OTHER=ALPHA,                                            +
               DEFAULT='NO '
             IKJENDP
         END
