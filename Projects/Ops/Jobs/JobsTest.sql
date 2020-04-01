
if exists(select * from msdb.dbo.sysjobs where name='dbaBackupsDailys' and enabled=1)
BEGIN
	if exists(select * from msdb.dbo.sysjobs where name='dbaBackupsLogs' and enabled=0)
	Begin 
		Raiserror('Found dbaBackupsLogs disabled, and re-enabled',0,1) 
		exec msdb.dbo.sp_update_job @job_name='dbaBackupsLogs', @enabled=1
	end 
		
end 