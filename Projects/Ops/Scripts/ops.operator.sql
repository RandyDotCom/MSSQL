USE [msdb]
GO

--IF  EXISTS (SELECT name FROM msdb.dbo.sysoperators WHERE name = N'Ops')
--	EXEC msdb.dbo.sp_delete_operator @name=N'Ops'
--GO

IF  NOT EXISTS (SELECT name FROM msdb.dbo.sysoperators WHERE name = N'Ops')

EXEC msdb.dbo.sp_add_operator @name=N'Ops', 
		@enabled=1, 
		@pager_days=0, 
		@email_address=N'Projects@ydpages.com'
GO
