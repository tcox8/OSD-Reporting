# OSD-Reporting
This script will query the ConfigMgr database for Task Sequence Status Messages. The output is parsed and built into a webpage. The script should be setup to run as a scheduled task. 


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
IIS setup with this project's template file and Images folder<br/>

# Things to Edit to Make This Work For You
template.html file - edit columns for your task sequence steps <br/>
Varibales - edit $Query to include your advertisement ID(s) for your task sequence, <br/>
            edit $SQLServer to your SQL server, <br/>
            edit $Database to your database, <br/>
            edit variables in foreach loop to mimic the columns in template.html file, <br/>
            edit $table to have same columns, <br/>
            edit $template to point to the appropriate IIS location
