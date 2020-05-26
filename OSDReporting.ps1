#############################################################################
# Author  : Tyler Cox
#
# Version : 1.0.0
# Created : 02/25/2020
# Modified : 
#
# Purpose : This script will query the ConfigMgr database for Task Sequence Status Messages.
#           The output is parsed and built into a webpage.
#
#           Things to edit: template.html file - edit columns for your task sequence steps
#                           Varibales - edit $Query to include your advertisement ID(s) for your task sequence,
#                                       edit $SQLServer to your SQL server
#                                       edit $Database to your database
#                                       edit variables in foreach loop to mimic the columns in template.html file
#                                       edit $table to have same columns
#                                       edit $template to point to the appropriate IIS location
#
# Requirements: Powershell 3.0, IIS Setup with this project's template file
#
# Change Log: Ver 1.0.0 - Initial Release
#
#############################################################################


[CmdletBinding(SupportsShouldProcess=$True)]
    param
        (
        [Parameter(Mandatory=$False, HelpMessage="The name of the computer to retrieve status message for")]
            [string]$ComputerName,
        [Parameter(Mandatory=$False, HelpMessage="The number of hours past in which to retrieve status messages")]
            [int]$TimeInHours = "36",
        [Parameter(Mandatory=$False)]
            [switch]$CSV,
        [Parameter(Mandatory=$False)]
            [switch]$GridView,
        [Parameter(Mandatory=$False, HelpMessage="The SQL server name (and instance name where appropriate)")]
            [string]$SQLServer = “”,
        [Parameter(Mandatory=$False, HelpMessage="The name of the ConfigMgr database")]
            [string]$Database = “”,
        [Parameter(Mandatory=$False, HelpMessage="The location of the smsmsgs directory containing the message DLLs")]
            [string]$SMSMSGSLocation = "C:\Program Files\Microsoft Configuration Manager\bin\X64\system32\smsmsgs"
        )
 

# Function to get the date difference
Function Get-DateDifference
    {
        param
        (
            [Parameter(Mandatory=$true, HelpMessage="The start date")]
                $StartDate,
            [Parameter(Mandatory=$true, HelpMessage="The end date")]
                $EndDate 
        )
        $TimeDiff = New-TimeSpan -Start $StartDate -End $EndDate
        if ($TimeDiff.Seconds -lt 0) {
            $Hrs = ($TimeDiff.Hours) + 23
            $Mins = ($TimeDiff.Minutes) + 59
            $Secs = ($TimeDiff.Seconds) + 59 }
        else {
            $Hrs = $TimeDiff.Hours
            $Mins = $TimeDiff.Minutes
            $Secs = $TimeDiff.Seconds }
        $Difference = '{0:00}:{1:00}:{2:00}' -f $Hrs,$Mins,$Secs
        Return $Difference
    }


# Function to get the status message description
function Get-StatusMessage {
param (
    $iMessageID,
    [ValidateSet("srvmsgs.dll","provmsgs.dll","climsgs.dll")]$DLL,
    [ValidateSet("Informational","Warning","Error")]$Severity,
    $InsString1,
    $InsString2,
    $InsString3,
    $InsString4,
    $InsString5,
    $InsString6,
    $InsString7,
    $InsString8,
    $InsString9,
    $InsString10
      )
 
#Load DLLs. These contain the status message query text
if ($DLL -eq "srvmsgs.dll")
    {$stringPathToDLL = "$SMSMSGSLocation\srvmsgs.dll"}
if ($DLL -eq "provmsgs.dll")
    {$stringPathToDLL = "$SMSMSGSLocation\provmsgs.dll"}
if ($DLL -eq "climsgs.dll")
    {$stringPathToDLL = "$SMSMSGSLocation\climsgs.dll"}
 
#Load Status Message Lookup DLL into memory and get pointer to memory
$ptrFoo = $Win32LoadLibrary::LoadLibrary($stringPathToDLL.ToString())
$ptrModule = $Win32GetModuleHandle::GetModuleHandle($stringPathToDLL.ToString()) 
 
if ($Severity -eq "Informational")
    {$code = 1073741824}
if ($Severity -eq "Warning")
    {$code = 2147483648}
if ($Severity -eq "Error")
    {$code = 3221225472}
 
$result = $Win32FormatMessage::FormatMessage($flags, $ptrModule, $Code -bor $iMessageID, 0, $stringOutput, $sizeOfBuffer, $stringArrayInput)
if ($result -gt 0)
    {
        # Add insert strings to message
        $objMessage = New-Object System.Object
        $objMessage | Add-Member -type NoteProperty -name MessageString -value $stringOutput.ToString().Replace("%11","").Replace("%12","").Replace("%3%4%5%6%7%8%9%10","").Replace("%1",$InsString1).Replace("%2",$InsString2).Replace("%3",$InsString3).Replace("%4",$InsString4).Replace("%5",$InsString5).Replace("%6",$InsString6).Replace("%7",$InsString7).Replace("%8",$InsString8).Replace("%9",$InsString9).Replace("%10",$InsString10)
    }
$objMessage
}
 
