param ([int]$Buildid)
cls
$MyDir = ($myinvocation.mycommand.path -replace ("\\" + $myinvocation.mycommand.name))
Set-Location ($mydir) 
$builds = Get-Content ("Builds.xml") -ErrorAction SilentlyContinue 



