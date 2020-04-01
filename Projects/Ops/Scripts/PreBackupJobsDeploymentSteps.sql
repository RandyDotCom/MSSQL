use ops 
go

/*  
	This is the last step before deploying Jobs 
	If the script timesout, re-execute here in SSMS 
	Before deploying Jobs 

*/
if not exists(select * from ops.dbo.BackupFiles)
BEGIN

Exec ops.dbo.BackupFiles_Get @debug=1

  if not exists(select * from ops.dbo.BackupFiles)
	BEGIN

		Exec ops.dbo.BackupDatabase @BackupType='Full', @debug=1
		Exec ops.dbo.BackupDatabase @BackupType='Log', @debug=1
		Exec ops.dbo.BackupsCleaner @retention=3 , @debug=1

	END 

	exec ops.dbo.BackupFiles_Report

END 
exec ops.dbo.BackupFiles_Report
ExitScript: 

