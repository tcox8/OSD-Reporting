# New in Version 2.0
Reworked script to be considerably more dynamic.
Added TSAdvertisementID as a variable for easier editing by end user.
Added use of ConfigMgr module for importing TS and Driver steps for dynamic building of HTML.
Grouped Driver steps together and put them as one step (this keeps the horizontal table size down).
Added processing of skipped steps (when conditions are not met on TS Step). Hovering over the grey checkmark gives more detail.
Now results sort with newest computers at top.

</br>
</br>
</br>
</br>

# OSD-Reporting
This script will query the ConfigMgr database for Task Sequence Status Messages. The output is parsed and built into a webpage that will automatically refresh every 90 seconds. The script should be setup to run as a scheduled task. 


The output will look like this. It lists every step of the task sequence as well as:<br/>
Image Start Time<br/>
Image Completed Time<br/>
Image Duration<br/>
Last Log received time<br/>
Name During Imaging<br/>

![Table Example](ExampleImages/Table.png?raw=true)



In my opinion, the best part about this is that it shows what task sequence step a computer fails out at during the imaging process. I've included the error text. This can be seen by hovering over the red "x" box as shown below:

![Error Example](ExampleImages/Error.png?raw=true)


# Requirements
Powershell 3.0<br/>
IIS setup with the files from the "IIS" folder<br/>
Configuration Manager console installed<br/>

# Things to Edit to Make This Work For You
Varibales - edit $TSAdvertisementID to match your advertisement ID(s) for your task sequence, <br/>
            edit $SQLServer to your SQL server, <br/>
            edit $Database to your database, <br/>
            edit $IISPath to point to the appropriate IIS location
