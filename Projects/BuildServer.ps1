param (
	[string]$Project="TPEStaging",	
	[string]$Server, 
	[string]$SubBuild, 
	[string]$Database,
	[switch]$AbortOnError=$true, 
	[switch]$quiet, 
	[String]$user,
	[String]$pass
    
)
<#
	.SYNOPSIS
		Executes .sql Files and Folderss of Files against a single server

	.DESCRIPTION
		A detailed description of the function.

	.PARAMETER  $Project
		The Subfolder name of the project to be built

	.PARAMETER  $Server
		The Server to be executed against

	.EXAMPLE
		PS C:\> Get-Something -ParameterA 'One value' -ParameterB 32

	.EXAMPLE
		PS C:\> Get-Something 'One value' 32

	.INPUTS
		System.String,System.Int32

	.OUTPUTS
		System.String

	.NOTES
		Additional information about the function go here.

	.LINK
		about_functions_advanced

	.LINK
		about_comment_based_help

#>

CLS 

[string]$ErrorMessage = $null 
[int]$ErrorClk=$null 

$ErrorActionPreference = "STOP"
$Error.Clear()

if (!($server)){$server='localhost'}
IF ($server -eq '.'){$server='localhost'}
if (!(Test-connection $server -quiet -Count 1))
{
	Write-host "unable to connect to server" -foreground red 
	Break;
}

#write-host ($myinvocation.mycommand.path + $args[1..2] ) 

$BuilderDIR = ($myinvocation.mycommand.path -replace $myinvocation.mycommand.name)
Set-Location FileSystem::$BuilderDIR

if (!($Database)){$Database=$Project} 
$global:servername=$Server
$global:Database=$Database 


#region Helper functions.

function RunScript 
{ param([string]$ScriptFile,[string]$tdb,[string]$user,[string]$pass)
	$ErrorActionPreference = "Continue" 
	$Error.Clear() 
	$Server = $global:servername
    Try 
                                                                                                                    {
#	$Server 
	$ScriptFile | Out-File -FilePath $LogFile -Append
		
    Write-host $ScriptFile
	$FP = (get-item $ScriptFile).Extension.ToLower() 
    switch ($fp) {
          ".sql" {		
	        IF (($pass) -and ($user)) <#User name and password provided#>
	        {
		        Invoke-sqlcmd -InputFile $ScriptFile -Server $Server -Database $tdb -Username $user -Password $pass  -erroraction Stop | Out-File -FilePath $LogFile -Append
	        }
	        elseif (($pass) -or ($user))
	        {
		        Throw "only one of username and password values was provided"
	        }
	        else 
	        {	
		        Invoke-sqlcmd -InputFile $ScriptFile -Server $Server -Database $tdb -erroraction Stop | Out-File -FilePath $LogFile -Append
     
	        }
                }
            ".ps1" {} #hmm 
            ".xml" {} #Do nothing 

            default 
            {
                Write-host ("Unknown file type " + $fp) 

            }
    }
	
    }
    catch [exception]
    {
	    $ErrorClk += 1
	    ("`r`n <Error> $Error <\Error>`r`n") | Out-File -FilePath $LogFile -Append

	
    }
	
}

