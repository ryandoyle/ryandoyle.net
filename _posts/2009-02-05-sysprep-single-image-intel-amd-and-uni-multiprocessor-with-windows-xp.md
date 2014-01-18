---
layout: post
title:  "Sysprep: Single Image Intel/AMD & uni/multi-processor with Windows XP"
date:   2009-02-05 01:30:01
comments: true
---

The Windows XP sysprep tool is quite limited in the [hardware configurations that it supports](http://support.microsoft.com/kb/828287). With a few hacks and tweaks you can successfully deploy the same syspreped image to both Intel and AMD hardware and uni-processor as well as multi-processor CPU’s.

Before starting, there are a few assumptions

- The master hardware is a uni-processor Intel PC
- It is as old as possible (P4 vintage is good if you can get your hands on them, its what I used)
- You are competent using sysprep already and simply want to consolidate on the number of images

Uni/Multi-Processor
-------------------

This part is easy as there is enough documentation around. Unfortunately I cannot remember exactly where I found the solution so I cannot give credit. Add the following line to your unattended section of sysprep

    [unattended]
    UpdateHAL="ACPIAPIC_MP,%WINDIR%\Inf\Hal.inf"

Intel and AMD
-------------

This is a bit harder to achieve. If you image back an image created on an Intel PC to an AMD PC, it will BSOD before mini-setup runs. This is due to the Intel Power Managment driver that runs only if the PC is an Intel. To get around this, the driver needs to be disabled **before** the sysprep tool is run on the master and then re-enabled after the image is deployed on the target PC’s only if the PC is Intel. This does not break the Intel image and the driver will be re-enabled on the target PC’s if it is identified as an Intel.

First, you will need to create a batch script that disables the Intel driver and then runs sysprep. Create a file called SYSPREP.BAT with the following and put it in your Sysprep directory (EG: C:\sysprep).

{% highlight bat %}
@echo off
cd C:\SYSPREP

echo Enabling image for AMD and Intel processors
reg add "HKLM\SYSTEM\ControlSet001\Services\intelppm" /v Start /t REG_DWORD /d 4 /f

echo Running sysprep and shutting down.
sysprep.exe -forceshutdown -mini -reseal -quiet -activated
{% endhighlight %}

Next we need to create a VBScript that will be run after the image has been deployed to the target PC and mini-setup has run. This will check for the CPU manufacturer throught WMI and adjust the Intel driver accordingly. Create a file called **checkforintel.vbs** and enter the following text. You can also download the script [here](/assets/posts/checkforintel.vbs).

{% highlight vbnet %}
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
{% endhighlight %}

Save this file to **C:\WINDOWS\PostGhost\checkforintel.vbs**. This needs to be set to automatically run after the target PC has finished mini-setup. Make the following alterations to your sysprep.inf

<pre>
[Unattended]
    OemSkipEula=Yes
    UpdateInstalledDrivers=yes

[GuiUnattended]
    AdminPassword="adminpasshere"
    EncryptedAdminPassword=NO
    <strong>AutoLogon=Yes</strong>
    <strong>AutoLogonCount=1</strong>
    OEMSkipRegional=1
    TimeZone=255
    OemSkipWelcome=1

[GuiRunOnce]
    <strong>Command0="C:\WINDOWS\PostGhost\checkforintel.vbs"</strong>
</pre>

The admin password and and other settings are to ensure that mini-setup will run unattended. The vital parts of the process are bolded. These settings will make sure that the target PC will auto login and run the script. You may also want to add in another script so that the PC automatically reboots so it is not logged in as an administrator.

Conclusion
----------

After following these steps, you should now have a master image that is able to be deployed on all hardware regardless of CPU brand or type of CPU. I will write a tutorial later which covers the whole sysprep process including:

- Building in mass storage drivers
- Building in drivers for all your hardware platforms
- Debugging drivers for hardware platforms
- Automatically renaming the PC’s based on MAC address
- Automatically joining the Active Directory domain

EDIT: Added the suggestion from Bastian to look for the “GenuineIntel” string instead of AMD computer models so each model doesn’t have to be entered into the script manually. Thanks for the advice : D

