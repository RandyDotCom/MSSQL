
Declare @schedule_id int 

select @schedule_id=schedule_id from msdb.dbo.sysschedules where Name = 'dbaDBCC-Checkdb'

if @schedule_id is not null  
EXEC msdb.dbo.sp_update_schedule @schedule_id=@schedule_id, 
		@freq_interval=64, 
		@active_start_time=180000
GO


