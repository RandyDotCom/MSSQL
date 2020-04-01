USE Ops
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.KillBlockingSpids') AND type in (N'P', N'PC'))
	DROP PROCEDURE dbo.KillBlockingSpids 
GO
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON
GO

Begin Try 
  
	Raiserror('Trying 2102 Version',0,1) with nowait 

 Exec sp_executesql N'
CREATE PROCEDURE [dbo].[KillBlockingSpids] 
AS
SET NOCOUNT ON;

DECLARE 
	@sql nvarchar(max),
	@spid varchar(11),
	@login_name sysname,
	@db_name sysname,
	@is_rolemember int,
	@host_name sysname,
	@program_name sysname,
	@sql_text nvarchar(max),
	@direct_blocks smallint,
	@total_blocks smallint,
	@cpu_time int,
	@login_time datetime,
	@last_request_start_time datetime,
	@last_request_end_time datetime;

DECLARE c CURSOR FAST_FORWARD FOR

WITH cte AS (SELECT es.session_id AS root_blocker, es.session_id AS spid, CAST(0 AS smallint) AS blocker, 0 AS lvl
		FROM sys.dm_exec_sessions es
		WHERE EXISTS(SELECT 1 FROM sys.dm_exec_requests r2 WHERE es.session_id = r2.blocking_session_id)
		AND NOT EXISTS( SELECT 1 FROM sys.dm_exec_requests r1 WHERE es.session_id = r1.session_id AND r1.blocking_session_id > 0)

		UNION ALL 
		SELECT cte.root_blocker, er.session_id AS spid, cte.spid AS blocker, cte.lvl + 1 AS lvl
		FROM sys.dm_exec_requests er
			INNER JOIN cte ON er.blocking_session_id = cte.spid),
	cte2 AS (SELECT cte.root_blocker, COUNT(*) AS total_blocks, SUM(CASE WHEN cte.lvl = 1 THEN 1 ELSE 0 END) AS direct_blocks
			FROM cte WHERE blocker > 0 GROUP BY root_blocker)

SELECT es.session_id, DB_NAME(es.database_id), es.login_name, es.program_name, es.host_name, st.text AS sql_text, cte2.direct_blocks, cte2.total_blocks,
		es.cpu_time, es.login_time, es.last_request_start_time, es.last_request_end_time
		-- SELECT database_id
FROM sys.dm_exec_sessions es
--inner join sys.dm_exec_requests er on er.session_id = es.session_id
INNER JOIN sys.dm_exec_connections ec ON es.session_id = ec.most_recent_session_id
CROSS APPLY sys.dm_exec_sql_text(ec.most_recent_sql_handle) st
INNER JOIN cte2 ON es.session_id = cte2.root_blocker
		
WHERE EXISTS(SELECT 1 FROM sys.dm_exec_requests r2 WHERE es.session_id = r2.blocking_session_id)
	AND NOT EXISTS( SELECT 1 FROM sys.dm_exec_requests r1
		WHERE es.session_id = r1.session_id AND r1.blocking_session_id > 0)
		AND es.status = ''sleeping''
		OPTION (MAXRECURSION 50);

OPEN c;

 declare @ERM nvarchar(max) 

