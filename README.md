# MXE

Sample z/OS synchronous cross memory server written in HLASM

Strongly suggest installing on a test system only.

# Install

Allocate the PDS data sets for ASM, MACLIB, SAMPLIB

## Install from a zip file

If you don't have git installed on z/OS download a zip file from Github and use the following instructions. 

* FTP the zip file to z/OS as a binary file
* Extract the zip file `jar xf mxe-master.zip`
* The files will be in ASCII (ISO8859-1) encoding so the files need to be tagged.
    
    * `cd mxe-master`
    * `chtag -tc ISO8859-1 .`
    
## Copy the z/OS Unix files to PDS data sets
    
Copy the files from the file system converting ISO8859-1 to EBCDIC (if required) `-O u`. 
File extensions will be stripped using the `-A` flag.

    ```
    cp -A -O u asm/* "//'HLQ.MXE.ASM'"
    cp -A -O u samplib/* "//'HLQ.MXE.SAMPLIB'"  
    cp -A -O u maclib/* "//'HLQ.MXE.MACLIB'"  
    ```

# Post installation

* Edit the `MXEALLOC` member of the samplib directory to z/OS system and submit the JCL.
* Edit and submit the MXEBUILD JCL in SAMPLIB to assemble and linkedit the product.
* Update your runtime PARMLIB PROGxx member with the contents of MXEPROG in the SAMPLIB dataset.
* Update your rutiime PARMLIB SCHEDxx member with the contents of MXESCHED in the SAMPLIB dataset.
* Copy the contents of MXE in the SAMPLIB dataset to your system PROCLIB dataset.
* Assign a userid to the MXE started task and ensure it has read access to the SMXELOAD dataset.
* Issue the "S MXE" operator command to start the server.

MXE can be stopped using the `P MXE` operator command.

# Running from TSO  

Make the `SMXELOAD` dataset available to your TSO userid load module search order.

Issue the `MXETSO` command from ISPF option 6 or the READY prompt.
