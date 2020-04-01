declare @stmt nvarchar(max) = null 

select 
	@stmt = coalesce(@stmt+char(10),'') + 'EXEC msdb.dbo.sp_delete_job @job_name=N''' + job.name + ''', @delete_unused_schedule=1;'
from 
  msdb.dbo.sysjobs job 
  inner join msdb.dbo.syscategories c on job.category_id = c.category_id 
where 
	c.name in ('EIAOPS','YDPages')

if @stmt is not null
BEGIN

	Begin Try 
	  Raiserror(@STMT,0,1) with nowait 
	  EXEC (@STMT) 
	End Try 
	Begin Catch 
		select @stmt = ERROR_MESSAGE() 
		Raiserror(@STMT,0,1) with nowait 
		GOTO OnErrorAbort 
	end Catch 
	 
END 

IF EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'YDPages' AND category_class=1)
	exec msdb.dbo.sp_delete_category @class='JOB', @name='YDPages'

IF EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'EIAOPS' AND category_class=1)
	exec msdb.dbo.sp_delete_category @class='JOB', @name='EIAOPS'

OnErrorAbort: 
