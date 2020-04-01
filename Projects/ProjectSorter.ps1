param($project)
$myinvocation.mycommand.path
$MyDir = ($myinvocation.mycommand.path -replace ('\\' + $myinvocation.mycommand.name))
Pushd $MyDir 
#$ErrorLog = $MyDir + ($myinvocation.mycommand.name).Replace(".ps1",".xml")  
#$ErrorLog 
$Error.Clear()

if (!(test-path ($project)))
{
    Throw "$MyDir $project not found"
    Break;
}

foreach ($fl in (GCI ($project)| ?{$_.Extension -eq ".sql"}))
{
    $namearray = $fl.name.Split('.')
    $idx = $namearray.count-2 
    $tgt = $namearray[$idx]

    if ($idx -gt 0) 
    {
        $loc = $MyDir +'\'+ $project+'\'+$tgt 
        #$loc 
        New-Item -Path $loc -ItemType Directory -ErrorAction SilentlyContinue 
        $fl | Move-Item -Destination $loc -Force #-WhatIf 
    }
    else
    {
        $loc = $MyDir +'\'+ $project+'\Scripts' #+$tgt 
        #$loc 
        New-Item -Path $loc -ItemType Directory -ErrorAction SilentlyContinue 
        $fl | Move-Item -Destination $loc -Force 
    }
    
}

$defBuildxml='<Project>
  <Build Name="Full" Description="End to end underlying objects">
	<Script type="folder" path="Database" />
	<Script type="folder" path="Schema" />
	<Script type="folder" path="UserDefinedDataType" />
	<Script type="folder" path="UserDefinedTableType" />
    <Script type="folder" path="Table" />
    <Script type="folder" path="PartitionScheme" />
	<Script type="folder" path="PartitionFunction" />
    <Script type="folder" path="UserDefinedFunction" />
	<Script type="folder" path="View" />
	<Script type="folder" path="Synonym" />
	<Script type="folder" path="Role" />
	<Script type="folder" path="User" />
	<Script type="folder" path="StoredProcedure" />
	<!-- PreRequisites to Procedures 
	Synonym
	-->
	<Script type="folder" path="PlanGuide" />
	<Script type="file" path="Scripts\Validate.sql" /> 
   </Build>
   <Build Name="Jobs" Description="SQL Server Maintenance Jobs">
   	<!-- Jobs Recommended -->
	</Build>
<!-- Example 
	<Script type="folder" path="Procedures" />  
	<Script type="file" path="Jobs\dbaDBCC-CheckDB.sql" Database="msdb" /> 
-->	
</Project>'
$TP = $MyDir+'\'+$project+'\build.xml'
if (!(Test-Path $tp))
{

$defBuildxml='<Project>
  <Build Name="Full" Description="End to end underlying objects">
	<Script type="folder" path="Database" />
	<Script type="folder" path="Schema" />
	<Script type="folder" path="UserDefinedDataType" />
	<Script type="folder" path="UserDefinedTableType" />
    <Script type="folder" path="Table" />
    <Script type="folder" path="PartitionScheme" />
	<Script type="folder" path="PartitionFunction" />
    <Script type="folder" path="UserDefinedFunction" />
	<Script type="folder" path="View" />
	<Script type="folder" path="Synonym" />
	<Script type="folder" path="Role" />
	<Script type="folder" path="User" />
	<Script type="folder" path="StoredProcedure" />
	<!-- PreRequisites to Procedures 
	Synonym
	-->
	<Script type="folder" path="PlanGuide" />
	<Script type="file" path="Scripts\Validate.sql" /> 
   </Build>
   <Build Name="Jobs" Description="SQL Server Maintenance Jobs">
   	<!-- Jobs Recommended -->
	</Build>
<!-- Example 
	<Script type="folder" path="Procedures" />  
	<Script type="file" path="Jobs\dbaDBCC-CheckDB.sql" Database="msdb" /> 
-->	
</Project>' | Out-File $tp -Encoding utf8 

}
Pushd $MyDir 

if (1 -eq 2)
{
#Reset
 $root ="C:\Users\dpitkin\Documents\SQL Server Management Studio\Projects\TPEStaging"
 (gci $root -Recurse | ?{$_.psIscontainer -eq $false} ) | Move-Item -Destination $root 

 (gci $root -Recurse | ?{$_.psIscontainer -eq $true} ) | remove-Item #-Destination $root 


}