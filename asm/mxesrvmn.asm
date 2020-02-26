MXESRVMN TITLE 'MXE - SERVER MAIN TASK'
*--------+---------+---------+---------+---------+---------+---------+-
* Name            : MXESRVMN
*
* Function        : MXE Server Main Task
*
*                   (o) Obtain global anchor called "MXEGBVT"
*
*                   (o) Unpack the MXE LPA module MXEINLPA and
*                       store important addresses in the MXEGBVT
*
*                   (o) Establish an ASID level resource manager
*                       routine to cleanup when the MXE server
*                       terminates.
*
*                   (o) Reserve a reusable SystemLX and define the
*                       module MXESRVPC as a PC-ss routine.
*
*                   (o) Establish operator communications and accept
*                       a possible STOP command.
*
*                   (o) Attach the MXESRVLD program as a subtask to
*                       periodically drain a PLO-serialized queue.
*
*                   (o) Publish address of the MXEGBVT via a system
*                       level name/token so that client code can
*                       locate the server information.
*
* Notes           : (o) This sample code is written to run in Key2.
*                       It requires a PPT entry similar to :
*
*                         PPT PGMNAME(MXESRVMN) KEY(2) NOSWAP
*
*                   (o) This is sample code - it does not really do
*                       anything useful (or harmful). It exists purely
*                       as a repository of coding examples.
*
*                   (o) The recovery provided in this sample code is
*                       pretty basic - there are many considerations
*                       that are not catered for in this code.
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
* r10 -
* r11 - MXEGBVT
* r12 - Data
* r13 - work area
*
*--------+---------+---------+---------+---------+---------+---------+-
* Changes
* 2019/01/09   RDS    Code Written
*--------+---------+---------+---------+---------+---------+---------+-
MXESRVMN MXEMAIN DATAREG=(R12)
*--------+---------+---------+---------+---------+---------+---------+-
* We are going to own PC rotuines - so ensure that we are nonswap
* Also ensure that we are running in the correct key (via PPT)
*--------+---------+---------+---------+---------+---------+---------+-
     MODESET MODE=SUP                        Supervisor state
     MXEMAC ZERO,(R2)                        Clear
     IPK   ,                                 R2=000000k0
     SRL   R2,4                              = 0000000k
     IF (C,R2,NE,=AL4(MXEGBVT@KEY))
       MXEMAC ABEND,MXEEQU@RSN_PPT           Bad PPT
     ENDIF
     XR    R1,R1
     SYSEVENT TRANSWAP                       PC-ss owner
*--------+---------+---------+---------+---------+---------+---------+-
* Grab the storage for the workarea
* Note : LOC=BELOW for STEPLIB DCB
*--------+---------+---------+---------+---------+---------+---------+-
     STORAGE OBTAIN,LENGTH=WA@LEN,LOC=BELOW,                           +
               ADDR=(R13),                                             +
               SP=WA@SP,                                               +
               COND=NO
     USING WA,R13
     MXEMAC INIT,WA,LENGTH==AL4(WA@LEN)      Clear storage
     MXEMAC SET_ID,WA                        and init
     USING SAVF4SA,WA_SAVEAREA
     MVC   SAVF4SAID,=A(SAVF4SAID_VALUE)
     MVC   WA_WTO_PLIST,LC_WTO_PLIST
*--------+---------+---------+---------+---------+---------+---------+-
* Execution shell
*--------+---------+---------+---------+---------+---------+---------+-
     DO    ,
       MXECALL INIT_SERVER_ANCHOR            Build MXEGBVT anchor
       DOEXIT (LTR,R15,R15,NZ)               Everything OK ?
       DOEXIT (LTR,R11,R1,Z)
       USING MXEGBVT,R11
       MXECALL PROCESS_STEPLIB               Process STEPLIB
       MXECALL LOAD_GLOBAL_MODULES           Load LPA module
       MXECALL ESTABLISH_RESOURCE_MANAGER    ASID level RESMGR
       MXECALL DEFINE_PC_ROUTINE             Build the PC routine
       MXEMSG  0006,OUTPUT=WA_MESSAGE
       WTO   TEXT=WA_MESSAGE,MF=(E,WA_WTO_PLIST)
       MXECATCH ON,RETRY=MXESRVMN_RECOVERY,MF=(E,WA_MXECATCH_PLIST)
       MXECALL ESTABLISH_OPERATOR_COMMS      Interface to operator
       MXECALL ATTACH_LOGDATA_TASK           Attach logdata subtask
