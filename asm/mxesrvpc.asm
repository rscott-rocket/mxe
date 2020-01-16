MXESRVPC TITLE 'MXE - SERVER SYSTEM-LX PC-SS ROUTINE'
*--------+---------+---------+---------+---------+---------+---------+-
* Name            : MXESRVPC
*
* Function        : MXE SystemLX Space Switch PC routine
*
*                   Parameter list passed to this routine is mapped
*                   by the MXEREQ structure.
*
*                   Provides the following services :
*
*                   (o) QUERY
*                       Schedule an SRB into a nominated foreign
*                       jobname and copy discovered information back
*                       to the caller. The information passed back
*                       depends on the contents of the MXEREQ_TYPE
*                       field of the MXEREQ parameter list.
*                   (o) DATA
*                       Copy service-provided data into one of MXE's
*                       64-bit bufferpools. This request must be
*                       correlated to an originating REQ=QUERY
*                       service so that the data payload can be
*                       returned to the original caller.
*                       The REQ=DATA service is used in the SRB
*                       (MXESRBRQ) to copied discovered data back
*                       to MXE on behalf of the REQ=QUERY caller.
*                   (o) LOGDATA
*                       Copy caller provided data into one of MXE's
*                       64-bit bufferpools and added to the LOGDATA
*                       subtask (MXESRVLD) data queue to be
*                       asynchronously drained.
*
*
* Register Usage  :
* r1  - paramter passed : MXEREQ
* r2  -
* r3  -
* r4  -
* r5  -
* r6  -
* r7  -
* r8  - Storage in SASN
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
MXESRVPC MXEMAIN DATAREG=(R12),BAKR=NO,PARMS=(R8)
*--------+---------+---------+---------+---------+---------+---------+-
* Establish parameters
*--------+---------+---------+---------+---------+---------+---------+-
     STORAGE OBTAIN,LENGTH=WA@LEN,                                     +
               SP=WA@SP,KEY=WA@KEY,                                    +
               ADDR=(R13),                                             +
               COND=NO
     USING WA,R13
     MXEMAC INIT,WA,LENGTH==AL4(WA@LEN)      Clear
     MXEMAC SET_ID,WA                        Init block
     USING SAVF4SA,WA_SAVEAREA
     MVC   SAVF4SAID,=A(SAVF4SAID_VALUE)
*--------+---------+---------+---------+---------+---------+---------+-
* We can use the common recovery routine as our ARR
*--------+---------+---------+---------+---------+---------+---------+-
     MXECATCH ON,RETRY=MXESRVPC_RECOVERY,                              +
               MODE=ARR,                                               +
               MF=(E,WA_MXECATCH_PLIST)
CLNT USING MXEREQ,R8
*--------+---------+---------+---------+---------+---------+---------+-
* Main execution shell
*--------+---------+---------+---------+---------+---------+---------+-
     DO    ,
       MXEMAC ASC,AR                             AR mode
       LAM   R8,R8,=A(AR@SEC)                    Set to SASN
       LAE   R1,CLNT.MXEREQ                      Addr of caller MXEREQ
       ST    R1,WA_CALLER_MXEREQ                 Remember
