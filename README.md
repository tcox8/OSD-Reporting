# OSD-Reporting
This script will query the ConfigMgr database for Task Sequence Status Messages. The output is parsed and built into a webpage. The script should be setup to run as a scheduled task. 


The output will look like this. It lists every step of the task sequence as well as:
Image Start Time
Image Completed Time
Image Duration
Last Log received time
Name During Imaging

![Table Example](ExampleImages/Table.png?raw=true)

In my opinion, the best part about this is that it shows what task sequence step a computer fails out at during the imaging process. I've included the error text. This can be seen by hovering over the red check box as shown below:

![Table Example](ExampleImages/error.png?raw=true)


# Requirements
Powershell 3.0
IIS setup with this project's template file and Images folder

# Things to Edit
template.html file - edit columns for your task sequence steps
Varibales - edit $Query to include your advertisement ID(s) for your task sequence,
            edit $SQLServer to your SQL server
            edit $Database to your database
            edit variables in foreach loop to mimic the columns in template.html file
            edit $table to have same columns
            edit $template to point to the appropriate IIS location
