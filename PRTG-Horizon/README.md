# PRTG Powershell scripts to monitor VMware Horizon environment
Here's a collection of powershell scripts that you can you as PRTG Custom sensors to monitor your VMware Horizon environment
## REQUIREMENTS
The scripts all use the [PRTG-CSRClass](../PRTG-CSR/) script to generate the correct PRTG JSON string
The scripts all use the Horizon-Functions.ps1 script
In most scripts channels are created with a custom lookup value. The custom lookup files can be found [here](../PRTG-Lookups/)
## Overview
### PRTG-HorizonCS.ps1
    This script shows the satus of the connection servers in your environment in a single sensor, using different channels

