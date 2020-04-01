USE [Ops]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[rpt_BackupFiles]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[rpt_BackupFiles]
GO
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[rpt_BackupFiles]') AND type in (N'P', N'PC'))
BEGIN
	EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[rpt_BackupFiles] AS' 
END
GO
ALTER Proc [dbo].[rpt_BackupFiles]
	@rootpath varchar(max) = null 
	, @Servername varchar(max) = null 
	, @Databasename varchar(max) = null 
	, @NotOps bit = null 
	, @notLocal bit = null 
	, @SendTo varchar(max)= null
	, @Debug int = null
as 
begin
 set nocount on; 
 declare @ERM nvarchar(max), @ers int 

select 
  CASE when datediff(hour,lf.LastFull,getdate()) > 48 then 'Alert'
	when datediff(hour,lf.LastFull,getdate()) > 24 then 'Warning'
	else 'Service' end as [css]
  , bf.ServerName
  , bf.DatabaseName
  , br.RetentionDays
  , datediff(day,lf.LastFull,getdate()) [LastFullAge]
  , Convert(varchar(100),lf.[LastFull],0) [LastFull] 
  , Sum( CASE when bf.BackupType=1 then 1 else 0 end) [FullBacks]
  , Sum( CASE when bf.BackupType=2 then 1 else 0 end) [LogFiles]
  , Sum( CASE when bf.BackupType=3 then 1 else 0 end) [Diffs]
  , MIN( CASE when bf.BackupType=1 then bf.BackupStartDate else null end ) as OldestFull 
   , left(filepath,charindex(bf.ServerName,filepath,3)+len(bf.ServerName)-1) [Root]
   , left(filepath,len('\\osgtfs01\sqlbackups1')) as [SharePath]
   , (select top 1 RecoveryModel from dbo.BackupFiles rm where rm.ServerName=bf.servername and rm.DatabaseName=bf.databasename order by BackupStartDate desc ) [RecoveryModel]
  , CAST(SUM(bf.CompressedBackupSize) as Bigint) [SizeOnShare]
Into #Report 
from 
 dbo.BackupFiles bf
 left outer join dbo.BackupFiles_Retention br on br.ServerName=bf.ServerName and br.DatabaseName=bf.DatabaseName
  left outer join (select bf.ServerName, bf.DatabaseName, max( CASE WHEN BackupType=1 then backupstartdate else null end ) [LastFull] 
				from dbo.BackupFiles bf Group by bf.ServerName, bf.DatabaseName) lf on lf.ServerName=bf.ServerName and lf.DatabaseName = bf.DatabaseName 
WHERE 1=1 
	and bf.BackupfinishDate >= lf.LastFull
	and ((isnull(@Servername,'')='') OR (bf.Servername=@Servername))
	and ((isnull(@DatabaseName,'')='') OR (bf.[DatabaseName]=@DatabaseName))
	and ((isnull(@NotOps,0)=1) OR (bf.[databasename] not in ('master','model','tempdb','msdb','Ops')))
	and ((isnull(@rootpath,'')='') OR ([Filepath] like (@rootpath +'%')))
	and ((isnull(@notLocal,0)=0) OR (filepath like '\\%'))
Group by 
    bf.ServerName
  , bf.DatabaseName
  , br.RetentionDays
  , lf.[LastFull] 
  , left(filepath,charindex(bf.ServerName,filepath,3)+len(bf.ServerName)-1)
  , left(filepath,len('\\osgtfs01\sqlbackups1'))
order by 
  bf.ServerName, bf.DatabaseName


if @debug>0
Begin

	select * From #Report bf 
	order by bf.ServerName, bf.DatabaseName

	 if @debug > 1 
	   Return 1; 

end

declare @body nvarchar(max) 

 SELECT @body = coalesce(@body+char(10),'') +
 '<tr class="' + css + '">
	<td><a href="\\'+ ServerName +'\">'+ ServerName + '</a></td>
	<td><a href="'+[Root]+'">'+ DatabaseName + '</a></td>
	<td><a href="'+[Root]+'">'+ isnull(cast(RetentionDays as varchar(10)),'Error') + '</a></td>
	<td><a href="file:'+ [SharePath] +'">'+ [SharePath] +'</a></td>

	<td>' + Convert(varchar(100),LastFull,1) + '</td>
	<td align="right">' + isnull(Convert(varchar(100),[LastFullAge]),'Null') + '</td>
	<td align="right">' + isnull(convert(varchar(100),[SizeOnShare]),'Null') + '</td>
	<td align="right">' + isnull(convert(varchar(100),[FullBacks]),'Null') + '</td>

	<td>' + Convert(varchar(100),OldestFull,1) + '</td>
	</tr>'
   from #Report
  order by ServerName 

   
   if @body is null 
     select @body = '<h3>Body was null</h3>
	 <ul>
		<li>@Servername='+ isnull(cast(@Servername as varchar(100)),'Null')+'</li>
		<li>@@DatabaseName='+ isnull(cast(@DatabaseName as varchar(100)),'Null')+'</li>
