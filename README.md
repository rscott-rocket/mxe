# mxe
Sample z/OS synchronous cross memory server written in HLASM

Strongly suggest installing on a test system only.

To install :

(1) Copy the MXEALLOC.txt member of the samplib directory to z/OS system, edit it and submit the JCL
(2) Copy the contents of the asm directory to the ASM dataset created in (1)
(3) Copy the contents of the maclib directory to the MACLIB dataset created in (1)
(4) Copy the contents of the samplib directory to the SAMPLIB dataset created in (1)
(5) Ensure all z/OS dataset members are in EBCDIC
(6) Edit and submkit the MXEBUILD JCL in SAMPLIB to assemble and linkedit the product
(7) Update your runtime PARMLIB PROGxx member with the contents of MXEPROG in the SAMPLIB dataset
(8) Update your rutiime PARMLIB SCHEDxx member with the contents of MXESCHED in the SAMPLIB dataset
(9) Copy the contents of MXE in the SAMPLIB dataset to your system PROCLIB dataset
(10) Assign a userid to the MXE started task and ensure it has read access to the SMXELOAD dataset
(11) Issue the "S MXE" operator command to start the server
(12) MXE can be stopped using the "P MXE" operator command
(13) Make the SMXELOAD dataset available to your TSO userid load module search order
(14) Issue the MXETSO command from ISPF option 6 or the READY prompt
