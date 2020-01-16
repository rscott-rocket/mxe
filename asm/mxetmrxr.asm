MXETMRXR TITLE 'MXE COMMON TIMER EXIT ROUTINE'                                  
*--------+---------+---------+---------+---------+---------+---------+-         
* Name            : MXETMRXR                                                    
*                                                                               
* Function        : General purpose STIMERM exit routine                        
*                                                                               
*                   Invoked by the MXETIMER macro                               
*                                                                               
*                                                                               
* Register Usage  :                                                             
* r1  - parameter passed : +4 MXETIMER                                          
* r2  -                                                                         
* r3  -                                                                         
* r4  -                                                                         
* r5  -                                                                         
* r6  -                                                                         
* r7  -                                                                         
* r8  -                                                                         
* r9  - MXETIMER                                                                
* r10 -                                                                         
* r11 -                                                                         
* r12 - Data                                                                    
* r13 -                                                                         
*                                                                               
*--------+---------+---------+---------+---------+---------+---------+-         
* Changes                                                                       
* 2019/01/09   RDS    Code Written                                              
*--------+---------+---------+---------+---------+---------+---------+-         
MXETMRXR MXEMAIN DATAREG=(R12)                                                  
         LLGT  R9,4(,R1)                                                        
         USING MXETIMER,R9                                                      
         MXEMAC VER_ID,MXETIMER                                                 
         IF (LTR,R15,R15,NZ)                                                    
           MXEMAC ABEND,MXEEQU@RSN_TIMER                                        
         ENDIF                                                                  
         POST  MXETIMER_ECB             Post the timer ECB                      
         MXEMAIN RETURN                                                         
         MXEMAIN END                                                            
*                                                                               
*--------+---------+---------+---------+---------+---------+---------+-         
* DSECTs                                                                        
*--------+---------+---------+---------+---------+---------+---------+-         
*                                                                               
         MXEGBVT                                                                
         MXETIMER DSECT=YES                                                     
         MXEMAC REG_EQU                                                         
*                                                                               
         END                                                                    
