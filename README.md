# PRTG
This repository consist of several scripts: 
1. [PRTG Custom Sensor Result Powershell class](#PRTG-Custom-Sensor-Result-Powershell-class)
2. [PRTG Custom Lookup files](#prtg-custom-lookup-files)
3. [PRTG Custom sensor Powershell scripts for monitoring VMware Horizon](#prtg-custom-sensor-powershell-scripts-for-monitoring-vmware-horizon)
## PRTG Custom Sensor Result Powershell class
I have created this Powershell class to facilitate a correct JSON output of my PRTG custom Powershell scripts. Instead of repeating all the output statements in all my scripts, this class stores all information I want in the sensor and finally writes out a PRTG compliant JSON string. It saved me a lot of coding time and even more debugging time because of another type in the outputted JSON string. 
The class can be found [here](PRTG-CSR/)
## PRTG Custom Lookup files
I also created some custom PRTG Lookup value files to show the status of some channels in PRTG
Those .ovl files must be placed in your PRTG installation folder under lookups\custom
You can find the files [here](PRTG-Lookups/)
## PRTG Custom sensor Powershell scripts for monitoring VMware Horizon
A collection of powershell scripts to monitor your VMware Horizon environment with PRTG. 
More information can be found [here](PRTG-Horizon/)