*--------+---------+---------+---------+---------+---------+---------+-
* Publish the MXEGBVT address via sytem level name/token
*--------+---------+---------+---------+---------+---------+---------+-
       MXEREQ REQ=PUTTOKEN,                  Create MXEGBVT name/token +
               TOKEN=MXEGBVT_TOKEN_TOKEN,                              +
               RC=WA_RC,                                               +
               MF=(E,WA_MXEREQ_PLIST)
*--------+---------+---------+---------+---------+---------+---------+-
* Main processing - wait for operator command or failure in MXE
* ECB list contains the COMM ECB and the emergency term ECB (not
* currently used).
*--------+---------+---------+---------+---------+---------+---------+-
       DO UNTIL=(TM,MXEGBVT_FLG1,MXEGBVT@FLG1_SHUTDOWN,O)
         LLGT  R9,WA_COMM              Address IEZCOM
         USING COMLIST,R9
         LLGT  R2,COMECBPT             Oper command ECB
         MXEMAC VAR_LIST,WA_ECBLIST,LIST=((R2),WA_MXESRVMN_TERM_ECB)
         WAIT  1,ECBLIST=WA_ECBLIST
         IF (TM,WA_MXESRVMN_TERM_ECB,ECBPOST,O)
           MXEMSG  0007,OUTPUT=WA_MESSAGE
           WTO   TEXT=WA_MESSAGE,MF=(E,WA_WTO_PLIST)
           MXEMAC BIT_ON,MXEGBVT@FLG1_SHUTDOWN,LOCKED
         ELSE
           MXECALL PROCESS_OPERATOR_COMMAND
         ENDIF
       ENDDO
     ENDDO
*--------+---------+---------+---------+---------+---------+---------+-
* Termination (normal and abnormal)
*--------+---------+---------+---------+---------+---------+---------+-
     MXECATCH OFF,LABEL=MXESRVMN_RECOVERY,MF=(E,WA_MXECATCH_PLIST)
     MXECALL TERM_ENVIRONMENT
     MXEMSG  0008,OUTPUT=WA_MESSAGE
     WTO   TEXT=WA_MESSAGE,MF=(E,WA_WTO_PLIST)
     STORAGE RELEASE,LENGTH=WA@LEN,ADDR=(R13),SP=WA@SP
     MXEMAC ZERO,(R15)
     MXEMAIN RETURN
*--------+---------+---------+---------+---------+---------+---------+-
* Constants and LTORGs
*--------+---------+---------+---------+---------+---------+---------+-
LC_WTO_PLIST       WTO   TEXT=((R2)),MF=L
LC@WTO_LEN         EQU   *-LC_WTO_PLIST
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
ATTACH_LOGDATA_TASK MXEPROC DATAREG=(R12)
*--------+---------+---------+---------+---------+---------+---------+-
* (o) Grab a cell to describe the LOGDATA task (MXESRVLD)
* (o) Attach the new subtask and wait for the "start" ECB to POST
* (o) POST the "go" ECB to release the subtask to do its thing
*--------+---------+---------+---------+---------+---------+---------+-
     USING WA,R13
     USING MXEGBVT,R11
     DO    ,
       CPOOL GET,U,CPID=MXEGBVT_MXETASK_CPID,REGS=SAVE,LINKAGE=SYSTEM
       LR    R10,R1
       USING MXETASK,R10
       MXETASK REQ=ATTACH,PROGRAM=LC_LOGDATA_PROGRAM
       LAE   R1,MXETASK
       ST    R1,MXEGBVT_MXETASK_LOGDATA           Remember in MXEGBVT
       MXETASK REQ=GO                             Off ya go ...
     ENDDO
     MXEPROC RETURN
*--------+---------+---------+---------+---------+---------+---------+-
* Local constants (LTORG etc)
*--------+---------+---------+---------+---------+---------+---------+-
LC_LOGDATA_PROGRAM DC    CL8'MXESRVLD'
     MXEPROC END
*
*
*
DEFINE_PC_ROUTINE MXEPROC DATAREG=(R12)
*--------+---------+---------+---------+---------+---------+---------+-
* Grab a system LX and define the MXESEVPC PC routine
*--------+---------+---------+---------+---------+---------+---------+-
     USING WA,R13
     USING MXEGBVT,R11
     DO    ,
*--------+---------+---------+---------+---------+---------+---------+-
* (o) Because we are owning a SystemLX PC-ss, we need to use AX of 1
*--------+---------+---------+---------+---------+---------+---------+-
       AXSET AX==Y(1)                    Because owning PC-ss SysLX
