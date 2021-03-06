param (
	[string]$Server, 
	[string]$Database,
	[switch]$AbortOnError, 
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
#$Error.Clear()

$BuilderDIR = ($myinvocation.mycommand.path -replace $myinvocation.mycommand.name)
Set-Location FileSystem::$BuilderDIR

$global:servername = $Server 

#region Helper functions.
Function RunScript 
{ param([string]$ScriptFile,[string]$tdb,[string]$user,[string]$pass)
	$ErrorActionPreference = "Continue" 
	$Error.Clear() 
	$Server = $global:servername
Try 
{
#	$Server 
	$ScriptFile | Out-File -FilePath $LogFile -Append
		
	Write-Host ("$Server  $tdb  > $ScriptFile ") -ForegroundColor Gray
		
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
catch [exception]
{
	$ErrorClk += 1
	("`r`n <Error> $Error <\Error>`r`n") | Out-File -FilePath $LogFile -Append
	Write-Error $Error[0]
	
	$ErrorActionPreference = "STOP" 
	Set-Location FileSystem::$BuilderDIR
	$myinvocation.mycommand.path 
	Try{npp $LogFile}catch{ii $LogFile}
	ii $ScriptFile
	
	Throw "Aborting on Error" 
	$Error.Clear() 
	
}
	
}

Function RunFolder 
{ param([string]$ScriptPath,[string]$cdb,[string]$user,[string]$pass)
	Write-Host $ScriptPath -ForegroundColor Green 
	('Folder:' + $ScriptPath) | Out-File -FilePath $LogFile -Append
	IF (!(Test-Path FileSystem::$ScriptPath)){ 
		$ErrorMessage = "Path not found: $ScriptPath"
		
		Out-File -InputObject $ErrorMessage -FilePath $LogFile -Append
		throw $ErrorMessage;
		#Write-Host "Path not found: $ScriptPath" -ForegroundColor DarkYellow
		return;
	}
	$Scripts = ((gci -Path FileSystem::$ScriptPath)| Where-Object {$_.Extension -eq '.sql'} )
	
:Scripts foreach($file in $Scripts) #
		{
			Try {
				RunScript -ScriptFile $file.fullname $cdb $user $pass 
			}
			catch {
				write-error ("Error on " + $file.fullname)
#				break; 
				
			}
		}
	
}

#if (!($SubBuild)) {$SubBuild="Full"} 
function df
{ param ($tst,$dft) 
	if ($tft -eq $null) {return $dft} 
	if ($tft.Length() -eq 0){return $dft}
	return $tst 	
}

  
Function RunBuild
{ param ($Database, $user, $pass)
[string]$Empty=""
:Package foreach ($pkg in $Build.Project.Build)
{
	Write-host ("Package Name:" + $pkg.GetAttribute("Name")) -ForegroundColor Green 
	
if ((!($SubBuild)) -or ($pkg.GetAttribute("Name") -eq $SubBuild))
{
	  Write-host ($SubBuild) -ForegroundColor Yellow 
	  
	:BuildProcess foreach ($BI in $pkg.Script)
	{
		
			$fp = $BuildPath+"\" + $BI.path 
			$fp
			
			Clear-Variable db -ErrorAction SilentlyContinue 
			[string]$tp = $BI.GetAttribute("type")
			[string]$db = $BI.GetAttribute("Database")
			
#			$global:Database
			if (!($db)){$db = $global:Database}
			switch ($tp)
			{
				"file" 
				{ #Write-Host " $db File"
					runscript -ScriptFile $fp -tdb $db -user $user -pass $pass 
				}
				"folder" 
				{ #Write-Host (" $db Folder") 
					runfolder -ScriptPath $fp -cdb $db -user $user -pass $pass
				}
				default {Write-Host "Type not defined "}
			}
			Write-Host "`r`n" 
				
	}
		Clear-Variable Server -ErrorAction SilentlyContinue 
		Clear-Variable Database -ErrorAction SilentlyContinue 
}
else {
	"Package Skipped"
}
}
}


#endregion



#region Build Process

$BuildPath = $BuilderDIR 
$LogFile = $BuilderDIR+'Logs'
if (!(Test-Path $LogFile)){New-Item -Path $LogFile -ItemType Directory }
$LogFile = $LogFile +'\'+ $Server+ "_Build.log"

"Build Started for " + $Server | out-file $LogFile 

$Project = $BuilderDIR + "build.xml"

IF (!(Test-Path $Project)) 
{ 
	throw "Project Build.xml for $Project not found";
	$Error | out-file $LogFile -Append
	ii $LogFile 
	Break;
}

Try {
	[xml]$Build = Get-Content ($Project)
	Write-Host ("$Project File Loaded") -ForegroundColor Green 
}
Catch
{
	
	throw "Project Build.xml for $Project failed to load";
	$Error | out-file $LogFile -Append
	ii $LogFile 
	Break;
	
}


("Starting "+ $Project +" build on " + $Server + " at " + (Get-Date).ToString())  | Out-File -FilePath $LogFile -Append 
Write-Host "RunBuild -S [$Server] -D [$database]" -ForegroundColor White 

$global:Database = "Ops"
	
			RunBuild $Database $user $pass 
		

#endregion 

IF ($ErrorClk) 
{
	Write-Host "There were $errorclk Errors" -ForegroundColor Red
} 

Set-Location FileSystem::$BuilderDIR
Try{npp $LogFile} 
catch{ii $LogFile}




