# PRTG Powershell scripts to monitor VMware Horizon environment
Here's a collection of powershell scripts that you can you as PRTG Custom sensors to monitor your VMware Horizon environment
## REQUIREMENTS
The scripts all use the [PRTG-CSRClass](../PRTG-CSR/) script to generate the correct PRTG JSON string
The scripts all use the Horizon-Functions.ps1 script
In most scripts channels are created with a custom lookup value. The custom lookup files can be found [here](../PRTG-Lookups/)
## Overview
Copy the powershell script(s) to the following location: <PRTG installation folder>\custom\exexml\ (this has to be done on each probe where you want to use this script)
Download the [PRTG-CSRClass](../PRTG-CSR/) (not necessary if you'll adjust the scripts for another monitoring system)
Download the Horizon-Functions.ps1 that contains common functions for all scripts (non-PRTG related functions)
Download the [PRTG Custom Lookup files](../PRTG-Lookups/) 

1. Create a new device in PRTG pointing to a Horizon Connection server (or the loadbalancer). 
2. Add a new sensor: "EXE/Script advanced"
3. Choose the correct script you want for this sensor
4. Enter the necessary parameters (make sure you add all mandatory parameters or the script will hang, waiting for userinput for the required parameters). You can use PRTG placeholders: 
   e.g. -HVUrl https://%host -HVUser %windowsuser -HVPass %windowspassword -HVDomain %windowsdomain 
   This wil take the values for user, password, host, ... from the information entered in PRTG on the sensor or parent group. Of course, you can also specify a fixed value in the parameters instead of using PRTG placeholders
### Horizon-Functions.ps1
This script contains some general functions that are used by all other scripts here. Put it in the same location where you put the other scripts.
### PRTG-HorizonCS.ps1
This script shows the satus of the connection servers in your environment in a single sensor, using different channels