*--------+---------+---------+---------+---------+---------+---------+-
* (o) Reserve a reusable SystemLX - this means we need a sequence
*     number in the HH of R15 prior to the PC call.
*--------+---------+---------+---------+---------+---------+---------+-
       MVC   MXEGBVT_TOKEN_LIST,=F'1'
       MVC   MXEGBVT_SYSLX_LIST,=F'1'
       LXRES ELXLIST=MXEGBVT_SYSLX_LIST, Reus SystemLX                 +
               SYSTEM=YES,                                             +
               REUSABLE=YES,                                           +
               MF=(E,WA_LXRES_PLIST)
*--------+---------+---------+---------+---------+---------+---------+-
* (o) Build the ETE for the MXESRVPC routine
*--------+---------+---------+---------+---------+---------+---------+-
       MVC   WA_ETDBASE,LC_ETDBASE      Model ETDEFs
       ETDEF TYPE=SET,HEADER=WA_ETDBASE,NUMETE=1
       LLGT  R2,MXEGBVT_ARR             Recovery routine
       LLGT  R7,MXEGBVT_MXESRVPC        PC-ss routine
*--------+---------+---------+---------+---------+---------+---------+-
* (o) MXESRVPC routine is in MXE LPA function pack along with the
*     common recovery routine MXECOMRC which will act as an ARR if
*     z/XDC not being used.
* (o) Stacking PC and space-switch with SASN=OLD meaning that
*     when MXESRVPC executes the PASN is MXE and the SASN is the
*     caller.
* (o) MXESRVPC gets control in ARmode and can use ALET value of 1
*     to access data in the caller ASID (SASN).
* (o) MXESRVPC gets control in Key2 (MXEGBVT@KEY)
*--------+---------+---------+---------+---------+---------+---------+-
       ETDEF TYPE=SET,ETEADR=WA_ETDBASE_PC,                            +
               ROUTINE=(R7),                                           +
               ARR=(R2),                                               +
               PC=STACKING,                                            +
               ASCMODE=AR,                                             +
               SSWITCH=YES,                                            +
               SASN=OLD,                                               +
               STATE=SUPERVISOR,                                       +
               RAMODE=31,                                              +
               AKM=(0:15),                                             +
               EKM=(0:15),PKM=REPLACE,                                 +
               EK=(MXEGBVT@KEY)
*--------+---------+---------+---------+---------+---------+---------+-
* Store the MXEGBVT as the first parameter in the latent parms
* Note that latent parm area address passed via R4 on entry to PC
*--------+---------+---------+---------+---------+---------+---------+-
       USING ETDELE,WA_ETDBASE_PC
       LAE   R1,MXEGBVT
       ST    R1,ETDPAR
*--------+---------+---------+---------+---------+---------+---------+-
* Create the ETEs and connect to linkage index
*--------+---------+---------+---------+---------+---------+---------+-
       ETCRE ENTRIES=WA_ETDBASE
       STCM  R0,B'1111',MXEGBVT_TOKEN
       ETCON ELXLIST=MXEGBVT_SYSLX_LIST,                               +
               TKLIST=MXEGBVT_TOKEN_LIST,                              +
               MF=(E,WA_ETCON_PLIST)
*--------+---------+---------+---------+---------+---------+---------+-
* (o) Publish the PC number in the MXEGBVT
* (o) Note that if we had more than one ETDEF, we would just increment
*     the PC numbers by one as we work down the ETDEFs.
*--------+---------+---------+---------+---------+---------+---------+-
       MVC   MXEGBVT_MXESRVPC_PCNUM,MXEGBVT_SYSLX
     ENDDO
     MXEPROC RETURN
*--------+---------+---------+---------+---------+---------+---------+-
* Local constants (LTORG etc)
*--------+---------+---------+---------+---------+---------+---------+-
LC_ETDBASE         ETDEF TYPE=INITIAL
                   ETDEF TYPE=ENTRY,ROUTINE=0,AKM=(0:15)
                   ETDEF TYPE=FINAL
LC@ETDBASE_LEN     EQU   *-LC_ETDBASE
     MXEPROC END
*
*
*
PROCESS_OPERATOR_COMMAND MXEPROC DATAREG=(R12)
*--------+---------+---------+---------+---------+---------+---------+-
* See what the operator command is - currently only STOP supported
*
* (o) If support for modify commands added, a good suggestion would
*     be to create an MXETASK and ATTACH a seperate task to handle
*     each command to provide a degree of abend-isolation from this
*     main task.
*--------+---------+---------+---------+---------+---------+---------+-
     USING WA,R13
     USING MXEGBVT,R11
     DO    ,
       LLGT  R9,WA_COMM             Address IEZCOM
       USING COMLIST,R9
       LLGT  R7,COMCIBPT            Get addr of CIB
       USING CIB,R7
       SELECT CLI,CIBVERB,EQ
         WHEN (CIBSTOP)