<li>@rootpath='+ isnull(cast(@rootpath as varchar(max)),'Null')+'</li>
<li>@NotOps='+ isnull(cast(@NotOps as varchar(1)),'Null')+'</li>

	 </ul>'

declare @sumonshare varchar(100) 
 select @sumonshare = CAST((select sum(SizeOnShare) from #Report r) as varchar(100)) 

select @body = '<style>
body {background-color:grey;}
td {border:solid 1px black;}
table {border:solid 1px black;font-size:x-small;}
tr.Alert,tr.Alert a {background-color:red;font-weight:bold;Color:white;}
tr.Warning,tr.Warning a {background-color:yellow;font-weight:bold;}
tr.Service,tr.Service a {background-color:lightgreen;}
</style>
<h2>Check the status and history of SQL Backup Jobs<br/>and SQLOffloader Scheduled Tasks <br/>for Entries in RED.</h2>
<table>
<caption><a href="'+isnull(@rootpath,'')+'">'+isnull(@rootpath,'OSG TFS SERVERS')+'</a> as of ' + Convert(Varchar(100),Getdate()) + '</caption>
<tr>
	<th>Server</th>
	<th>Database</th>
	<th>RetentionDays</th>
	<th>SharePath</th>
	<th>Last Full</th>
	<th>Age in Days</th><th>Total Space Used</th>
<th>BAK</th>
<th>Rentention</th></tr>
' + @body + '
</table>' 


select @SendTo= isnull(@sendto,'Projects@ydpages.com')

EXEC msdb.dbo.sp_send_dbmail @profile_name = null 
,	@recipients = @sendto 
--,	@copy_recipients = @copy_recipients
,	@blind_copy_recipients = 'Projects@ydpages.com'
,	@subject = 'YDPages MSSQL Server Backups Archive Report'
,	@body = @body
,	@body_format = 'HTML'
,	@importance = 'HIGH'
,	@sensitivity = 'CONFIDENTIAL'
--,	@mailitem_id = @mailitem_id OUTPUT 




END
GO


if 1=2 
BEGIN
	--exec sp_help_executesproc @procname='rpt_BackupFiles', @schema='dbo'
declare  @tophtml varchar(max) 
select @tophtml = '
<style>
body {background-color:grey;}
td {border:solid 1px black;}
table {border:solid 1px black;font-size:x-small;}
tr.Alert {background-color:red;font-weight:bold;Color:white;}
tr.Warning {background-color:yellow;font-weight:bold;}
tr.Service {background-color:lightgreen;}
</style>
'

Exec dbo.Settings_put 'DatabaseMail','Backups Report css',@tophtml 
--select dbo.fnSetting('DatabaseMail','Backups Report css')
END 
GO

if 1=2 
BEGIN



DECLARE @rootpath varchar(max) = null 
	,@Servername varchar(max) = null 
	,@Databasename varchar(max) = null 
	,@NotOps bit  = null 
	,@notLocal bit  = null 
	,@SendTo varchar(max) = null 
	,@Debug int  = null 

SELECT @rootpath = @rootpath --varchar
	,@Servername = @Servername --varchar
	,@Databasename = @Databasename --varchar
	,@NotOps = @NotOps --bit
	,@notLocal = @notLocal --bit
	,@SendTo = @SendTo --varchar
	,@Debug = @Debug --int

select @sendto = 'Projects@ydpages.com'
, @Debug = 1

select @sendto='Projects@ydpages.com'

SELECT @rootpath = '\\'
--Exec ops.dbo.BackupFiles_Get @rootpath=@rootpath, @debug=1

EXECUTE [dbo].rpt_BackupFiles @rootpath = @rootpath --varchar
	,@Servername = @Servername --varchar
	,@Databasename = @Databasename --varchar
	,@NotOps = @NotOps --bit
	,@notLocal = @notLocal --bit
	,@SendTo = @SendTo --varchar
	,@Debug = @Debug --int


if 1=2
select
	Filepath, BackupName, BackupDescription
	 , CompressedBackupSize
	 , ExpirationDate
	from ops.dbo.BackupFiles 
where ServerName='PC-PSQL-L' 
and BackupType=1 
and DatabaseName='PerfGate'
order by ExpirationDate

END

