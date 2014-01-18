' CheckForIntel.vbs
' Checks if the processor is an Intel and re-enables the power managment driver if it is.
' Written by Ryan D - based off the WMI sample script by Guy Thomas http://computerperformance.co.uk/
' 
' ===Version History===
' 1.0 - Initial release
' 1.1 - Changed the way that the script checks for Intel machines. Now it looks at the CPU type and looks
'         to see if the string "GenuineIntel" is present.
' --------------------------------------------------------------' 
option explicit
const HKEY_LOCAL_MACHINE = &H80000002
dim objWMIService, objItem, colItems, strComputer, compModel, strKeyPath, strValueName, strValue, oReg

strKeyPath = "SYSTEM\ControlSet001\Services\intelppm"
strValueName = "Start"
strValue = "1"
strComputer = "."

' WMI connection to Root CIM and get the computer type
set objWMIService = GetObject("winmgmts:\\" _
& strComputer & "\root\cimv2")
set colItems = objWMIService.ExecQuery(_
"Select Manufacturer from Win32_Processor")

'Loop through the results and store the type in compModel
for each objItem in colItems
compModel = objItem.Manufacturer
next

'Get a registry object
Set oReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & strComputer & "\root\default:StdRegProv")



'Check the computer type. If the processor is an Intel, then re-enable the driver
if compModel = "GenuineIntel" then
	oReg.SetDWORDValue HKEY_LOCAL_MACHINE,strKeyPath,strValueName,strValue
else
	
end if

' Exit
WSCript.Quit