WHILE 1=1
BEGIN

	FETCH NEXT FROM c INTO @spid, @db_name, @login_name, @program_name, @host_name, @sql_text,
				@direct_blocks,	@total_blocks, @cpu_time, @login_time, @last_request_start_time, @last_request_end_time;
	IF @@FETCH_STATUS <> 0 BREAK;

	/*  Test for membership in wtt_datastoreadmins */
	SET @sql = ''USE '' + @db_name + ''; EXECUTE AS LOGIN = '' + QUOTENAME(@login_name, '''''''') + ''; SET @is_rolemember = IS_ROLEMEMBER(''''wtt_datastoreadmins''''); REVERT;'';
	EXEC sp_executesql @sql, N''@is_rolemember int OUTPUT'', @is_rolemember = @is_rolemember OUTPUT;

	IF @is_rolemember = 0 OR @is_rolemember IS NULL
		BEGIN
		Begin Try 
			Select @ERM = coalesce(@ERM+char(10),'''') + ''Killing '' + @login_name + '' SPID:'' + @spid
			 
			EXEC (''Kill '' + @spid);
			INSERT INTO dbo.BlockingSpidsKilled (kill_date, spid, db_name, login_name, program_name, host_name, sql_text,
								direct_blocks, total_blocks, cpu_time, login_time, last_request_start_time, last_request_end_time)
			VALUES (GETDATE(), @spid, @db_name, @login_name, @program_name, @host_name, @sql_text,
								@direct_blocks,	@total_blocks, @cpu_time, @login_time, @last_request_start_time, @last_request_end_time)
		END Try 
		Begin CAtch 
			select @ERM = coalesce(@ERM+char(10),'''') + ERROR_MESSAGE()
		End Catch 
		END 

END;

  IF @ERM is not null 
    Raiserror(@ERM,16,1)
CLOSE c;
DEALLOCATE c;

'
	-- Raiserror('used normal version Version',0,1) with nowait 
End Try 
Begin Catch -- Try Version for 2008 

  Begin Try 
    Raiserror('Trying 2008 Version',0,1) with nowait 

 Exec sp_executesql N'
CREATE PROCEDURE [dbo].[KillBlockingSpids] 
AS
SET NOCOUNT ON;

DECLARE 
	@sql nvarchar(max),
	@spid varchar(11),
	@login_name sysname,
	@db_name sysname,
	@is_rolemember int,
	@host_name sysname,
	@program_name sysname,
	@sql_text nvarchar(max),
	@direct_blocks smallint,
	@total_blocks smallint,
	@cpu_time int,
	@login_time datetime,
	@last_request_start_time datetime,
	@last_request_end_time datetime;



DECLARE c CURSOR FAST_FORWARD FOR

WITH cte AS (SELECT es.session_id AS root_blocker, es.session_id AS spid, CAST(0 AS smallint) AS blocker, 0 AS lvl
		FROM sys.dm_exec_sessions es
		WHERE EXISTS(SELECT 1 FROM sys.dm_exec_requests r2 WHERE es.session_id = r2.blocking_session_id)
		AND NOT EXISTS( SELECT 1 FROM sys.dm_exec_requests r1 WHERE es.session_id = r1.session_id AND r1.blocking_session_id > 0)

		UNION ALL 
		SELECT cte.root_blocker, er.session_id AS spid, cte.spid AS blocker, cte.lvl + 1 AS lvl
		FROM sys.dm_exec_requests er
			INNER JOIN cte ON er.blocking_session_id = cte.spid),
	cte2 AS (SELECT cte.root_blocker, COUNT(*) AS total_blocks, SUM(CASE WHEN cte.lvl = 1 THEN 1 ELSE 0 END) AS direct_blocks
			FROM cte WHERE blocker > 0 GROUP BY root_blocker)

SELECT es.session_id, DB_NAME(er.database_id), es.login_name, es.program_name, es.host_name, st.text AS sql_text, cte2.direct_blocks, cte2.total_blocks,
		es.cpu_time, es.login_time, es.last_request_start_time, es.last_request_end_time
		-- SELECT database_id
FROM sys.dm_exec_sessions es
inner join sys.dm_exec_requests er on er.session_id = es.session_id
INNER JOIN sys.dm_exec_connections ec ON es.session_id = ec.most_recent_session_id
CROSS APPLY sys.dm_exec_sql_text(ec.most_recent_sql_handle) st
INNER JOIN cte2 ON es.session_id = cte2.root_blocker
		
WHERE EXISTS(SELECT 1 FROM sys.dm_exec_requests r2 WHERE es.session_id = r2.blocking_session_id)
	AND NOT EXISTS( SELECT 1 FROM sys.dm_exec_requests r1
		WHERE es.session_id = r1.session_id AND r1.blocking_session_id > 0)
		AND es.status = ''sleeping''
		OPTION (MAXRECURSION 50);

OPEN c;

 declare @ERM nvarchar(max) 

WHILE 1=1
BEGIN

	FETCH NEXT FROM c INTO @spid, @db_name, @login_name, @program_name, @host_name, @sql_text,
				@direct_blocks,	@total_blocks, @cpu_time, @login_time, @last_request_start_time, @last_request_end_time;
	IF @@FETCH_STATUS <> 0 BREAK;

	/*  Test for membership in wtt_datastoreadmins */
	SET @sql = ''USE '' + @db_name + ''; EXECUTE AS LOGIN = '' + QUOTENAME(@login_name, '''''''') + ''; SET @is_rolemember = IS_ROLEMEMBER(''''wtt_datastoreadmins''''); REVERT;'';
	EXEC sp_executesql @sql, N''@is_rolemember int OUTPUT'', @is_rolemember = @is_rolemember OUTPUT;

	IF @is_rolemember = 0 OR @is_rolemember IS NULL
		BEGIN
		Begin Try 
			Select @ERM = coalesce(@ERM+char(10),'''') + ''Killing '' + @login_name + '' SPID:'' + @spid
			 
			EXEC (''Kill '' + @spid);
			INSERT INTO dbo.BlockingSpidsKilled (kill_date, spid, db_name, login_name, program_name, host_name, sql_text,
								direct_blocks, total_blocks, cpu_time, login_time, last_request_start_time, last_request_end_time)
			VALUES (GETDATE(), @spid, @db_name, @login_name, @program_name, @host_name, @sql_text,
								@direct_blocks,	@total_blocks, @cpu_time, @login_time, @last_request_start_time, @last_request_end_time)
		END Try 
		Begin CAtch 
			select @ERM = coalesce(@ERM+char(10),'''') + ERROR_MESSAGE()
		End Catch 
		END 

END;

  IF @ERM is not null 
    Raiserror(@ERM,16,1)

CLOSE c;
DEALLOCATE c;
'
   end try 
   begin Catch 
		Raiserror('Unable to create either version of this sproc "KillBlockingSpids"',0,1) with nowait 
   end Catch 
end Catch 
GO


	
if 1=2 
  exec ops.dbo.KillBlockingSpids 