# Open a database connection
$connectionString = “Server=$SQLServer;Database=$database;Integrated Security=SSPI;”
$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString
$connection.Open()
 
# Define the SQl query
#2372004C and 2372004B are the advertisement IDs for the Windows 10 task sequence. 
$Query = "
select smsgs.RecordID, 
CASE smsgs.Severity
WHEN -1073741824 THEN 'Error'
WHEN 1073741824 THEN 'Informational'
WHEN -2147483648 THEN 'Warning'
ELSE 'Unknown'
END As 'SeverityName',
case smsgs.MessageType
WHEN 256 THEN 'Milestone'
WHEN 512 THEN 'Detail'
WHEN 768 THEN 'Audit'
WHEN 1024 THEN 'NT Event'
ELSE 'Unknown'
END AS 'Type',
smsgs.MessageID, smsgs.Severity, smsgs.MessageType, smsgs.ModuleName,modNames.MsgDLLName, smsgs.Component,
smsgs.MachineName, smsgs.Time, smsgs.SiteCode, smwis.InsString1,
smwis.InsString2, smwis.InsString3, smwis.InsString4, smwis.InsString5,
smwis.InsString6, smwis.InsString7, smwis.InsString8, smwis.InsString9,
smwis.InsString10, v_StatMsgAttributes.*, DATEDIFF(hour,dateadd(hh,-5,smsgs.Time),GETDATE()) as DateDiffer
from v_StatusMessage smsgs
join v_StatMsgWithInsStrings smwis on smsgs.RecordID = smwis.RecordID
join v_StatMsgModuleNames modNames on smsgs.ModuleName = modNames.ModuleName
join v_StatMsgAttributes on v_StatMsgAttributes.RecordID = smwis.RecordID
where (smsgs.Component = 'Task Sequence Engine' or smsgs.Component = 'Task Sequence Action')
and v_StatMsgAttributes.AttributeID = 401 
and (v_StatMsgAttributes.AttributeValue = '2372004C' or v_StatMsgAttributes.AttributeValue = '2372004B')
and DATEDIFF(hour,smsgs.Time,GETDATE()) < '24'
Order by smsgs.Time DESC
"

 
# Run the query
$command = $connection.CreateCommand()
$command.CommandText = $query
$reader = $command.ExecuteReader()
$table = new-object “System.Data.DataTable”
$table.Load($reader)
 
# Close the connection
$connection.Close()
 
#Start PInvoke Code
$sigFormatMessage = @'
[DllImport("kernel32.dll")]
public static extern uint FormatMessage(uint flags, IntPtr source, uint messageId, uint langId, StringBuilder buffer, uint size, string[] arguments);
'@ 
 
$sigGetModuleHandle = @'
[DllImport("kernel32.dll")]
public static extern IntPtr GetModuleHandle(string lpModuleName);
'@ 
 
$sigLoadLibrary = @'
[DllImport("kernel32.dll")]
public static extern IntPtr LoadLibrary(string lpFileName);
'@ 
 
$Win32FormatMessage = Add-Type -MemberDefinition $sigFormatMessage -name "Win32FormatMessage" -namespace Win32Functions -PassThru -Using System.Text
$Win32GetModuleHandle = Add-Type -MemberDefinition $sigGetModuleHandle -name "Win32GetModuleHandle" -namespace Win32Functions -PassThru -Using System.Text
$Win32LoadLibrary = Add-Type -MemberDefinition $sigLoadLibrary -name "Win32LoadLibrary" -namespace Win32Functions -PassThru -Using System.Text
#End PInvoke Code 
 
