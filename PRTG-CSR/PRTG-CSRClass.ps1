##################################################################################################
### PRTG-CSRClass.ps1
###
###     Defines the prtgCSR object, members and methods to output a PRTG validated JSON string.
###
###     The script is mostly based on the PRTG-provided python class "CustomSensorResult"
###    
##################################################################################################


# class prtgCSR, contains a collection of prtgChannels and an optional text of error message to be returned
#                contains functions to add a channel, set an error message and return a PRTG-valid JSON string
class prtgCSR {
    [System.Collections.ArrayList]$Channels = @()
    [string]$Text="OK"
    [string]$ErrorText=""
    [bool]$hasError=$false

    [void]addChannel([string]$cChannel, [float]$cValue, [PSCustomObject]$cOptions) {
        #############################################################################################
        ### prtgCSR.addChannel(string, float, PSCustomObject)
        ###
        ###     $cChannel = Name of the channel that will be shown in PRTG
        ###     $cValue = integer or float representing the value of the channel
        ###     $cOptions = hashtable with following posible values:
        ###
        ###         [bool]Float = $true | $false
        ###             DEFAULT = $false
        ###             specifies if the value will be shown with floating point or not
        ###
        ###         [string]Unit = possible values in $lValueUnit
        ###             DEFAULT = "Custom"
        ###             specifies the unit of the value.
        ###
        ###         [string]CustomUnit = string
        ###             DEFAULT = "#"
        ###             specifies the string to be placed after the value (e.g. "sec.") in PRTG
        ###
        ###         [string]SpeedSize = possible values in $lValueSize
        ###             DEFAULT = "One"
        ###             specifies the size used for displaying the value. If value = 50000
        ###             and SpeedSize = Kilo, PRTG will show the value as 50 kilo
        ###
        ###         [string]VolumeSize = possible values in $lValueSize
        ###             DEFAULT = "One"
        ###             specifies the size used for displaying the value. If value = 50000
        ###             and VolumeSize = Kilo, PRTG will show the value as 50 kilo
        ###
        ###         [string]SpeedTime = possible values in $lValueTime
        ###             DEFAULT = "Second"
        ###             specifies the time used for displaying the value. If value = 60 and
        ###             SpeedTime = Mintue, PRTG will show the value as 1 min.
        ###
        ###         [string]Mode = possible values in $lValueMode
        ###             DEFAULT = "Absolute"
        ###             specifies if the value is an absolute value or counter
        ###
        ###         [bool]Warning = $true | $false
        ###             DEFAULT = $false
        ###             specifies if the sensor must be set in warning status if at least 
        ###             one channel is in Warning
        ###
        ###         [bool]HideChart = $true | $false
        ###             DEFAULT = $false
        ###             hides the channel from the charts in PRTG
        ###
        ###         [bool]HideTable = $true | $false
        ###             DEFAULT = $false
        ###             hides the channel from the tables in PRTG
        ###
        ###         [string]ValueLookup = string
        ###             DEFAULT = "None"
        ###             specifies the ValueLookup to be used in PRTG, only valid with Unit="Custom"
        ###
        ###         [bool]Primary = $true | $false
        ###             DEFAULT = $false
        ###             specifies if this channel will be set as primary channel
        ###
        ### EXAMPLES:
        ###     prtgCSR.addChannel("Channel Name", 512, @{})
        ###         Specify name and value with an empty option list
        ###
        ###     prtgCSR.addChannel("Channel Name", 15.36, @{Float=$true; Unit="Percent"})
        ###         Specify float value, showing in PRTG as percentage
        ###
        ###     prtgCSR.addChannel("Channel Name", 1024, @{Unit="BytesDisk"; VolumeSize="KiloByte"})
        ###         Specify bytes value, showing in PRTG as a size in Kb 
        ###
        ###     prtgCSR.addChannel("Channel Name", 3, @{Primary=$true})
        ###         Specify name and value an set it as primary channel in PRTG
        ###         NOTE: only the last channel added with the Primary switch will be 
        ###             set as primary in PRTG.
        ###
        #############################################################################################

        # define possible values for some Channel settings. Invalid options will raise a sensor error with the details or the faulty option
        $lValueSize = @("One", "Kilo", "Mega", "Giga", "Tera", "Byte", "KiloByte", "MegaByte", "GigaByte", "TeraByte", "Bit", "KiloBit", "MegaBit", "GigaBit", "TeraBit") 
        $lValueTime = @("Second", "Minute", "Hour", "Day") 
        $lValueUnit = @("BytesBandwidth", "BytesDisk", "Temperature", "Percent", "TimeResponse", "TimeSeconds", "Custom", "Count", "CPU", "BytesFile", "SpeedDisk", "SpeedNet", "TimeHours") 
        $lValueMode = @("Absolute", "Difference") 

        # create new prtgChannel object and set its name
        $newChannel = @{}
        $newChannel.Channel = $cChannel
        
        # check if Float is specified. If not, value will be handled as integer
        if ($cOptions["Float"]) {
            $newChannel.Float = 1
            $newChannel.DecimalMode = "ALL"
            $newChannel.Value = $cValue
        } else { $newChannel.value = [int]$cValue }

        # Check if Unit is specified and if a correct value is given. If not return error.
        if (-not ([string]::IsNullOrWhiteSpace($cOptions["Unit"]))) {
            if ($lValueUnit.Contains($cOptions["Unit"])) {
                $newChannel.Unit = $cOptions["Unit"]
                if (($newChannel.Unit -eq "Custom") -and (-not ([string]::IsNullOrWhiteSpace($cOptions["CustomUnit"])))) {
                    # if unit = Custom & CustomUnit is specified, save it. Ignore if unit is not Custom
                    $newChannel.CustomUnit = $cOptions["CustomUnit"]
                }
            } else { $this.Error("Invalid Unit '$($cOptions["Unit"])' for channel '$($cChannel)'' specified") }
        }

        # check if ValueLookup is specified. Only valid with ValueUnit="Custom"
        if (-not ([string]::IsNullOrWhiteSpace($cOptions["ValueLookup"]))) {
            $newChannel.ValueLookup = $cOptions["ValueLookup"]
            $newChannel.Unit = "Custom"
        }
        

        # Check if SpeedSize is specified and if a correct value is given. If not return error.
        if (-not ([string]::IsNullOrWhiteSpace($cOptions["SpeedSize"]))) {
            if ($lValueSize.Contains($cOptions["SpeedSize"])) {
                $newChannel.unit = $cOptions["SpeedSize"]
            } else { $this.Error("Invalid SpeedSize '$($cOptions["SpeedSize"])' for channel '$($cChannel)'' specified") }
        }

        # Check if VolumeSize is specified and if a correct value is given. If not return error.
        if (-not ([string]::IsNullOrWhiteSpace($cOptions["VolumeSize"]))) {
            if ($lValueSize.Contains($cOptions["VolumeSize"])) {
                $newChannel.unit = $cOptions["VolumeSize"]
            } else { $this.Error("Invalid VolumeSize '$($cOptions["VolumeSize"])' for channel '$($cChannel)'' specified") }
        }

        # Check if SpeedTime is specified and if a correct value is given. If not return error.
        if (-not ([string]::IsNullOrWhiteSpace($cOptions["SpeedTime"]))) {
            if ($lValueTime.Contains($cOptions["SpeedTime"])) {
                $newChannel.unit = $cOptions["SpeedTime"]
            } else { $this.Error("Invalid SpeedTime '$($cOptions["SpeedTime"])' for channel '$($cChannel)'' specified") }
        }
        
        # Check if Mode is specified and if a correct value is given. If not return error
        if (-not ([string]::IsNullOrWhiteSpace($cOptions["Mode"]))) {
            if ($lValueMode.Contains($cOptions["Mode"])) {
                $newChannel.unit = $cOptions["Mode"]
            } else { $this.Error("Invalid Mode '$($cOptions["Mode"])' for channel '$($cChannel)'' specified") }
        }

        # check if Warning is specified
        if ($cOptions["Warning"]) { $newChannel.Warning = 1 }

        # check if HideChart & HideTable is specified
        if ($cOptions["HideChart"]) { $newChannel.ShowChart = 0}
        if ($cOptions["HideTable"]) { $newChannel.ShowTable = 0}

        # check if channel must be set as primary. If so, put Channel in list as first item
        if ($cOptions["Primary"]) { $this.Channels.Insert(0, $newChannel) } 
        else { $this.Channels.add($newChannel) }
    }