*--------+---------+---------+---------+---------+---------+---------+-
* Operator has indicated that MXE is to stop. We need to terminate
* the LOGDATA subtask.
*--------+---------+---------+---------+---------+---------+---------+-
           MXEMSG  0009,OUTPUT=WA_MESSAGE
           WTO   TEXT=WA_MESSAGE,MF=(E,WA_WTO_PLIST)
           MXEMAC BIT_ON,MXEGBVT@FLG1_SHUTDOWN,LOCKED
           LLGT  R10,MXEGBVT_MXETASK_LOGDATA
           USING MXETASK,R10
           MXETASK REQ=STOP
         OTHRWISE
           MXEMSG  0010,OUTPUT=WA_MESSAGE
           WTO   TEXT=WA_MESSAGE,MF=(E,WA_WTO_PLIST)
       ENDSEL
       QEDIT ORIGIN=COMCIBPT,BLOCK=(R7)        Free CIB
     ENDDO
     MXEPROC RETURN
*--------+---------+---------+---------+---------+---------+---------+-
* Local constants (LTORG etc)
*--------+---------+---------+---------+---------+---------+---------+-
     MXEPROC END
*
*
*
ESTABLISH_OPERATOR_COMMS MXEPROC DATAREG=(R12)
*--------+---------+---------+---------+---------+---------+---------+-
* Setup communications with the operator console
*--------+---------+---------+---------+---------+---------+---------+-
     USING WA,R13
     USING MXEGBVT,R11
     DO   ,
       LAE   R2,WA_COMM
       EXTRACT (R2),FIELDS=COMM,MF=(E,WA_EXTRACT_PLIST)
       LLGT  R9,WA_COMM             Address IEZCOM
       USING COMLIST,R9
       LLGT  R7,COMCIBPT            Get addr of CIB
       USING CIB,R7
       IF (LTR,R7,R7,NZ),OR,(CLI,CIBVERB,EQ,CIBSTART)
         QEDIT ORIGIN=COMCIBPT,BLOCK=(R7)      Free CIB
       ENDIF
       QEDIT ORIGIN=COMCIBPT,CIBCTR=1          Modify one at a time
     ENDDO
     MXEPROC RETURN
*--------+---------+---------+---------+---------+---------+---------+-
* Local constants (LTORG etc)
*--------+---------+---------+---------+---------+---------+---------+-
     MXEPROC END
*
*
*
ESTABLISH_RESOURCE_MANAGER MXEPROC DATAREG=(R12)
*--------+---------+---------+---------+---------+---------+---------+-
* Define the ASID level RESMGR routine.
* (o) MXESRVRM is part of the MXE LPA function pack
* (o) Resource manager passed the address of the MXEGBVT so that it
*     can cleanup when MXE terminates normally or abnormally.
*--------+---------+---------+---------+---------+---------+---------+-
     USING WA,R13
     USING MXEGBVT,R11
     DO    ,
       MVC   WA_RESMGR_PLIST,LC_RESMGR
       LAE   R2,MXEGBVT                        Global anchor as parm
       STG   R2,WA_RESMGR_PARAM
       LLGT  R4,MXEGBVT_MXESRVRM               routine EPA
       RESMGR ADD,                                                     +
               TOKEN=WA_RESMGR_TOKEN,                                  +
               TYPE=ADDRSPC,                                           +
               ASID=CURRENT,                                           +
               ROUTINE=(BRANCH,(R4)),                                  +
               PARAM=WA_RESMGR_PARAM,                                  +
               MF=(E,WA_RESMGR_PLIST)
       IF (LTR,R15,R15,NZ)                     Badness - cannot cope
         MXEMAC ABEND,MXEEQU@RSN_RESMGR
       ENDIF
     ENDDO
     MXEPROC RETURN
*--------+---------+---------+---------+---------+---------+---------+-
* Local constants (LTORG etc)
*--------+---------+---------+---------+---------+---------+---------+-
LC_RESMGR          RESMGR ADD,MF=L
LC@RESMGR_LEN      EQU   *-LC_RESMGR
     MXEPROC END
