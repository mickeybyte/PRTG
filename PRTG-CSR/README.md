# PRTG-CSRClass
To be able to use this class, first dot-source the PRTG-CSRClass.ps1 file in your script (see [Powershell dot-source](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_operators?view=powershell-7#dot-sourcing-operator-))
Next create a new prtgCSR object, add one or more channels and finally output the JSON string.
```
$csr = New-Object prtgCSR
$csr.addChannel("Channel 1", 16)
$csr.addChannel("Channel 2", 26.36, @{Primary=$true; Float=$true; Unit="Percent"})
write-host $csr.result()
```
If you want te return an error state to PRTG, use the prtgCSR.error(string) function
```
...
$csr.Error("An error occured retrieving the value")
write-host $csr.result()
```