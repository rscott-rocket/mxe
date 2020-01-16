MXECOMRC TITLE 'MXE COMMON RECOVERY'                                            
*--------+---------+---------+---------+---------+---------+---------+-         
* Name            : MXECOMRC                                                    
*                                                                               
* Function        : General purpose recovery routine                            
*                                                                               
*                   Populate the MXECATCH control block with SDWA info          
*                   and retry (if possible)                                     
*                                                                               
*                   MXECATCH control block passed as a parm to this             
*                   recovery routine by the following means :                   
*                                                                               
*                     ESTAE - Passed via "PARAM" keyword                        
*                                                                               
*                     ARR   - Stored in the linkage stack via MSTA              
*                                                                               
*                     FRR   - Stored in the FRR parm area                       
*                                                                               
*                   MXECOMRC is part of the MXE LPA function pack               
*                                                                               
*                                                                               
* Register Usage  :                                                             
* r1  - parameter passed : SDWA                                                 
* r2  -                                                                         
* r3  -                                                                         
* r4  - SDWA                                                                    
* r5  -                                                                         
* r6  -                                                                         
* r7  - SDWARC1                                                                 
* r8  - MXECATCH                                                                
* r9  - Retry routine                                                           
* r10 -                                                                         
* r11 - Return address                                                          
* r12 - Data                                                                    
* r13 -                                                                         
*                                                                               
*--------+---------+---------+---------+---------+---------+---------+-         
* Changes                                                                       
* 2019/01/09   RDS    Code Written                                              
*--------+---------+---------+---------+---------+---------+---------+-         
MXECOMRC MXEMAIN DATAREG=(R12),BAKR=NO,PARMS=(R4)                               
*--------+---------+---------+---------+---------+---------+---------+-         
* Copy the regs passed by RTM                                                   
*--------+---------+---------+---------+---------+---------+---------+-         
     LGR   R5,R0                   Entry code                                   
     LGR   R8,R2                   Possible MXECATCH address                    
*--------+---------+---------+---------+---------+---------+---------+-         
* Init code                                                                     
*--------+---------+---------+---------+---------+---------+---------+-         
     LGR   R11,R14                 Save return address                          
     IF (C,R5,EQ,=F'12')           No SDWA ?                                    
       MXEMAC ZERO,(R15)           ..Percolate                                  
       BR    R11                   ..Return to caller                           
     ENDIF                                                                      
*--------+---------+---------+---------+---------+---------+---------+-         
* We have an SDWA - and maybe an MXECATCH if this is "us"                       
*--------+---------+---------+---------+---------+---------+---------+-         
     USING SDWA,R4                 Address SDWA                                 
     USING MXECATCH,R8             Address possible MXECATCH                    
*--------+---------+---------+---------+---------+---------+---------+-         
* Ensure that the passed parm is an MXECATCH and that the recovery              
* environment was established OK.                                               
*--------+---------+---------+---------+---------+---------+---------+-         
     DO    ,                                                                    
       DOEXIT (LTGR,R8,R8,Z)       no address - quit                            
       MXEMAC VER_ID,MXECATCH      Check eye-catchcer                           
       DOEXIT (LTR,R15,R15,NZ)     Bad eye-catcher                              
       DOEXIT (TM,MXECATCH_FLG1,MXECATCH@FLG1_INIT,NO) Init OK?                 
*--------+---------+---------+---------+---------+---------+---------+-         
* If the "invoked" flag is on, then we have recursively entered                 
* this routine and most likely this is not intentional, so we                   
* percolate if so.                                                              
*--------+---------+---------+---------+---------+---------+---------+-         
       DOEXIT (TM,MXECATCH_FLG1,MXECATCH@FLG1_INVOKED,O)                        
*--------+---------+---------+---------+---------+---------+---------+-         
* Indicate that we have been invoked and that we have found SDWA                
*--------+---------+---------+---------+---------+---------+---------+-         
       MXEMAC BIT_ON,MXECATCH@FLG1_INVOKED                                      
       MXEMAC BIT_ON,MXECATCH@FLG1_SDWA                                         