*
*
*
LOAD_GLOBAL_MODULES MXEPROC DATAREG=(R12)
*--------+---------+---------+---------+---------+---------+---------+-
* Load (or re-use) the MXEINLPA module.
* Store the VCONs for various modules in the MXEGBVT
*
* (o) MXE server will dynamically install the MXEINLPA module *once*
* (o) If the MXE server locates MXEINLPA already present, then it
*     will be re-used.
* (o) MXEINLPA is never deleted from LPA
* (o) If maintenance applied to MXEINLPA, then the operator must
*     issue the correct "SETPROG LPA" command to reload MXEINLPA from
*     its load library.
*--------+---------+---------+---------+---------+---------+---------+-
     USING WA,R13
     USING MXEGBVT,R11
     DO    ,
       MXEMAC INIT,WA_LPMEA                 Clear
       USING LPMEA,WA_LPMEA
       MVC   LPMEANAME,LC_LPA_NAME
       CSVQUERY INEPNAME=LPMEANAME,         Hunt for the module in LPA +
               SEARCH=LPA,                                             +
               OUTEPA=MXEGBVT_MXEINLPA,                                +
               RETCODE=WA_RC,                                          +
               MF=(E,WA_CSVQUERY_PLIST)
       SELECT CLC,WA_RC,EQ
         WHEN (=F'0')
         WHEN (=F'4',=F'8')
           LLGT  R4,MXEGBVT_LOADLIB_DCB     Get the DCB address
           CSVDYLPA REQUEST=ADD,                                       +
               MODINFOTYPE=MEMBERLIST,                                 +
               MODINFO=LPMEA,                                          +
               NUMMOD==F'1',                                           +
               DCB=(R4),                                               +
               REQUESTOR=LC_LPA_REQUESTOR,                             +
               RETCODE=WA_RC,                                          +
               RSNCODE=WA_RSN,                                         +
               SECMODCHECK=NO,                                         +
               MF=(E,WA_CSVDYLPA_PLIST)
           IF (LTR,R15,R15,NZ)
             MXEMAC ABEND,MXEEQU@RSN_CSVDYLPA
           ENDIF
           MVC   MXEGBVT_MXEINLPA,LPMEAENTRYPOINTADDR  Copy EPA
         OTHRWISE
           MXEMAC ABEND,MXEEQU@RSN_CSVQUERY
       ENDSEL
*--------+---------+---------+---------+---------+---------+---------+-
* If we get here, the address of MXEINLPA has been updated with the
* existing (or new) EPA. We can now dissect the module and store
* the VCONs in the MXEGBVT
*--------+---------+---------+---------+---------+---------+---------+-
       LLGT  R5,MXEGBVT_MXEINLPA            Load LPA pack address
       LLGT  R5,0(,R5)                      Point to first VCON
       USING MXEINLPA,R5                    Use VCON table map
       MVC   MXEGBVT_MXECOMRC,MXEINLPA_MXECOMRC
       MVC   MXEGBVT_MXEEOTXR,MXEINLPA_MXEEOTXR
       MVC   MXEGBVT_MXEMSGTB,MXEINLPA_MXEMSGTB
       MVC   MXEGBVT_MXESRBRQ,MXEINLPA_MXESRBRQ
       MVC   MXEGBVT_MXESRVRM,MXEINLPA_MXESRVRM
       MVC   MXEGBVT_MXETMRXR,MXEINLPA_MXETMRXR
*--------+---------+---------+---------+---------+---------+---------+-
* MXESRVPC is PC-ss, we we can use the MXE server private storage
* for its location. Easiest way is to linkedit it into this module
*--------+---------+---------+---------+---------+---------+---------+-
       MVC   MXEGBVT_MXESRVPC,=V(MXESRVPC)  PC-ss (private storage)
*--------+---------+---------+---------+---------+---------+---------+-
* Notice if z/XDC installed - store EPA in case we want to run with
* it as the common recovery instead of MXECOMRC
*--------+---------+---------+---------+---------+---------+---------+-
       MVC   MXEGBVT_ESTAE,MXEINLPA_MXECOMRC  Assume MXE recovery
       CSVQUERY INEPNAME=LC_XDC_NAME,         z/XDC installed?         +
               OUTEPA=MXEGBVT_XDC,                                     +
               SEARCH=LPA,                                             +
               MF=(E,WA_CSVQUERY_PLIST)
*--------+---------+---------+---------+---------+---------+---------+-
* Notice if DDNAME "MXEXDC" allocated - if so we force z/XDC to be
* the ESATE/ARR and FRR for all MXE modules
*--------+---------+---------+---------+---------+---------+---------+-
       IF (CLC,MXEGBVT_XDC,NE,=A(0))        Got XDC LPA module?
         LAE   R2,LC_XDC_DDNAME             See if DD present
         DEVTYPE (R2),WA_WORK_D
         IF (LTR,R15,R15,Z)                 Set ESTAE address
           MVC   MXEGBVT_ESTAE,MXEGBVT_XDC
         ENDIF
       ENDIF
     ENDDO
     MXEPROC RETURN