function RunScriptsFolder { 
 param( [string]$ScriptPath,
        [string]$cdb,
        [string]$user,
        [string]$pass
        )
  
	Write-Host $ScriptPath -ForegroundColor Green 
	('Folder:' + $ScriptPath) | Out-File -FilePath $LogFile -Append
	IF (!(Test-Path FileSystem::$ScriptPath)){ 
		$ErrorMessage = "Path not found: $ScriptPath"
		
		Out-File -InputObject $ErrorMessage -FilePath $LogFile -Append
		throw $ErrorMessage;
		#Write-Host "Path not found: $ScriptPath" -ForegroundColor DarkYellow
		return;
	}

    $Scripts = ((gci -Path FileSystem::$ScriptPath) ) #| Where-Object {$_.Extension -eq '.sql'}
    :Scripts foreach($file in $Scripts) #
		    {
            
			    Try {
                    $file.fullname 
			        RunScript -ScriptFile $file.fullname $cdb $user $pass 
			    }
			    catch {
				    #write-error ("Error on " + $file.fullname)
                        if ($AbortOnError)
                        {
                            #Try{npp $LogFile}catch{ii $LogFile}         
                            Throw "Aborting on Error" 
                            Break Package;
                        }
		
			    }
		    }
	
}

  
Function RunBuild {
 param ([string]$Database, 
        [string]$user, 
        [string]$pass
        )

:Package foreach ($pkg in $Build.Project.Build)
    {
	    Write-host ("Package Name:" + $pkg.GetAttribute("Name")) -ForegroundColor Green 
	
        if ((!($SubBuild)) -or ($pkg.GetAttribute("Name") -eq $SubBuild))
                                                                                                                                                                                        {
	
	    :BuildProcess foreach ($BI in $pkg.Script)
	    {
		
			    $fp = $BuildPath+"\" + $BI.path 
			    [string]$tp = $BI.GetAttribute("type")
			    [string]$db = $BI.GetAttribute("Database")
                if (!($db)){$db = $global:Database}

            $msg = ("For $db Run " + $tp + ' ' +$fp ) 
            Write-host $msg -ForegroundColor White 
 		    
                Try 
                {
                    switch ($tp)
			        {
				        "file" 
				        { 
					        runscript -ScriptFile $fp -tdb $db -user $user -pass $pass 
				        }
				        "folder" 
				        { 
					        RunScriptsFolder -ScriptPath $fp -cdb $db -user $user -pass $pass 
				        }
				        default {
                            Write-Host "Type not defined "
                            }
			        }
                }
                catch [exception]
                {

                    $Error
                    $error.Clear()

                }
				
	    }
            Clear-Variable "db" -ErrorAction SilentlyContinue 
		    Clear-Variable "Server" -ErrorAction SilentlyContinue 
		    Clear-Variable "Database" -ErrorAction SilentlyContinue 
        }
        else {
	        "Package Skipped"
        }
    }
}


#endregion


#region Build Process

if (!($SubBuild)) {$SubBuild="Full"} 
#Write-host ($SubBuild) -ForegroundColor Yellow 

$BuildPath = $BuilderDIR + $Project
$BuilderDIR.substring(0,2) 

if ($BuilderDIR.substring(0,2) -match "\\") # UNC Building support
{ #moving LogFile to C$
	$LogFile = $env:USERPROFILE + '\desktop\'+ $Server+ "_"+$SubBuild+"_Build.log"
}
ELSE
{
	$LogFile = $BuilderDIR + $Project+"\Logs" # + $Server+ "_Build.log"
	if (!(Test-Path $LogFile)){New-Item $LogFile -ItemType Directory} 
	$LogFile = $LogFile +'\'+ $Server + "_" + $SubBuild + "_Build.log"
}
Try { "Testing Logfile path" | Out-File $LogFile} 
Catch 
	{
	Write-Error "Unable to create a log file to path $LogFile please make sure the path exists" 
	Break; 
}

        write-host ($LogFile) -foreground blue -BackgroundColor white  


$Project = $BuilderDIR + $Project + "\build.xml"
$project 

IF (!(Test-Path $Project)) 
{ 
	throw "Project Build.xml for $Project not found";
	Break;
}

	Try {
	[xml]$Build = Get-Content ($Project)
	    Write-Host ("$Project File Loaded") -ForegroundColor Green 
	}
	Catch
	{
		Npp $Project
		Write-Error $Error 
		Break; 
		
	}

	("Starting "+ $Project +" build on " + $Server + " at " + (Get-Date).ToString())  | Out-File -FilePath $LogFile -Force 
		
	Write-Host "RunBuild -S [$Server] -D [$database] Build $SubBuild" -ForegroundColor White 
		
			RunBuild $Database $user $pass 
		

#endregion 

IF ($ErrorClk) 
{
	Write-Host "There were $errorclk Errors" -ForegroundColor Red
    Try{npp $Project} catch{ii $Project}

    Try{npp $LogFile} catch{ii $LogFile}
} 