    [void]addChannel([string]$cChannel, [float]$cValue) {
        ##############################################################################
        ### prtgCSR.addChannel(string, float)
        ###
        ###     overload with only minimal parameters (name & value) 
        ###     this funtions just calls addChannel(string, float, PSCustomObject) 
        ###     with an empty options list
        ##############################################################################
        $this.addChannel($cChannel, $cValue, @{})
    }

    [void]Error([string]$msg) {
        ##############################################################################
        ### prtgCSR.Error(string)
        ###
        ###     Sets $hasError to $true and saves error message
        ###     When $hasError = $true, no channels will be returned in JSON result
        ###     only the error message that will be visible in the sensor in  PRTG
        ##############################################################################
        $this.hasError = $true
        $this.ErrorText = $msg
    }

    [string]result(){
        ########################################################################
        ### prtgCSR.result()
        ###
        ###     Returns a JSON formatted string containing either the channels
        ###     or the error message that will be shown in PRTG
        ########################################################################
        if ($this.hasError) {
            # If error then only output error message
            return @"
{
    "prtg": {
        "text": "$($this.ErrorText)",
        "error": 1
    }
}
"@
        } else {
            # if no error, return channels
            return @"
{
    "prtg": {
        "text": "$($this.Text)",
        "result": $(ConvertTo-Json @($this.Channels))
    }
}
"@
        }
    }


}