*--------+---------+---------+---------+---------+---------+---------+-
* Local constants (LTORG etc)
*--------+---------+---------+---------+---------+---------+---------+-
LC_LPA_NAME        DC    CL8'MXEINLPA'
LC_LPA_REQUESTOR   DC    CL16'MXESRVMN'
LC_XDC_NAME        DC    CL8'XDC'
LC_XDC_DDNAME      DC    CL8'MXEXDC'
     MXEPROC END
*
*
*
INIT_SERVER_ANCHOR MXEPROC DATAREG=(R12)
*--------+---------+---------+---------+---------+---------+---------+-
* Init the server anchor block in E-CSA and return its address to
* caller in R1
* The MXEGBVT is assigned ownership to SYSTEM and is deliberately not
* released - this is to prevent any long-running TCBs that may be
* connected to MXE server having problems if it is terminated with
* force.
*--------+---------+---------+---------+---------+---------+---------+-
     USING WA,R13
     DO    ,
       STORAGE OBTAIN,                                                 +
               LENGTH=MXEGBVT@LEN,                                     +
               OWNER=SYSTEM,                                           +
               ADDR=(R11),                                             +
               BNDRY=PAGE,                                             +
               SP=MXEGBVT@SP,                                          +
               KEY=MXEGBVT@KEY
       USING MXEGBVT,R11
       MXEMAC INIT,MXEGBVT,LENGTH==AL4(MXEGBVT@LEN)   Clear block
       MXEMAC SET_ID,MXEGBVT                   Standard init
       MVC   MXEGBVT_SP,=AL4(MXEGBVT@SP)
       LHI   R0,MXEGBVT@KEY                    Get 0000000k
       SLL   R0,4                              Make 000000k0
       ST    R0,MXEGBVT_KEY                    Store
       MVC   MXEGBVT_TOKEN_NAME,LC_TOKEN_NAME
*--------+---------+---------+---------+---------+---------+---------+-
* Define the cell pools
* (o) MXETASK for the generic task structure
*--------+---------+---------+---------+---------+---------+---------+-
       CPOOL BUILD,HDR='MXE:MXETASK',                                  +
               SP=MXETASK@SP,                                          +
               KEY=MXETASK@KEY,                                        +
               CSIZE=MXETASK@LEN,                                      +
               PCELLCT=MXETASK@PCELLCT,                                +
               BNDRY=DWORD,                                            +
               LOC=(31,64),                                            +
               MF=(E,WA_CPOOL_PLIST)
       ST    R0,MXEGBVT_MXETASK_CPID             Remember
*--------+---------+---------+---------+---------+---------+---------+-
* Define the buffer pools - 64bit
* (o) Currently various payload sizes from 0 thru 4096 in multiples
*     of 256 bytes.
* (o) Actual cell size includes the payload header (MXEREQDA)
*--------+---------+---------+---------+---------+---------+---------+-
       MXEMAC AMODE,64
       LAE   R4,LC_BPOOLDEF                      List of defs
       USING BPOOLDEF,R4
       LAE   R5,MXEGBVT_BPOOLS                   Target in MXEGBVT
       USING MXEGBVT_BP,R5
       DO FROM=(R3,=AL4(LC@BPOOLDEF_NUM))
         MVC   MXEGBVT_BP_SIZE,BPOOLDEF_SIZE     cell size
         MVC   WA_SIZE,BPOOLDEF_SIZE             cell size
         MXEMAC ADD,WA_SIZE,=AL4(MXEREQDA@LEN)   adjust for header
         IARCP64 REQUEST=BUILD,HEADER=BPOOLDEF_NAME,                   +
               CELLSIZE=WA_SIZE,                                       +
               CALLERKEY=YES,                                          +
               OWNINGTASK=CURRENT,                                     +
               TYPE=PAGEABLE,                                          +
               COMMON=NO,                                              +
               FPROT=YES,                                              +
               DUMP=LIKERGN,                                           +
               DUMPPRIO=10,                                            +
               FAILMODE=ABEND,                                         +
               TRAILER=NO,                                             +
               OUTPUT_CPID=MXEGBVT_BP_CPID,                            +
               MF=(E,WA_IARCP64_PLIST)
         LAE   R4,BPOOLDEF@LEN(,R4)              Next def
         LAE   R5,MXEGBVT_BP@LEN(,R5)            Next bufferpool
       ENDDO
       MXEMAC AMODE,31
*--------+---------+---------+---------+---------+---------+---------+-
* Format the LOGDATA queue
*--------+---------+---------+---------+---------+---------+---------+-
       USING MXEQUEUE,MXEGBVT_LOGDATA_QUEUE
       MXEMAC SET_ID,MXEQUEUE
       MVC   MXEQUEUE_NAME,LC_QUEUE_NAME