*--------+---------+---------+---------+---------+---------+---------+-
* Sniff the PSW from the stack to get the callers key - we are taking
* care here as we are dealing with the outside world. All movement of
* data between MXE and caller will be performed using MVCDK/MVCSK
*--------+---------+---------+---------+---------+---------+---------+-
       MXEMAC GET_PSW_KEY,KEY=WA_CALLER_KEY
       MXEMAC MOVE_SRC_KEY,WA_MXEREQ,CLNT.MXEREQ,                      +
               LENGTH==AL4(L'WA_MXEREQ),                               +
               KEY=WA_CALLER_KEY
       DROP  CLNT                                Remove interest
*--------+---------+---------+---------+---------+---------+---------+-
* We have taken a copy of the caller MXEREQ into our own working
* storage to guarantee that the contents do not change.
*--------+---------+---------+---------+---------+---------+---------+-
       USING MXEREQ,WA_MXEREQ                    Ref authorized copy
*--------+---------+---------+---------+---------+---------+---------+-
* Validate the basic contents of MXEREQ to ensure that required parms
* have been specified for each service and that there are no silly
* values.
*--------+---------+---------+---------+---------+---------+---------+-
       MXECALL VALIDATE_PARAMETERS,                                    +
               RC=WA_RETINFO_RC,                                       +
               RSN=WA_RETINFO_RSN
       DOEXIT (LTR,R15,R15,NZ)                   Give up if bad
*--------+---------+---------+---------+---------+---------+---------+-
* Get the MXEGBVT from the system level name/token
*--------+---------+---------+---------+---------+---------+---------+-
       MXEMAC SET_RC,WA_RETINFO_RC,MXEEQU@RC_SEVERE
       MXEMAC SET_RSN,WA_RETINFO_RSN,MXEEQU@RSN_BAD_ENV
       MXEREQ  REQ=GETTOKEN,                     Get MXEGBVT anchor    +
               TOKEN=WA_TOKEN,                                         +
               RC=WA_RC,                                               +
               MF=(E,WA_MXEREQ_INTL)
       DOEXIT (CLC,WA_RC,NE,=F'0')               Not there?
       DOEXIT (LTG,R11,WA_TOKEN_ADDR,Z)          No address ?
       USING MXEGBVT,R11
       MXEMAC VER_ID,MXEGBVT                     bad-eyecatch?
       DOEXIT (LTR,R15,R15,NZ)
*--------+---------+---------+---------+---------+---------+---------+-
* If we get here, the MXE environment looks OK.
*--------+---------+---------+---------+---------+---------+---------+-
* Examine the request type and decide what to do
*--------+---------+---------+---------+---------+---------+---------+-
       SELECT CLI,MXEREQ_REQ,EQ
         WHEN (MXEREQ@REQ_QUERY)
           MXECALL PROCESS_QUERY_REQUEST,        SRB QUERY             +
               RC=WA_RETINFO_RC,                                       +
               RSN=WA_RETINFO_RSN,                                     +
               OUTPUT=WA_RETINFO_OUTPUT
         WHEN (MXEREQ@REQ_DATA)                  "PUT" DATA
           MXECALL PROCESS_DATA_REQUEST,                               +
               RC=WA_RETINFO_RC,                                       +
               RSN=WA_RETINFO_RSN
         WHEN (MXEREQ@REQ_LOGDATA)               "LOG" DATA
           USING MXEREQCI,MXEREQ_CORID           Set CORID = self
           MVC   MXEREQCI_STCK,MXEREQ_STCK
           LAE   R6,MXEREQ
           LLGT  R9,MXEGBVT_CORID_ARRAY          Add to CORID array
CORID      USING MXEARRAY,R9
           MXEARRAY REQ=PUSH,                                          +
               ITEM=(R6),                                              +
               STCK=MXEREQCI_STCK,                                     +
               INDEX=MXEREQCI_INDEX,                                   +
               ARRAY=CORID.MXEARRAY,                                   +
               MF=(E,WA_MXEARRAY_PLIST)
           MXECALL PROCESS_DATA_REQUEST,         Perform DATA call     +
               RC=WA_RETINFO_RC,                                       +
               RSN=WA_RETINFO_RSN
           DOEXIT (LTR,R15,R15,NZ)               Data in cell?
           MXECALL QUEUE_LOGDATA,                Add to queue          +
               RC=WA_RETINFO_RC,                                       +
               RSN=WA_RETINFO_RSN
         OTHRWISE
           MXEMAC SET_RC,WA_RETINFO_RC,MXEEQU@RC_ERROR
           MXEMAC SET_RSN,WA_RETINFO_RSN,MXEEQU@RSN_BAD_REQ
       ENDSEL
     ENDDO
*--------+---------+---------+---------+---------+---------+---------+-
* Termination (normal and abnormal)
* Note that MXECATCH will override the RC+RSN only *if* the recovery
* routine was invoked.
*--------+---------+---------+---------+---------+---------+---------+-
     MXECATCH OFF,LABEL=MXESRVPC_RECOVERY,MODE=ARR,                    +
               RC=WA_RETINFO_RC,RSN=WA_RETINFO_RSN,                    +
               MF=(E,WA_MXECATCH_PLIST)
     MXEMAIN RETINFO,                                                  +
               RC=WA_RETINFO_RC,                                       +
               RSN=WA_RETINFO_RSN,                                     +
               OUTPUT=WA_RETINFO_OUTPUT
     STORAGE RELEASE,LENGTH=WA@LEN,                                    +
               ADDR=(R13),                                             +
               SP=WA@SP,KEY=WA@KEY,                                    +
               COND=NO
     MXEMAIN RETURN
*--------+---------+---------+---------+---------+---------+---------+-
* Mainline constants
*--------+---------+---------+---------+---------+---------+---------+-
     MXEMAIN END
*
*
*--------+---------+---------+---------+---------+---------+---------+-
*--------+---------+---------+---------+---------+---------+---------+-
* Subroutines
*--------+---------+---------+---------+---------+---------+---------+-
*--------+---------+---------+---------+---------+---------+---------+-
*
PROCESS_QUERY_REQUEST MXEPROC DATAREG=(R12)
*--------+---------+---------+---------+---------+---------+---------+-
* Schedule SRB into target address space to capture data
*--------+---------+---------+---------+---------+---------+---------+-
     USING WA,R13
     USING MXEGBVT,R11
     USING MXEREQ,WA_MXEREQ
     DO   ,
*--------+---------+---------+---------+---------+---------+---------+-
* Locate ASCB for the specified JOBNAME - use first found logic
*
* Obviously any production version of code needs to use the ASID as
* well as the jobname, but this is just example code.
*--------+---------+---------+---------+---------+---------+---------+-
       MXEMAC SET_RC,WA_RC,MXEEQU@RC_WARNING
       MXEMAC SET_RSN,WA_RSN,MXEEQU@RSN_NOT_FOUND
       MXEMAC ZERO_AR,R14,R1
       MXEMAC GET_ASCB,MXEREQ_JOBNAME
       DOEXIT (LTR,R15,R15,NZ)
       LGR   R4,R1
       USING ASCB,R4
*--------+---------+---------+---------+---------+---------+---------+-
* Construct the MXEREQPM block to pass to SRB as parameter
* (o) MXEREQPM resides in ECSA
* (o) As MXEREQPM is passed as parm to SRB, it must be 31-bit
*--------+---------+---------+---------+---------+---------+---------+-
       STORAGE OBTAIN,                                                 +
               LENGTH=MXEREQPM@LEN,                                    +
               SP=MXEREQPM@SP,KEY=MXEREQPM@KEY,                        +
               ADDR=(R7),                                              +
               COND=NO
       USING MXEREQPM,R7
       MXEMAC INIT,MXEREQPM,LENGTH==AL4(MXEREQPM@LEN)
       MXEMAC SET_ID,MXEREQPM
       MVC   MXEREQPM_JOBNAME,MXEREQ_JOBNAME     Jobname
       MVC   MXEREQPM_TYPE,MXEREQ_TYPE           Query type
       LAE   R1,MXEGBVT                          Anchor MXEGBVT
       STG   R1,MXEREQPM_MXEGBVT
       LAE   R1,ASCB                             ASCB address
       ST    R1,MXEREQPM_ASCB
       LLGT  R14,ASCBASSB                        STOKEN
       MVC   MXEREQPM_STOKEN,ASSBSTKN-ASSB(R14)
       MXEMAC ZERO,MXEREQ_MXEREQDA               Remove any caller data
*--------+---------+---------+---------+---------+---------+---------+-
* Set a correlation ID for this request
*--------+---------+---------+---------+---------+---------+---------+-
       USING MXEREQCI,MXEREQPM_CORID
       MVC   MXEREQCI_STCK,MXEREQ_STCK
       LAE   R6,MXEREQ
       LLGT  R9,MXEGBVT_CORID_ARRAY
CORID  USING MXEARRAY,R9
       MXEARRAY REQ=PUSH,                                              +
               ITEM=(R6),                                              +
               STCK=MXEREQCI_STCK,                                     +
               INDEX=MXEREQCI_INDEX,                                   +
               ARRAY=CORID.MXEARRAY,                                   +
               MF=(E,WA_MXEARRAY_PLIST)
*--------+---------+---------+---------+---------+---------+---------+-
* Setup various RC+RSN fields for sync SRB
*--------+---------+---------+---------+---------+---------+---------+-
       LAE   R1,MXEREQPM_DISPATCH_RC             Dispatch
       ST    R1,WA_DISPATCH_RC_ADDR
       LAE   R1,MXEREQPM_SCHEDULE_RC             Schedule
       ST    R1,WA_SCHEDULE_RC_ADDR
       LAE   R1,MXEREQPM_RC                      SRB R15
       ST    R1,WA_SRB_RC_ADDR
       LAE   R1,MXEREQPM_RSN                     SRB R0
       ST    R1,WA_SRB_RSN_ADDR
*--------+---------+---------+---------+---------+---------+---------+-
* Schedule SRB into target address space
* (o) MXESRBRQ is in the MXE LPA function pack
* (o) We use the STOKEN for the address space
* (o) The MXEREQPM block is passed as parm to SRB
*--------+---------+---------+---------+---------+---------+---------+-
       IEAMSCHD EPADDR=MXEGBVT_MXESRBRQ,                               +
               ENV=STOKEN,                                             +
               TARGETSTOKEN=MXEREQPM_STOKEN,                           +
               KEYVALUE=INVOKERKEY,                                    +
               FRRADDR=MXEGBVT_FRR,                                    +
               PRIORITY=LOCAL,                                         +
               LLOCK=NO,                                               +
               PARM=MXEREQPM_MXEREQPM_31,                              +
               SYNCH=YES,                                              +
               SYNCHCOMPADDR=WA_DISPATCH_RC_ADDR,                      +
               SYNCHCODEADDR=WA_SRB_RC_ADDR,                           +
               SYNCHRSNADDR=WA_SRB_RSN_ADDR,                           +
               RETCODE=WA_SCHEDULE_RC_ADDR,                            +
               PLISTVER=MAX,                                           +
               MF=(E,WA_IEAMSCHD_PLIST,COMPLETE)
*--------+---------+---------+---------+---------+---------+---------+-
*  On return from SRB scheduling MXEREQPM_DISPATCH_RC contains :
*
*  00 Meaning: Successful completion.
*  04 Meaning: Warning. The enclave token is not valid. The enclave
*     token specified on the ENCLAVETOKEN parameter has been reused
*     for a new enclave. The SRB was not scheduled.
*  08 Meaning: Program error. The client STOKEN address space has
*     failed. The SRB was not scheduled.
*  0C Meaning: Program error. The purge STOKEN address space has
*     failed.  The SRB was not scheduled.
*  10 Meaning: Program error. The target STOKEN address space has
*     failed. The SRB was not scheduled.
*  1C Meaning: Program error. A SYNCH=YES SRB was not scheduled or did
*     not complete successfully. The values returned on SYNCHCOMPADDR,
*     SYNCHCODEADDR, and SYNCHRSNADDR contain additional information.
*
*  On return from SRB completion
*
*  Code in MXEREQPM_DISPATCH_RC means :
*
*   0   SRB completed successfully.
*   8   SRB ENDed abnormally; there is an associated reason code.
*  12   SRB ENDed abnormally; there is no associated reason code.
*  16   PURGEDQ processing purged the SRB.
*  20   SRB state is undetermined. It was dispatched but did not
*       complete.  A probable cause is address space termination or an
*       error in the dynamic address translation (DAT) process.
*  24   SRB was not scheduled; SYNCHCODEADDR contains the return code
*       from the SUSPEND service.
*  28   SRB was not scheduled; SYNC
*
*  Code in MXEREQPM_RC means :
*
*   0   Contents of GPR 15 when the SRB completed.
*   8   ABEND code in the same format as field SDWAABCC in the SDWA.
*  12   ABEND code in the same format as field SDWAABCC in the SDWA.
*  16   X'FFFFFFFF' (-1), indicating that there is no meaningful value
*       to return.
*  20   X'FFFFFFFF' (-1), indicating that there is no meaningful value
*       to return.
*  24   Return code from the SUSPEND service. The SRB was not scheduled
*       because this work unit could not be successfully suspENDed.
*  28   ABEND code from the SUSPEND service. The SRB was not scheduled
*       because this work unit could not be successfully suspENDed.
*
*  Code in MXEREQPM_RSN means :
*
*   0   Contents of GPR 0 when the SRB completed.
*   8   Reason code associated with an ABEND code.
*  12   X'FFFFFFFF' (-1), indicating that there is no meaningful value
*       to return.
*  16   X'FFFFFFFF' (-1), indicating that there is no meaningful value
*       to return.
*  20   X'FFFFFFFF' (-1), indicating that there is no meaningful value
*       to return.
*  24   X'FFFFFFFF' (-1), indicating that there is no meaningful value
*       to return.
*  28   Reason code associated with the ABEND code issued during an
*       unsuccessful attempt to suspEND the current work unit.
*
*--------+---------+---------+---------+---------+---------+---------+-
       MVC   WA_RC,MXEREQPM_RC                   Prime RC+RSN
       MVC   WA_RSN,MXEREQPM_RSN
*--------+---------+---------+---------+---------+---------+---------+-
* Copy results back to caller ANSAREA
* (o) If we have a payload (MXEREQDA) we reload the caller ANSAREA
*     address and copy it back using MVCDK
* (o) If no payload and SRB RC=0, we set a warning RC and a RSN of
*     "empty".
* (o) Otherwise we pass back the SRB RC=RSN
*--------+---------+---------+---------+---------+---------+---------+-
       MXEMAC AMODE,64
       LG    R5,MXEREQ_MXEREQDA
       USING MXEREQDA,R5
       IF (LTG,R5,MXEREQ_MXEREQDA,NZ)
         LG    R8,MXEREQ_ANSAREA
         LAM   R8,R8,=A(AR@SEC)                    Set to SASN
         MXEMAC MOVE_DEST_KEY,(R8),MXEREQDA_DATA,                      +
               LENGTH=MXEREQDA_DATA_LEN,                               +
               KEY=WA_CALLER_KEY
         MVC   WA_OUTPUT,MXEREQDA_DATA_LEN
         IARCP64 REQUEST=FREE,CELLNAME=(R5),REGS=SAVE
       ELSEIF (CLC,WA_RC,EQ,=F'0')
         MXEMAC SET_RC,WA_RC,MXEEQU@RC_WARNING
         MXEMAC SET_RSN,WA_RSN,MXEEQU@RSN_EMPTY
         MXEMAC ZERO,WA_OUTPUT
       ELSE
         MXEMAC ZERO,WA_OUTPUT
       ENDIF
*--------+---------+---------+---------+---------+---------+---------+-
* Release the MXEREQPM block
*--------+---------+---------+---------+---------+---------+---------+-
       STORAGE RELEASE,                                                +
               LENGTH=MXEREQPM@LEN,                                    +
               SP=MXEREQPM@SP,KEY=MXEREQPM@KEY,                        +
               ADDR=(R7),                                              +
               COND=NO
       MXEMAC AMODE,31
     ENDDO
     MXEPROC RETURN,RC=WA_RC,RSN=WA_RSN,OUTPUT=WA_OUTPUT
*--------+---------+---------+---------+---------+---------+---------+-
* Local constants (LTORG etc)
*--------+---------+---------+---------+---------+---------+---------+-
     MXEPROC END
*
*
*
PROCESS_DATA_REQUEST MXEPROC DATAREG=(R12)
*--------+---------+---------+---------+---------+---------+---------+-
* Take the payload from the caller and copy to correct cell pool
* (o) Ensure that the correlation token is valid. This should match
*     the values established when the REQ=QUERY service was being
*     processed. If the token is not valid, we throw away the request.
*--------+---------+---------+---------+---------+---------+---------+-
     USING WA,R13
     USING MXEGBVT,R11
     USING MXEREQ,WA_MXEREQ
     DO   ,
       MXEMAC AMODE,64
*--------+---------+---------+---------+---------+---------+---------+-
* Extract the original QUERY MXEREQ using the correlation ID generated
* by MXEARRAY PUSH. The register specified on the ITEM will contain
* the MXEREQ address (or zero if not found).
*--------+---------+---------+---------+---------+---------+---------+-
       USING MXEREQCI,MXEREQ_CORID
       LLGT  R9,MXEGBVT_CORID_ARRAY
CORID  USING MXEARRAY,R9
       MXEARRAY REQ=POP,                                               +
               ITEM=(R6),                                              +
               STCK=MXEREQCI_STCK,                                     +
               INDEX=MXEREQCI_INDEX,                                   +
               ARRAY=CORID.MXEARRAY,                                   +
               MF=(E,WA_MXEARRAY_PLIST)
ORIG   USING MXEREQ,R6
       MXEMAC SET_RC,WA_RC,MXEEQU@RC_ERROR
       MXEMAC SET_RSN,WA_RSN,MXEEQU@RSN_BAD_CORID
       DOEXIT (LTGR,R6,R6,Z)
*--------+---------+---------+---------+---------+---------+---------+-
* Corid is good, so now we loop thru the bufferpools hunting for
* one that is the correct size for the payload.
*--------+---------+---------+---------+---------+---------+---------+-
       LAE   R4,MXEGBVT_BPOOLS                   Buffer pool start
       USING MXEGBVT_BP,R4
       MXEMAC SET_RSN,WA_RSN,MXEEQU@RSN_BAD_LENGTH
       MXEMAC ZERO,(R5)                          Cell address
       DO FROM=(R3,=AL4(MXEGBVT@BPOOLS_NUM))
         IF (CLC,MXEREQ_ANSLEN,LE,MXEGBVT_BP_SIZE)
           IARCP64 REQUEST=GET,                                        +
               INPUT_CPID=MXEGBVT_BP_CPID,                             +
               EXPAND=YES,                                             +
               FAILMODE=ABEND,                                         +
               REGS=SAVE,                                              +
               TRACE=NO
           LGR   R5,R1                           We have a cell
           DOEXIT ,                              Stop looking
         ENDIF
         LAE   R4,MXEGBVT_BP@LEN(,R4)            Next buffer pool
       ENDDO
*--------+---------+---------+---------+---------+---------+---------+-
* If R5 is zero, then we failed to get a cell
*--------+---------+---------+---------+---------+---------+---------+-
       DOEXIT (LTGR,R5,R5,Z)                     No cell gotten
       USING MXEREQDA,R5                         Payload header
*--------+---------+---------+---------+---------+---------+---------+-
* Init the payload header
* (o) Copy the CPID (for debug purposes)
* (o) Set the data length and offset from start of header
* (o) Copy the caller provided payload into the cell immediately
*     after the end of the header section using MVCSK.
* (o) Note that because we use MVCSK, the caller *must* provide
*     payloads in storage whose key matches their execution key.
*--------+---------+---------+---------+---------+---------+---------+-
       MXEMAC SET_ID,MXEREQDA
       MVC   MXEREQDA_CPID,MXEGBVT_BP_CPID
       MVC   MXEREQDA_DATA_LEN,MXEREQ_ANSLEN
       MVC   MXEREQDA_DATA_OFF,=AL4(MXEREQDA@DATA_OFF)
       LG    R8,MXEREQ_ANSAREA
       LAM   R8,R8,=A(AR@SEC)                    Set to SASN
       MXEMAC MOVE_SRC_KEY,MXEREQDA_DATA,(R8),                         +
               LENGTH=MXEREQDA_DATA_LEN,                               +
               KEY=WA_CALLER_KEY
       LAE   R1,MXEREQDA                         Remember MXEREQDA
       STG   R1,ORIG.MXEREQ_MXEREQDA             Store in request
       MXEMAC ZERO,WA_RC
       MXEMAC ZERO,WA_RSN
     ENDDO
     MXEMAC AMODE,31
     MXEPROC RETURN,RC=WA_RC,RSN=WA_RSN
*--------+---------+---------+---------+---------+---------+---------+-
* Local constants (LTORG etc)
*--------+---------+---------+---------+---------+---------+---------+-
     MXEPROC END
*
*
*
QUEUE_LOGDATA MXEPROC DATAREG=(R12)
*--------+---------+---------+---------+---------+---------+---------+-
* Take the data payload and queue up for the MXESRVLD task to
* process.
*--------+---------+---------+---------+---------+---------+---------+-
     USING WA,R13
     USING MXEGBVT,R11
     USING MXEREQ,WA_MXEREQ
     MXEMAC AMODE,64
     DO   ,
       MXEMAC SET_RC,WA_RC,MXEEQU@RC_WARNING
       MXEMAC SET_RSN,WA_RSN,MXEEQU@RSN_NO_DATA
       DOEXIT (LTG,R5,MXEREQ_MXEREQDA,Z)          Any payload?
       USING MXEREQDA,R5
       MXEMAC ZERO,MXEREQDA_NEXT                  Next is zero
       MXEQUEUE REQ=PUSH_TAIL,                                         +
               ITEM=MXEREQDA,                                          +
               NEXT_OFFSET=MXEREQDA_NEXT-MXEREQDA,                     +
               QUEUE=MXEGBVT_LOGDATA_QUEUE,                            +
               MF=(E,WA_MXEQUEUE_PLIST)
       MXEMAC ZERO,WA_RC
       MXEMAC ZERO,WA_RSN
     ENDDO
     MXEMAC AMODE,31
     MXEPROC RETURN,RC=WA_RC,RSN=WA_RSN
*--------+---------+---------+---------+---------+---------+---------+-
* Local constants (LTORG etc)
*--------+---------+---------+---------+---------+---------+---------+-
     MXEPROC END
*
*
*
VALIDATE_PARAMETERS MXEPROC DATAREG=(R12)
*--------+---------+---------+---------+---------+---------+---------+-
* Validate the caller provided parameters
* Note that we are using the copy taken to our working storage
*--------+---------+---------+---------+---------+---------+---------+-
     USING WA,R13
     USING MXEREQ,WA_MXEREQ
     DO   ,
*--------+---------+---------+---------+---------+---------+---------+-
*--------+---------+---------+---------+---------+---------+---------+-
* Common validation
*--------+---------+---------+---------+---------+---------+---------+-
*--------+---------+---------+---------+---------+---------+---------+-
       MXEMAC SET_RC,WA_RC,MXEEQU@RC_ERROR
*--------+---------+---------+---------+---------+---------+---------+-
* ANSAREA must be non-zero
*--------+---------+---------+---------+---------+---------+---------+-
       MXEMAC SET_RSN,WA_RSN,MXEEQU@RSN_BAD_ANSAREA
       DOEXIT (CLC,MXEREQ_ANSAREA,EQ,=AD(0))
*--------+---------+---------+---------+---------+---------+---------+-
* ANSLEN must be non-zero and less than 4K
*--------+---------+---------+---------+---------+---------+---------+-
       MXEMAC SET_RSN,WA_RSN,MXEEQU@RSN_BAD_ANSLEN
       DOEXIT (CLC,MXEREQ_ANSLEN,EQ,=F'0')
       DOEXIT (CLC,MXEREQ_ANSLEN,GT,=AL4(MXEREQ@ANSLEN_MAX))
*--------+---------+---------+---------+---------+---------+---------+-
*--------+---------+---------+---------+---------+---------+---------+-
* Request specific validation
*--------+---------+---------+---------+---------+---------+---------+-
*--------+---------+---------+---------+---------+---------+---------+-
       SELECT CLI,MXEREQ_REQ,EQ
         WHEN (MXEREQ@REQ_QUERY)
*--------+---------+---------+---------+---------+---------+---------+-
* Type must be non-blank and non-zero
*--------+---------+---------+---------+---------+---------+---------+-
           MXEMAC SET_RSN,WA_RSN,MXEEQU@RSN_BAD_TYPE
           DOEXIT (CLI,MXEREQ_TYPE,EQ,X'00')
           DOEXIT (CLI,MXEREQ_TYPE,EQ,X'40')
*--------+---------+---------+---------+---------+---------+---------+-
* Jobname must be non-blank and non-zero
*--------+---------+---------+---------+---------+---------+---------+-
           MXEMAC SET_RSN,WA_RSN,MXEEQU@RSN_BAD_JOBNAME
           DOEXIT (CLI,MXEREQ_JOBNAME,EQ,X'00')
           DOEXIT (CLI,MXEREQ_JOBNAME,EQ,X'40')
         WHEN (MXEREQ@REQ_DATA)
*--------+---------+---------+---------+---------+---------+---------+-
* Token must be non-zero
*--------+---------+---------+---------+---------+---------+---------+-
           MXEMAC SET_RSN,WA_RSN,MXEEQU@RSN_BAD_CORID
           DOEXIT (CLC,MXEREQ_CORID,EQ,=XL16'00')
         WHEN (MXEREQ@REQ_LOGDATA)
         OTHRWISE
*--------+---------+---------+---------+---------+---------+---------+-
* Do not recognise the request type
*--------+---------+---------+---------+---------+---------+---------+-
           MXEMAC SET_RSN,WA_RSN,MXEEQU@RSN_BAD_REQ
       ENDSEL
*--------+---------+---------+---------+---------+---------+---------+-
* All OK
*--------+---------+---------+---------+---------+---------+---------+-
       MXEMAC ZERO,WA_RC
       MXEMAC ZERO,WA_RSN
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
WA_CALLER_MXEREQ     DS    A                     Caller MXEREQ
WA_CALLER_KEY        DS    F                     Caller KEY
WA_ADDR_KEY          DS    F
WA_RC                DS    F
WA_RSN               DS    F
WA_OUTPUT            DS    F
WA_RETINFO           DS    0F
WA_RETINFO_RC        DS    F
WA_RETINFO_RSN       DS    F
WA_RETINFO_OUTPUT    DS    F
                     DS    0D
WA_TOKEN             DS    0XL16
WA_TOKEN_ADDR        DS    AD
WA_TOKEN_SEQ         DS    XL8
                     DS    0D
WA_MXEREQ            DS    XL(MXEREQ@LEN)
WA_MXEREQ_INTL       DS    XL(MXEREQ@LEN)
                     DS    0D
WA_DISPATCH_RC_ADDR  DS    A
WA_SCHEDULE_RC_ADDR  DS    A
WA_SRB_RC_ADDR       DS    A
WA_SRB_RSN_ADDR      DS    A
                     DS    0D
                     IEAMSCHD PLISTVER=MAX,MF=(L,WA_IEAMSCHD_PLIST)
                     DS    0D
                     MXEARRAY MF=(L,WA_MXEARRAY_PLIST)
                     DS    0D
                     MXEQUEUE MF=(L,WA_MXEQUEUE_PLIST)
                     DS    0D
                     MXECATCH MF=(L,WA_MXECATCH_PLIST)
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
         IEANTASM
         CVT      DSECT=YES
         IHAASVT
         IHAASCB
         IHAASSB
*
         MXEMAC REG_EQU
         END