*--------+---------+---------+---------+---------+---------+---------+-         
* Copy all of the failure info from the SDWA into the MXECATCH                  
*--------+---------+---------+---------+---------+---------+---------+-         
       LLGT  R6,SDWAXPAD            Get SDWAPTRS address                        
       USING SDWAPTRS,R6                                                        
       MVC   MXECATCH_EC1,SDWAEC1   Copy PSW                                    
       MVC   MXECATCH_ABCC,SDWAABCC Copy completion code                        
       LLGT  R7,SDWASRVP            Get SDWARC1                                 
       USING SDWARC1,R7                                                         
       MVC   MXECATCH_CRC,SDWACRC   Copy reason code                            
       MVC   MXECATCH_FAIN,SDWAFAIN Copy failing instruction                    
       MVC   MXECATCH_AR,SDWAARER   Copy ARs                                    
       MVC   MXECATCH_NXT1,SDWANXT1 Copy next instruction address               
       MVC   MXECATCH_PASN,SDWAPRIM Primary address space                       
       MVC   MXECATCH_SASN,SDWASCND Secondary address space                     
       MVC   MXECATCH_HASN,SDWAASID Home address space                          
*--------+---------+---------+---------+---------+---------+---------+-         
* Copy the 31-bit general regs at time of error                                 
*--------+---------+---------+---------+---------+---------+---------+-         
       LAE   R15,SDWAGRSV           31-bit regs                                 
       LAE   R1,MXECATCH_GR         Reg area to save them in                    
       DO FROM=(R14,=F'16')                                                     
         MXEMAC ZERO,(R0)           Clear reg                                   
         ICM   R0,B'1111',0(R15)    Get SDWA reg value                          
         STG   R0,0(,R1)            Store as 64-bit                             
         LAE   R15,4(,R15)          Next 31-bit                                 
         LAE   R1,8(,R1)            Next 64-bit                                 
       ENDDO                                                                    
*--------+---------+---------+---------+---------+---------+---------+-         
* Attempt to get any 64-bit information                                         
*--------+---------+---------+---------+---------+---------+---------+-         
       IF (ICM,R10,B'1111',SDWAXEME,NZ) 64-bit stuff present?                   
         USING SDWARC4,R10                                                      
         MVC   MXECATCH_GR,SDWAG64  Copy GPRs                                   
         MVC   MXECATCH_TEA,SDWATRNE                                            
         MVC   MXECATCH_BEA,SDWABEA                                             
       ENDIF                                                                    
*--------+---------+---------+---------+---------+---------+---------+-         
* Do we have a retry routine address and is retry allowed?                      
*--------+---------+---------+---------+---------+---------+---------+-         
       DOEXIT (ICM,R9,B'1111',MXECATCH_RETRY,Z)                                 
       DOEXIT (TM,SDWAERRD,SDWACLUP,O)   Retry allowed ?                        
*--------+---------+---------+---------+---------+---------+---------+-         
* Go back to RTM and request retry                                              
*--------+---------+---------+---------+---------+---------+---------+-         
       SETRP   RC=4,                                                   +        
               WKAREA=(R4),                                            +        
               DUMP=NO,                                                +        
               RECORD=YES,                                             +        
               FRESDWA=YES,                                            +        
               RETREGS=YES,                                            +        
               RETADDR=(R9)                                                     
       BR    R11                                                                
     ENDDO                                                                      
*--------+---------+---------+---------+---------+---------+---------+-         
* Percolate back to RTM  (retry noy possible or not MXE env)                    
*--------+---------+---------+---------+---------+---------+---------+-         
     SETRP RC=0,WKAREA=(R4),RECORD=NO,DUMP=NO                                   
     BR    R11                                                                  
     MXEMAIN RETURN                                                             
*--------+---------+---------+---------+---------+---------+---------+-         
* Local constants                                                               
*--------+---------+---------+---------+---------+---------+---------+-         
     MXEMAIN END                                                                
*                                                                               
*                                                                               
*--------+---------+---------+---------+---------+---------+---------+-         
* DSECTs                                                                        
*--------+---------+---------+---------+---------+---------+---------+-         
*                                                                               
*                                                                               
         IHASDWA                                                                
         IKJRB                                                                  
         IHACDE                                                                 
*                                                                               
         MXECATCH DSECT=YES                                                     
         MXEMAC   REG_EQU                                                       
         END                                                                    
