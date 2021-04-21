You will need a server with the SCCM Console and IIS installed. For this reason, I chose to run this on my SCCM site server. Copy the "OSDReporting.ps1" file to a known
location somewhere on the server. You'll reference this path later. Don't make any changes to this file. You'll specify the paramters in the scheduled task.

# Step 1 - IIS

1 - Right Click "Sites" and select "Create New Website"

![IIS Step 1 Example](ExampleImages/IIS-Step1-AddWebsite.PNG?raw=true)


2 - Give the site a name and path. Change the "IP Address" from  "All Unassigned" to the server's IP.
 
    My site will be named "OSD".
    My Physical path will be "C:\inetpub\OSD\"
    Leave the binding on http and port 80.

![Table Example](ExampleImages/IIS-Step2-NameAndPath.PNG?raw=true)


3 - You may have to refresh the list, but the new website should show up under "Sites" in IIS.

4 - Right click the site and select "Edit Bindings..."

5 - Double click the first binding and enter your site's name as the hostname

![Table Example](ExampleImages/IIS-Step5-Binding1.PNG?raw=true)

6 - Click "Add Binding", enter the server's IP address (use the drop down), and use port 80 again. 
    
    For the hostname, use your site's name but add the server's FQDN. My lab is "lab.hosp.org"
    
7 - Right click the site and select "Explore"

8 - Copy over the contents of the IIS folder into the site's folder.

![Table Example](ExampleImages/IIS-Step8-IISfolder.PNG?raw=true)


# Step 2 - DNS

1 - Create a CNAME in DNS for your new website. Note: You may have to work with your DNS administrator to get this done.

    Set the "Alias name" to the name of the website
    Set the "FQDN for target host" to the FQDN of the server you used in Step 1

![Table Example](ExampleImages/DNS-Step1-CNAME.PNG?raw=true)


# Step 3 - Powershell Script and a Scheduled Task

1 - Open Task Scheduler and create a new scheduled task

![Table Example](ExampleImages/ST-Step1-NewTask.PNG?raw=true)

2 - Give it a name and security options

    I named mine "OSD Reporting"
    I set my security options to use a service account. Note: This must be an administrator on the server and in the SCCM console

![Table Example](ExampleImages/ST-Step2-Name.PNG?raw=true)

3 - On the "Triggers" tab, select "New"

    Set it to Daily, reoccuring every 1 day
    Under Advanced settings, tell it to repeate the task every 5 minutes
    
![Table Example](ExampleImages/ST-Step3-Triggers.PNG?raw=true)

4 - On the "Actions" tab, select "New"  Note: This is where you'll put in your variables!!!

    For Action, select "start a program"
    Under Settings, for Program/script:  C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
    For Arguments:  -NoProfile -ExecutionPolicy Bypass -File "PATHTOosdreporting.ps1" -SQLServer "YOURSQLSERVER" -Database "YOURDATABASE" -TSAdvertisementID "YOURADVERTISEMENTID" -TaskSequenceID "YOURPACKAGEID" -IISPath "YOURIISPATH" -$MDM $False (set this to $true if using Modern Driver Management)
    
![Table Example](ExampleImages/ST-Step4-Actions1.PNG?raw=true)    
    
    

# That's it! Your html for the website should be created after the script finishes!  
Note: The script now runs every 5 minutes and the webpage auto refreshes every 90 seconds. 
