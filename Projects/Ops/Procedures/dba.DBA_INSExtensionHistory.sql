USE [OPS]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DBA_INSExtensionHistory]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[DBA_INSExtensionHistory]
GO

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DBA_INSExtensionHistory]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[DBA_INSExtensionHistory] AS' 
END
GO

ALTER Procedure [dbo].[DBA_INSExtensionHistory]
 @debug int = null 
AS
BEGIN
/*
	TODO: This procedure requires a trace to be running, if the trace is not found the procedure should start the trace as required. 


*/
SET NOCOUNT ON; 
DECLARE @ERM NVARCHAR(MAX), @ERN INT, @ERS INT 
--ORDER BY Database then STARTTIME DESC
DECLARE @dbname sysname;
--SET @dbname = 'tempdb'

DECLARE @filename NVARCHAR(1000);
DECLARE @bc INT;
DECLARE @ec INT;
DECLARE @bfn VARCHAR(1000);
DECLARE @efn VARCHAR(10);
/*
IF @dbname is NULL
BEGIN
	SET @dbname = 'fffffffffffffff'
END	
*/
-- Get the name of the current default trace
SELECT @filename = CAST(value AS NVARCHAR(1000))
FROM ::fn_trace_getinfo(DEFAULT)
WHERE traceid = 1 AND property = 2;

if @filename is null 
Begin
	Raiserror('Default Trace not found',11,1) with nowait 
	Return 0; 
end 

if @debug > 0 
  Raiserror(@filename,0,1) with nowait 

-- rip apart file name into pieces
SET @filename = REVERSE(@filename);
SET @bc = CHARINDEX('.',@filename);
SET @ec = CHARINDEX('_',@filename)+1;
SET @efn = REVERSE(SUBSTRING(@filename,1,@bc));
SET @bfn = REVERSE(SUBSTRING(@filename,@ec,LEN(@filename)));

-- set filename without rollover number
SET @filename = @bfn + @efn

if @debug > 0 
Begin
	SELECT 
		ftg.StartTime
--,CAST (CONVERT(varchar(10),ftg.StartTime,101)  AS datetime) AS starttimeconverted
		,te.name AS EventName
		,DB_NAME(ftg.databaseid) AS DatabaseName 
		,ftg.Filename
		,(ftg.IntegerData*8)/1024.0 AS GrowthMB 
		,(ftg.duration/1000)AS DurMS
		
		FROM ::fn_trace_gettable(@filename, DEFAULT) AS ftg 
		INNER JOIN sys.trace_events AS te ON ftg.EventClass = te.trace_event_id 
					WHERE (ftg.EventClass = 92 -- Date File Auto-grow
		OR ftg.EventClass = 93) -- Log File Auto-grow
		AND DB_NAME(ftg.databaseid) = ISNULL(@dbname,DB_NAME(ftg.databaseid)) 
		AND NOT EXISTS
			(SELECT 1
			 FROM  dbo.DBA_ExtensionHistory t3 WITH(NOLOCK)
			 WHERE t3.StartTime = ftg.StartTime
			 AND t3.EventName = te.name
			 AND t3.filename = ftg.FileName) 
		ORDER BY 1 desc 
end 
ELSE 
Begin

  INSERT OPS.dbo.DBA_ExtensionHistory 
	SELECT 
		ftg.StartTime
--,CAST (CONVERT(varchar(10),ftg.StartTime,101)  AS datetime) AS starttimeconverted
		,te.name AS EventName
		,DB_NAME(ftg.databaseid) AS DatabaseName 
		,ftg.Filename
		,(ftg.IntegerData*8)/1024.0 AS GrowthMB 
		,(ftg.duration/1000)AS DurMS
		
		FROM ::fn_trace_gettable(@filename, DEFAULT) AS ftg 
		INNER JOIN sys.trace_events AS te ON ftg.EventClass = te.trace_event_id 
					WHERE (ftg.EventClass = 92 -- Date File Auto-grow
		OR ftg.EventClass = 93) -- Log File Auto-grow
		AND DB_NAME(ftg.databaseid) = ISNULL(@dbname,DB_NAME(ftg.databaseid)) 
		AND NOT EXISTS
			(SELECT 1
			 FROM  dbo.DBA_ExtensionHistory t3 WITH(NOLOCK)
			 WHERE t3.StartTime = ftg.StartTime
			 AND t3.EventName = te.name
			 AND t3.filename = ftg.FileName) 
		ORDER BY 1 desc 
--ORDER BY Database then STARTTIME DESC
END 

END 
GO

if 1=2 
Begin

	EXEC OPS.[dbo].[DBA_INSExtensionHistory] @debug=1 
end  