$sizeOfBuffer = [int]16384
$stringArrayInput = {"%1","%2","%3","%4","%5", "%6", "%7", "%8", "%9"}
$flags = 0x00000800 -bor 0x00000200
$stringOutput = New-Object System.Text.StringBuilder $sizeOfBuffer 
 
# Put desired fields into an object for each result
$StatusMessages = @()
foreach ($Row in $Table.Rows)
    {
        $Params = @{
            iMessageID = $Row.MessageID
            DLL = $Row.MsgDLLName
            Severity = $Row.SeverityName
            InsString1 = $Row.InsString1
            InsString2 = $Row.InsString2
            InsString3 = $Row.InsString3
            InsString4 = $Row.InsString4
            InsString5 = $Row.InsString5
            InsString6 = $Row.InsString6
            InsString7 = $Row.InsString7
            InsString8 = $Row.InsString8
            InsString9 = $Row.InsString9
            InsString10 = $Row.InsString10
            }
        $Message = Get-StatusMessage @params
 
        $StatusMessage = New-Object psobject
        Add-Member -InputObject $StatusMessage -Name Severity -MemberType NoteProperty -Value $Row.SeverityName
        Add-Member -InputObject $StatusMessage -Name Type -MemberType NoteProperty -Value $Row.Type
        Add-Member -InputObject $StatusMessage -Name SiteCode -MemberType NoteProperty -Value $Row.SiteCode
        Add-Member -InputObject $StatusMessage -Name "Date / Time" -MemberType NoteProperty -Value $Row.Time.AddHours(-5)
        Add-Member -InputObject $StatusMessage -Name System -MemberType NoteProperty -Value $Row.MachineName
        Add-Member -InputObject $StatusMessage -Name Component -MemberType NoteProperty -Value $Row.Component
        Add-Member -InputObject $StatusMessage -Name Module -MemberType NoteProperty -Value $Row.ModuleName
        Add-Member -InputObject $StatusMessage -Name MessageID -MemberType NoteProperty -Value $Row.MessageID
        Add-Member -InputObject $StatusMessage -Name Description -MemberType NoteProperty -Value $Message.MessageString
        $StatusMessages += $StatusMessage
    }






$html = @() #Create a blank array
$Messages = $StatusMessages | Sort-Object -Property "Date / Time" | Group-Object -Property System #Grab our status messages, sort and group them.

