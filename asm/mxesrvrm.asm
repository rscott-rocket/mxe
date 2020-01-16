MXESRVRM TITLE 'MXE - SERVER RESOURCE MANAGER'
*--------+---------+---------+---------+---------+---------+---------+-
* Name            : MXESRVRM
*
* Function        : MXE Server Resource Manager (RESMGR) routine
*
*                   (o) Mark server as unavailable
*
* Register Usage  :
* r1  -
* r2  -
* r3  -
* r4  -
* r5  -
* r6  -
* r7  -
* r8  - RMPL
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
MXESRVRM MXEMAIN DATAREG=(R12)
*--------+---------+---------+---------+---------+---------+---------+-
* Establish parameters
*--------+---------+---------+---------+---------+---------+---------+-
      LM    R8,R9,0(R1)                       Get parameters
      USING RMPL,R8
      LG    R11,0(,R9)                        MXEGBVT = passed parm
      USING MXEGBVT,R11
      STORAGE OBTAIN,LENGTH=WA@LEN,ADDR=(R13),COND=NO
      USING WA,R13
      MXEMAC INIT,WA,LENGTH==AL4(WA@LEN)      Clear
      MXEMAC SET_ID,WA                        Init block
      USING SAVF4SA,WA_SAVEAREA
      MVC   SAVF4SAID,=A(SAVF4SAID_VALUE)
*--------+---------+---------+---------+---------+---------+---------+-
* Main execution shell
*--------+---------+---------+---------+---------+---------+---------+-
      DO    ,
        DOEXIT (LTR,R11,R11,Z)                Do we have address?
        MXEMAC VER_ID,MXEGBVT                 Correct eye-catch ?
        DOEXIT (LTR,R15,R15,NZ)
*--------+---------+---------+---------+---------+---------+---------+-
* Ensure "shutdown" indicated
* MXEGBVT block is deliberately not released incase we have any long
* running tasks that have not terminated before server is terminated
* We also leave the MXEINLPA function pack in LPA for same reason.
*--------+---------+---------+---------+---------+---------+---------+-
        MXEMAC BIT_ON,MXEGBVT@FLG1_SHUTDOWN,LOCKED
        MXEMAC ZERO,MXEGBVT_MXESRVPC_PCNUM
*--------+---------+---------+---------+---------+---------+---------+-
* Termination (normal and abnormal)
*--------+---------+---------+---------+---------+---------+---------+-
      ENDDO
      STORAGE RELEASE,LENGTH=WA@LEN,ADDR=(R13)
      MXEMAC ZERO,(R15)
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
                     DS    0D
WA@LEN               EQU   *-WA
*
         MXEGBVT
*
         IHASAVER
         IHARMPL
*
         MXEMAC REG_EQU
         END
