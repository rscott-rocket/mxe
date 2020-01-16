         TITLE 'MXE LPA MODULE PACK'                                            
*--------+---------+---------+---------+---------+---------+---------+-         
* Name     : MXEINLPA                                                           
*                                                                               
* Function : LPA resident MXE modules                                           
*                                                                               
* Note     : First word in the module points to the VCON array and              
*            caters for the MODID info.                                         
*                                                                               
*          : Array of VCONs is mapped by the MXEINLPA macro using               
*            DSECT=YES.                                                         
*                                                                               
*--------+---------+---------+---------+---------+---------+---------+-         
* Changes                                                                       
* 2019/01/09   RDS    Code Written                                              
*--------+---------+---------+---------+---------+---------+---------+-         
MXEINLPA CSECT                                                                  
MXEINLPA AMODE 31                                                               
MXEINLPA RMODE ANY                                                              
         DC    AL4(MXEINLPA_VCON_START)                                         
         MODID ,                                                                
*--------+---------+---------+---------+---------+---------+---------+-         
* Table of 4 byte CSECT addresses                                               
*--------+---------+---------+---------+---------+---------+---------+-         
MXEINLPA_VCON_START DS    0A                                                    
         MXEINLPA   DSECT=NO                                                    
MXEINLPA_VCON_END   DS    0A                                                    
         END                                                                    
