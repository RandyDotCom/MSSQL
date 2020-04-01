CLS 
if ([System.Diagnostics.EventLog]::SourceExists("EIACollection") -eq $false) 
{ #used by ops.dbo.Raisealert 
	[System.Diagnostics.EventLog]::CreateEventSource("EIACollection", "Application")
}

Clear-Variable "MyLoc" -ErrorAction SilentlyContinue 
$MyLoc = ($myinvocation.mycommand.path -replace $myinvocation.mycommand.name)
$Thisdir = Get-item $MyLoc 
Set-location $Thisdir.PSParentPath
Set-location ((((Get-Location).Path) -split '::')[1]) 

.\BuildServer.ps1 Ops $Env:Computername 
.\BuildServer.ps1 Ops $Env:Computername Jobs 