*--------+---------+---------+---------+---------+---------+---------+-
* Format the CORID array
*--------+---------+---------+---------+---------+---------+---------+-
       USING MXEARRAY,WA_CORID_ARRAY
       MXEMAC SET_ID,MXEARRAY
       MVC   MXEARRAY_NAME,LC_ARRAY_NAME
       LLGT  R0,=AL4(MXEEQU@MAX_CORID)
       STG   R0,MXEARRAY_MAX
       MVC   MXEARRAY_FREE,MXEARRAY_MAX
       LAE   R1,MXEARRAY
       ST    R1,MXEGBVT_CORID_ARRAY
     ENDDO
     MXEPROC RETURN,RC==F'0',OUTPUT=(R11)
*--------+---------+---------+---------+---------+---------+---------+-
* Local constants (LTORG etc)
*--------+---------+---------+---------+---------+---------+---------+-
LC_TOKEN_NAME      DC    CL16'MXE:MXEGBVT'
LC_QUEUE_NAME      DC    CL8'LOGDATA'
LC_ARRAY_NAME      DC    CL8'CORID'
LC_BPOOLDEF        DS    0D
                   DC    CL24'MXE:BP256'
                   DC    AL4(256)
*
                   DC    CL24'MXE:BP512'
                   DC    AL4(512)
*
                   DC    CL24'MXE:BP1K'
                   DC    AL4(1024)
*
                   DC    CL24'MXE:BP2K'
                   DC    AL4(2048)
*
                   DC    CL24'MXE:BP4K'
                   DC    AL4(4096)
*
LC@BPOOLDEF_SIZE   EQU   *-LC_BPOOLDEF
LC@BPOOLDEF_NUM    EQU   LC@BPOOLDEF_SIZE/BPOOLDEF@LEN
     MXEPROC END
*
*
*
PROCESS_STEPLIB MXEPROC DATAREG=(R12)
*--------+---------+---------+---------+---------+---------+---------+-
* Work out if STEPLIB coded in the STC JCL and remember its DCB
* (o) Required for CSVDYLPA
*--------+---------+---------+---------+---------+---------+---------+-
     USING WA,R13
     USING MXEGBVT,R11
     DO    ,
       LLGT  R1,CVTPTR(,R0)
       LLGT  R1,CVTLINK-CVT(,R1)
       ST    R1,MXEGBVT_LOADLIB_DCB            Store as DCB address
       LAE   R2,LC_STEPLIB                     STEPLIB in JCL ?
       DEVTYPE (R2),WA_WORK_D
       IF (LTR,R15,R15,Z)
         MXEMAC BIT_ON,MXEGBVT@FLG1_STEPLIB    Remember
         MVC   WA_STEPLIB,LC_STEPLIB_DCB
         MVC   WA_OPEN_PLIST,LC_OPEN
         MVC   WA_CLOSE_PLIST,LC_CLOSE
         OPEN  (WA_STEPLIB,(INPUT)),MF=(E,WA_OPEN_PLIST)
         LAE   R1,WA_STEPLIB
         ST    R1,MXEGBVT_LOADLIB_DCB          Store as DCB address
         MXEMAC BIT_ON,WA@FLG1_STEPLIB_OPEN
       ENDIF
     ENDDO
     MXEPROC RETURN
*--------+---------+---------+---------+---------+---------+---------+-
* Local constants (LTORG etc)
*--------+---------+---------+---------+---------+---------+---------+-
LC_STEPLIB         DC    CL8'STEPLIB'
LC_STEPLIB_DCB     DCB   DDNAME=STEPLIB,RECFM=U,MACRF=(R),DSORG=PO
LC@STEPLIB_DCB_LEN EQU   *-LC_STEPLIB_DCB
LC_OPEN            OPEN  (,),MF=L
LC@OPEN_LEN        EQU   *-LC_OPEN
LC_CLOSE           CLOSE (,),MF=L
LC@CLOSE_LEN       EQU   *-LC_CLOSE
     MXEPROC END
