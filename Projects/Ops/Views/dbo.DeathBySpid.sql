USE [Ops]
GO

IF  EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[DeathBySpid]'))
	DROP VIEW [dbo].[DeathBySpid]
GO

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON
GO

Create view [dbo].[DeathBySpid] as
SELECT
	 tp.[JobVictomCount]
	, tp.[program_name]
	  ,tp.[host_name]
	  ,tp.[login_name]
	  , datediff(second,bt.[last_request_end_time],bt.kill_date) as [SleepPeriodinSeconds]
	  ,bt.[db_name]
      ,bt.[direct_blocks]
      ,bt.[total_blocks]
      ,bt.[cpu_time]
      ,bt.[login_time]
      ,bt.[last_request_start_time]
      ,bt.[last_request_end_time]
	  --, convert(XML,bt.[sql_text]) [SQL_Text]
  FROM 
    (select [login_name]
      ,[host_name]
      ,[program_name]
	  , Count(*) [JobVictomCount]
		FROM [OPS].[dbo].[BlockingSpidsKilled]
		 where [kill_date] > dateadd(hour,-24,getdate())
		 group by 
		 [login_name]
      ,[host_name]
      ,[program_name]) tp
	left outer join [OPS].[dbo].[BlockingSpidsKilled] bt on tp.[program_name] = bt.[program_name] and tp.[host_name]=bt.[host_name] and tp.[program_name] = bt.[program_name]
WHERE 1=1 

GO