ForEach ($Computer in $Messages) 
    {         
        #Null out our variables
        $Script:ImageStarted = $null
        $Script:ImageCompleted = $null
        $Script:ImageDuration = $null
        $Script:NameDuringImaging = $null
        $Script:01RestartinWinPE = $null
        $Script:02PartitionDisk0 = $null
        $Script:03ConnecttoNetworkFolder = $null
        $Script:04CopyFileforWBC = $null
        $Script:05RunPowershellScript = $null
        $Script:06ApplyOperatingSystem = $null
        $Script:07ApplyDeviceDrivers = $null
        $Script:08ApplyWindowsSettings = $null
        $Script:09ApplyNetworkSettings = $null
        $Script:10SetupWindowsandConfigMgr = $null
        $Script:11KillSomeTime = $null
        $Script:12JoinDomain = $null
        $Script:13RestartComputer = $null
        $Script:14InstallAppAlertus = $null
        $Script:15InstallAppLAPS = $null
        $Script:16InstallAppMcAfeeAgent = $null
        $Script:17InstallUpdates = $null
        $Script:18EnableMouse = $null
        $Script:19RestartComputer = $null
        $Script:20RunWindowsBuildChecker = $null
        $Script:21DisableMouse = $null
        $Script:22ExitTaskSequence = $null
        

        $green = '<img src="images/checks/greenCheckMark_round.png" alt="Green Check Mark">' #Green is always the same so we can declare it here.
        ForEach ($statmsg in $Computer.Group)
            {      
                $NameDuringImaging = $statmsg.System
                If ($statmsg.MessageID -eq "11144") { $ImageStarted = $statmsg."Date / Time"} #MessageID 11144 is the start of a task sequence
                If (($statmsg.Description -like "*Restart in Windows PE*") -AND ($statmsg.Severity -eq "Informational")) 
                    {
                        $01RestartinWinPE = $green
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                ElseIf (($statmsg.Description -like "*Restart in Windows PE*") -AND ($statmsg.Severity -eq "Error")) 
                    {
                        $errortext = $statmsg.Description.replace('"','&quot;') #replace quotes so the html doesn't truncate
                        $01RestartinWinPE = '<a href=" " title="' + $errortext + '"><img src="images/checks/redCheckMark_round.png" alt="Red Check Mark"></a>' #set pic to red and include error text
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                If ((($statmsg.Description -like "*Partition Disk 0 - UEFI*") -OR ($statmsg.Description -like "*Partition Disk 0 - BIOS*")) -AND ($statmsg.Severity -eq "Informational")) 
                    {
                        $02PartitionDisk0 = $green
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                ElseIf ((($statmsg.Description -like "*Partition Disk 0 - UEFI*") -OR ($statmsg.Description -like "*Partition Disk 0 - BIOS*")) -AND ($statmsg.Severity -eq "Error")) 
                    {
                        $errortext = $statmsg.Description.replace('"','&quot;') #replace quotes so the html doesn't truncate
                        $02PartitionDisk0 = '<a href=" " title="' + $errortext + '"><img src="images/checks/redCheckMark_round.png" alt="Red Check Mark"></a>' #set pic to red and include error text
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                If (($statmsg.Description -like "*Connect to Network Folder*") -AND ($statmsg.Severity -eq "Informational")) 
                    {
                        $03ConnecttoNetworkFolder = $green
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                ElseIf (($statmsg.Description -like "*Connect to Network Folder*") -AND ($statmsg.Severity -eq "Error")) 
                    {
                        $errortext = $statmsg.Description.replace('"','&quot;') #replace quotes so the html doesn't truncate
                        $03ConnecttoNetworkFolder = '<a href=" " title="' + $errortext + '"><img src="images/checks/redCheckMark_round.png" alt="Red Check Mark"></a>' #set pic to red and include error text
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                If (($statmsg.Description -like "*Copy File for WBC*") -AND ($statmsg.Severity -eq "Informational")) 
                    {
                        $04CopyFileforWBC = $green
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                ElseIf (($statmsg.Description -like "*Copy File for WBC*") -AND ($statmsg.Severity -eq "Error")) 
                    {
                        $errortext = $statmsg.Description.replace('"','&quot;') #replace quotes so the html doesn't truncate
                        $04CopyFileforWBC = '<a href=" " title="' + $errortext + '"><img src="images/checks/redCheckMark_round.png" alt="Red Check Mark"></a>' #set pic to red and include error text
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                If (($statmsg.Description -like "*Run Powershell Script*") -AND ($statmsg.Severity -eq "Informational")) 
                    {
                        $05RunPowershellScript = $green
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                ElseIf (($statmsg.Description -like "*Run Powershell Script*") -AND ($statmsg.Severity -eq "Error")) 
                    {
                        $errortext = $statmsg.Description.replace('"','&quot;') #replace quotes so the html doesn't truncate
                        $05RunPowershellScript = '<a href=" " title="' + $errortext + '"><img src="images/checks/redCheckMark_round.png" alt="Red Check Mark"></a>' #set pic to red and include error text
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                If (($statmsg.Description -like "*Apply Operating System*") -AND ($statmsg.Severity -eq "Informational")) 
                    {
                        $06ApplyOperatingSystem = $green
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                ElseIf (($statmsg.Description -like "*Apply Operating System*") -AND ($statmsg.Severity -eq "Error")) 
                    {
                        $errortext = $statmsg.Description.replace('"','&quot;') #replace quotes so the html doesn't truncate
                        $06ApplyOperatingSystem = '<a href=" " title="' + $errortext + '"><img src="images/checks/redCheckMark_round.png" alt="Red Check Mark"></a>' #set pic to red and include error text
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                If (($statmsg.Description -like "*(Apply Device Drivers)*") -AND ($statmsg.Severity -eq "Informational")) 
                    {
                        $07ApplyDeviceDrivers = $green
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                ElseIf (($statmsg.Description -like "*(Apply Device Drivers)*") -AND ($statmsg.Severity -eq "Error")) 
                    {
                        $errortext = $statmsg.Description.replace('"','&quot;') #replace quotes so the html doesn't truncate
                        $07ApplyDeviceDrivers = '<a href=" " title="' + $errortext + '"><img src="images/checks/redCheckMark_round.png" alt="Red Check Mark"></a>' #set pic to red and include error text
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                If (($statmsg.Description -like "*Apply Windows Settings*") -AND ($statmsg.Severity -eq "Informational")) 
                    {
                        $08ApplyWindowsSettings = $green
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                ElseIf (($statmsg.Description -like "*Apply Windows Settings*") -AND ($statmsg.Severity -eq "Error")) 
                    {
                        $errortext = $statmsg.Description.replace('"','&quot;') #replace quotes so the html doesn't truncate
                        $08ApplyWindowsSettings = '<a href=" " title="' + $errortext + '"><img src="images/checks/redCheckMark_round.png" alt="Red Check Mark"></a>' #set pic to red and include error text
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                If (($statmsg.Description -like "*Apply Network Settings*") -AND ($statmsg.Severity -eq "Informational")) 
                    {
                        $09ApplyNetworkSettings = $green
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                ElseIf (($statmsg.Description -like "*Apply Network Settings*") -AND ($statmsg.Severity -eq "Error")) 
                    {
                        $errortext = $statmsg.Description.replace('"','&quot;') #replace quotes so the html doesn't truncate
                        $09ApplyNetworkSettings = '<a href=" " title="' + $errortext + '"><img src="images/checks/redCheckMark_round.png" alt="Red Check Mark"></a>' #set pic to red and include error text
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                If (($statmsg.Description -like "*Setup Windows and Configuration Manager*") -AND ($statmsg.Severity -eq "Informational")) 
                    {
                        $10SetupWindowsandConfigMgr = $green
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                ElseIf (($statmsg.Description -like "*Setup Windows and Configuration Manager*") -AND ($statmsg.Severity -eq "Error")) 
                    {
                        $errortext = $statmsg.Description.replace('"','&quot;') #replace quotes so the html doesn't truncate
                        $10SetupWindowsandConfigMgr = '<a href=" " title="' + $errortext + '"><img src="images/checks/redCheckMark_round.png" alt="Red Check Mark"></a>' #set pic to red and include error text
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog                                               
                    }
                If (($statmsg.Description -like "*Kill Some Time*") -AND ($statmsg.Severity -eq "Informational")) 
                    {
                        $11KillSomeTime = $green
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                ElseIf (($statmsg.Description -like "*Kill Some Time*") -AND ($statmsg.Severity -eq "Error")) 
                    {
                        $errortext = $statmsg.Description.replace('"','&quot;') #replace quotes so the html doesn't truncate
                        $11KillSomeTime = '<a href=" " title="' + $errortext + '"><img src="images/checks/redCheckMark_round.png" alt="Red Check Mark"></a>' #set pic to red and include error text
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                If (($statmsg.Description -like "*Join Domain*") -AND ($statmsg.Severity -eq "Informational")) 
                    {
                        $12JoinDomain = $green
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                ElseIf (($statmsg.Description -like "*Join Domain*") -AND ($statmsg.Severity -eq "Error")) 
                    {
                        $errortext = $statmsg.Description.replace('"','&quot;') #replace quotes so the html doesn't truncate
                        $12JoinDomain = '<a href=" " title="' + $errortext + '"><img src="images/checks/redCheckMark_round.png" alt="Red Check Mark"></a>' #set pic to red and include error text
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                If (($statmsg.Description -like "*system reboot initiated by the action (Join Domain)*") -AND ($statmsg.Severity -eq "Informational")) 
                    {
                        $13RestartComputer = $green
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                ElseIf (($statmsg.Description -like "*system reboot initiated by the action (Join Domain)*") -AND ($statmsg.Severity -eq "Error")) 
                    {
                        $errortext = $statmsg.Description.replace('"','&quot;') #replace quotes so the html doesn't truncate
                        $13RestartComputer = '<a href=" " title="' + $errortext + '"><img src="images/checks/redCheckMark_round.png" alt="Red Check Mark"></a>' #set pic to red and include error text
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                If (($statmsg.Description -like "*application Alertus Desktop Alert Client*") -AND ($statmsg.Severity -eq "Informational")) 
                    {
                        $14InstallAppAlertus = $green
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                ElseIf (($statmsg.Description -like "*application Alertus Desktop Alert Client*") -AND ($statmsg.Severity -eq "Error")) 
                    {
                        $errortext = $statmsg.Description.replace('"','&quot;') #replace quotes so the html doesn't truncate
                        $14InstallAppAlertus = '<a href=" " title="' + $errortext + '"><img src="images/checks/redCheckMark_round.png" alt="Red Check Mark"></a>' #set pic to red and include error text
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                If (($statmsg.Description -like "*application Local Administrator Password Solution*") -AND ($statmsg.Severity -eq "Informational")) 
                    {
                        $15InstallAppLAPS = $green
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                ElseIf (($statmsg.Description -like "*application Local Administrator Password Solution*") -AND ($statmsg.Severity -eq "Error")) 
                    {
                        $errortext = $statmsg.Description.replace('"','&quot;') #replace quotes so the html doesn't truncate
                        $15InstallAppLAPS = '<a href=" " title="' + $errortext + '"><img src="images/checks/redCheckMark_round.png" alt="Red Check Mark"></a>' #set pic to red and include error text
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                If (($statmsg.Description -like "*application McAfee Agent*") -AND ($statmsg.Severity -eq "Informational")) 
                    {
                        $16InstallAppMcAfeeAgent= $green
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                ElseIf (($statmsg.Description -like "*application McAfee Agent*") -AND ($statmsg.Severity -eq "Error")) 
                    {
                        $errortext = $statmsg.Description.replace('"','&quot;') #replace quotes so the html doesn't truncate
                        $16InstallAppMcAfeeAgent = '<a href=" " title="' + $errortext + '"><img src="images/checks/redCheckMark_round.png" alt="Red Check Mark"></a>' #set pic to red and include error text
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                If (($statmsg.Description -like "*(Install Updates)*") -AND ($statmsg.Severity -eq "Informational")) 
                    {
                        $17InstallUpdates= $green
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                ElseIf (($statmsg.Description -like "*(Install Updates)*") -AND ($statmsg.Severity -eq "Error")) 
                    {
                        $errortext = $statmsg.Description.replace('"','&quot;') #replace quotes so the html doesn't truncate
                        $17InstallUpdates = '<a href=" " title="' + $errortext + '"><img src="images/checks/redCheckMark_round.png" alt="Red Check Mark"></a>' #set pic to red and include error text
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                If (($statmsg.Description -like "*(Enable Mouse)*") -AND ($statmsg.Severity -eq "Informational")) 
                    {
                        $18EnableMouse= $green
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                ElseIf (($statmsg.Description -like "*(Enable Mouse)*") -AND ($statmsg.Severity -eq "Error")) 
                    {
                        $errortext = $statmsg.Description.replace('"','&quot;') #replace quotes so the html doesn't truncate
                        $18EnableMouse = '<a href=" " title="' + $errortext + '"><img src="images/checks/redCheckMark_round.png" alt="Red Check Mark"></a>' #set pic to red and include error text
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                If (($statmsg.Description -like "*(Restart Computer - 1)*") -AND ($statmsg.Severity -eq "Informational")) 
                    {
                        $19RestartComputer = $green
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                ElseIf (($statmsg.Description -like "*(Restart Computer - 1)*") -AND ($statmsg.Severity -eq "Error")) 
                    {
                        $errortext = $statmsg.Description.replace('"','&quot;') #replace quotes so the html doesn't truncate
                        $19RestartComputer = '<a href=" " title="' + $errortext + '"><img src="images/checks/redCheckMark_round.png" alt="Red Check Mark"></a>' #set pic to red and include error text
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                If (($statmsg.Description -like "*(Run WBC (Windows Build Checker))*") -AND ($statmsg.Severity -eq "Informational")) 
                    {
                        $20RunWindowsBuildChecker = $green
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                ElseIf (($statmsg.Description -like "*(Run WBC (Windows Build Checker))*") -AND ($statmsg.Severity -eq "Error")) 
                    {
                        $errortext = $statmsg.Description.replace('"','&quot;') #replace quotes so the html doesn't truncate
                        $20RunWindowsBuildChecker = '<a href=" " title="' + $errortext + '"><img src="images/checks/redCheckMark_round.png" alt="Red Check Mark"></a>' #set pic to red and include error text
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                If (($statmsg.Description -like "*(Disable Mouse)*") -AND ($statmsg.Severity -eq "Informational")) 
                    {
                        $21DisableMouse = $green
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                ElseIf (($statmsg.Description -like "*(Disable Mouse)*") -AND ($statmsg.Severity -eq "Error")) 
                    {
                        $errortext = $statmsg.Description.replace('"','&quot;') #replace quotes so the html doesn't truncate
                        $21DisableMouse = '<a href=" " title="' + $errortext + '"><img src="images/checks/redCheckMark_round.png" alt="Red Check Mark"></a>' #set pic to red and include error text
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $LastLog
                    }
                If (($statmsg.MessageID -eq "11171") -or ($statmsg.MessageID -eq "11143")) 
                    {
                        $22ExitTaskSequence = $green
                        $ImageCompleted = $statmsg."Date / Time"
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $ImageCompleted
                    }
                If ($statmsg.MessageID -eq "11141") #Failed Task Sequence
                    {
                        $errortext = $statmsg.Description.replace('"','&quot;') #replace quotes so the html doesn't truncate
                        $22ExitTaskSequence = '<a href=" " title="' + $errortext + '"><img src="images/checks/redCheckMark_round.png" alt="Red Check Mark"></a>' #set pic to red and include error text
                        $ImageCompleted = $statmsg."Date / Time"
                        $LastLog = $statmsg."Date / Time"
                        $ImageDuration = Get-DateDifference -StartDate $ImageStarted -EndDate $ImageCompleted
                    }

                #Build our HTML Table
                $table = '
                <tr class="row100">
                    <td class="column100 column2" data-column="column2">'+ $ImageStarted +'</td>
                    <td class="column100 column3" data-column="column3">'+ $ImageCompleted +'</td>
                    <td class="column100 column4" data-column="column4">'+ $ImageDuration +'</td>
                    <td class="column100 column5" data-column="column5">'+ $LastLog +'</td>
                    <td class="column100 column6" data-column="column6">'+ $NameDuringImaging +'</td>
                    <td class="column100 column8" data-column="column8">'+ $01RestartinWinPE +'</td>
                    <td class="column100 column9" data-column="column9">'+ $02PartitionDisk0 +'</td>
                    <td class="column100 column10" data-column="column10">'+ $03ConnecttoNetworkFolder +'</td>
                    <td class="column100 column11" data-column="column11">'+ $04CopyFileforWBC +'</td>
                    <td class="column100 column12" data-column="column12">'+ $05RunPowershellScript +'</td>
                    <td class="column100 column13" data-column="column13">'+ $06ApplyOperatingSystem +'</td>
                    <td class="column100 column14" data-column="column14">'+ $07ApplyDeviceDrivers +'</td>
                    <td class="column100 column15" data-column="column15">'+ $08ApplyWindowsSettings +'</td>
                    <td class="column100 column16" data-column="column16">'+ $09ApplyNetworkSettings +'</td>
                    <td class="column100 column17" data-column="column17">'+ $10SetupWindowsandConfigMgr +'</td>
                    <td class="column100 column18" data-column="column18">'+ $11KillSomeTime +'</td>
                    <td class="column100 column19" data-column="column19">'+ $12JoinDomain +'</td>
                    <td class="column100 column20" data-column="column20">'+ $13RestartComputer +'</td>
                    <td class="column100 column21" data-column="column21">'+ $14InstallAppAlertus +'</td>
                    <td class="column100 column22" data-column="column22">'+ $15InstallAppLAPS +'</td>
                    <td class="column100 column23" data-column="column23">'+ $16InstallAppMcAfeeAgent +'</td>
                    <td class="column100 column25" data-column="column25">'+ $17InstallUpdates +'</td>
                    <td class="column100 column26" data-column="column26">'+ $18EnableMouse +'</td>
                    <td class="column100 column27" data-column="column27">'+ $19RestartComputer +'</td>
                    <td class="column100 column28" data-column="column28">'+ $20RunWindowsBuildChecker +'</td>
                    <td class="column100 column29" data-column="column29">'+ $21DisableMouse +'</td>
                    <td class="column100 column29" data-column="column29">'+ $22ExitTaskSequence +'</td>
                </tr>'

            }
            If ($ImageStarted -ne $null) 
                {
                    #Build the array. The HTML variable is used in the $template file. 
                    $html = $html += $table
                }
    }

#Get the template file
$template = (Get-Content -Path C:\inetpub\OSDReporting\template.html -raw)
#Place variables and new $html into the template file and rename it as index.html
Invoke-Expression "@`"`r`n$template`r`n`"@" | Set-Content -Path "C:\inetpub\OSDReporting\index.html"