*
*
*
TERM_ENVIRONMENT MXEPROC DATAREG=(R12)
*--------+---------+---------+---------+---------+---------+---------+-
* Terminate the server
* (o) Remove PC routine
* (o) Close STEPLIB if required
*--------+---------+---------+---------+---------+---------+---------+-
     USING WA,R13
     USING MXEGBVT,R11
     DO    ,
       DOEXIT (LTR,R11,R11,Z)                    Ensure MXEGBVT
       MXEMAC VER_ID,MXEGBVT
       DOEXIT (LTR,R15,R15,NZ)
       MXEMAC ZERO,MXEGBVT_MXESRVPC_PCNUM        Zero the field
       IF (CLC,MXEGBVT_TOKEN,NE,=F'0')
         ETDES TOKEN=MXEGBVT_TOKEN,PURGE=YES,                          +
               MF=(E,WA_ETDES_PLIST)
       ENDIF
       IF (TM,WA_FLG1,WA@FLG1_STEPLIB_OPEN,O)
         CLOSE (WA_STEPLIB),MF=(E,WA_CLOSE_PLIST)
         MXEMAC BIT_OFF,WA@FLG1_STEPLIB_OPEN
       ENDIF
       AXSET AX==Y(0)
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
WA@FLG1_STEPLIB_OPEN EQU   X'80'
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
WA_COMM              DS    A
WA_SIZE              DS    F
                     DS    0D
WA_ECBLIST           DS    0XL(4*4)              Room for 4 ECBs
WA_ECBLIST_1         DS    A
WA_ECBLIST_2         DS    A
WA_ECBLIST_3         DS    A
WA_ECBLIST_4         DS    A
WA_MXESRVMN_TERM_ECB DS    A
                     DS    0D
WA_ETDBASE           DS    0XL(LC@ETDBASE_LEN)
WA_ETDBASE_HEADER    DS    XL(ETDLEN)
WA_ETDBASE_PC        DS    XL(ETDELEN)
                     DS    0D
WA_LPMEA             DS    XL(LPMEA_LEN)
                     DS    0D
WA_RESMGR_PLIST      DS    XL(LC@RESMGR_LEN)
WA_RESMGR_TOKEN      DS    F
WA_RESMGR_PARAM      DS    AD
                     DS    0D
WA_WTO_PLIST         DS    XL(LC@WTO_LEN)        Parm list for WTO
WA_MESSAGE           DS    XL128
                     DS    0D
WA_EXTRACT_PLIST     EXTRACT ,FIELDS=COMM,MF=L
                     DS    0D
WA_STEPLIB           DS    XL(LC@STEPLIB_DCB_LEN)
                     DS    0D
WA_OPEN_PLIST        DS    XL(LC@OPEN_LEN)
                     DS    0D
WA_CLOSE_PLIST       DS    XL(LC@CLOSE_LEN)
                     DS    0D
                     CSVQUERY PLISTVER=MAX,MF=(L,WA_CSVQUERY_PLIST)
                     DS    0D
                     CSVDYLPA PLISTVER=MAX,MF=(L,WA_CSVDYLPA_PLIST)
                     DS    0D
WA_LXRES_PLIST       LXRES LXLIST=*-*,SYSTEM=YES,MF=L
                     DS    0D
WA_ETCON_PLIST       ETCON MF=L
                     DS    0D
WA_ETDES_PLIST       ETDES MF=L
                     DS    0D
                     IARCP64 PLISTVER=MAX,MF=(L,WA_IARCP64_PLIST)
                     DS    0D
                     MXEREQ MF=(L,WA_MXEREQ_PLIST)
                     DS    0D
                     MXECATCH MF=(L,WA_MXECATCH_PLIST)
                     DS    0D
WA_CPOOL_PLIST       DS    XL(WA@CPOOL_PLIST_LEN)
                     DS    0D
WA_CORID_ARRAY       DS    XL(MXEARRAY@LEN)
WA_CORID_SLOT        DS    XL(MXEARRAYSL@LEN*MXEEQU@MAX_CORID)
                     DS    0D
WA@LEN               EQU   *-WA
WA@SP                EQU   50
WA@CPOOL_PLIST_LEN   EQU   64
*
*--------+---------+---------+---------+---------+---------+---------+-
* Buffer pool definitions
*--------+---------+---------+---------+---------+---------+---------+-
BPOOLDEF           DSECT
BPOOLDEF_NAME      DS    CL24          Name of buffer pool
BPOOLDEF_SIZE      DS    F             Cell size
BPOOLDEF@LEN       EQU   *-BPOOLDEF
*
*
*
         MXEGBVT
         MXEINLPA DSECT=YES
         MXEREQ   DSECT=YES
         MXETASK  DSECT=YES
         MXEMSGDF DSECT=YES
*
         CVT      DSECT=YES
         CSVLPRET
         IEANTASM
         IHASAVER
         IHAECB
         IHAETD   FORMAT=1,LIST=YES
         IEZCOM
CIB      DSECT
         IEZCIB
*
*
         MXEMAC   REG_EQU
         END
