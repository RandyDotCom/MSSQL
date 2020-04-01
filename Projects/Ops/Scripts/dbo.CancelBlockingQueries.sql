USE [Ops]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CancelBlockingQueries]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[CancelBlockingQueries]
GO

SET ANSI_NULLS ON ; SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CancelBlockingQueries]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[CancelBlockingQueries] AS' 
END
GO


ALTER PROCEDURE [dbo].[CancelBlockingQueries]
	@blockingThreshold INT = 60
AS
-- =============================================
-- Author:		harshadc
-- Create date: 4 November 2015
-- Description:	Kills blocking queries running for more than one minute from Non-WhiteList users
-- Revision: 11/5/2015 [DAVMAD]: cleanup
--           12/10/2015 [DAVMAD]: Adapt to be database agnostic, move everything to dbo for easier deployment
-- =============================================
SET NOCOUNT ON;

DECLARE @SessionIds TABLE (SessionId INT);
DECLARE @blockingSpid SMALLINT;	
DECLARE @cancelRequestStartThreshold DATETIME;
DECLARE @cancelCommand NVARCHAR(100);

SET @cancelRequestStartThreshold = DATEADD(SECOND, ABS(@blockingThreshold) * -1, GETDATE());
	
INSERT INTO @SessionIds (SessionId)
	SELECT s.session_id
	FROM sys.dm_exec_sessions AS s WITH (NOLOCK)
		LEFT OUTER JOIN sys.dm_exec_requests AS blocker WITH (NOLOCK) ON s.session_id = blocker.session_id 
		INNER JOIN sys.dm_exec_requests AS blocked WITH (NOLOCK) ON s.session_id = blocked.blocking_session_id
	WHERE (blocker.blocking_session_id = 0 OR blocker.blocking_session_id IS NULL) 
		AND s.last_request_start_time < @cancelRequestStartThreshold
		AND NOT EXISTS (
			SELECT TOP 1 1
			FROM  OPS.[dbo].[ApprovedBlockers] AS AB WITH (NOLOCK)
			WHERE s.login_name LIKE AB.LoginPattern);

INSERT INTO OPS.[dbo].[CancelledQueries] (
	CancelledTime, 
	SessionId, 
	DatabaseName, 
	LoginName, 
	[HostName],
	SqlText, 
	CpuTime, 
	QueryElapsedTimeInMs)

SELECT GETUTCDATE(),
		s.session_id,
		DB_NAME(s.database_id),
		s.login_name,
		s.[host_name],
		sqltext.[TEXT],
		req.cpu_time,
		DATEDIFF(MILLISECOND, s.last_request_start_time, GETDATE())
	FROM sys.dm_exec_sessions s WITH (NOLOCK)
		LEFT OUTER JOIN sys.dm_exec_requests AS req WITH (NOLOCK) ON s.session_id = req.session_id
		INNER JOIN @SessionIds ses ON s.session_id = ses.SessionId
		OUTER APPLY sys.dm_exec_sql_text(SQL_HANDLE) AS sqltext;


DECLARE cancel_cursor CURSOR FOR 
	SELECT SessionId FROM @SessionIds;
OPEN cancel_cursor;
FETCH NEXT FROM cancel_cursor INTO @blockingSpid;

WHILE @@FETCH_STATUS = 0 
BEGIN
	BEGIN TRY
		SET @cancelCommand = N'KILL ' + CONVERT(NVARCHAR(6), @blockingSpid);
		Raiserror(@cancelCommand,0,1) with nowait 
		EXEC sp_executesql @cancelCommand;
	END TRY
	BEGIN CATCH
		IF ERROR_NUMBER() != 6106 -- Process ID %d is not an active process ID.
		THROW; 
	END CATCH
	FETCH NEXT FROM cancel_cursor INTO @blockingSpid;
END

CLOSE cancel_cursor;
DEALLOCATE cancel_cursor;


GO


