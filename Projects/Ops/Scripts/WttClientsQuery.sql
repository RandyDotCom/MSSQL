USE [OPS]
GO

--IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[wttactivityreport]') AND type in (N'P', N'PC'))
--  DROP PROCEDURE [dbo].[wttactivityreport]
--GO

--SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON
--GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[wttactivityreport]') AND type in (N'P', N'PC'))
BEGIN
  EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[wttactivityreport] AS' 
END
GO
-- =============================================
-- Author:		randy
-- Create date: 2016
-- Description:	returns data about machines and controllers from a wtt datastore
-- =============================================
ALTER PROCEDURE [dbo].[wttactivityreport] 
	@databasename varchar(300) = null, 
	@reporttype varchar(300) = null  ,
	@debug int = null 
AS
BEGIN
SET NOCOUNT ON; 
SET XACT_ABORT ON;
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 

if 1=2
BEGIN
/* HOW TO SET Exeptions to the default value */

	exec ops.dbo.settings_put @context='WCSBlue', @name='MaxMchineCount', @value='600', @purge=1


END 

if @debug=2
Begin 
  select * from ops.dbo.Settings where name='MaxMchineCount'
  Return 1; 
END

if object_id('tempdb..#report') is not null 
  drop table #report 

create table #Report (servername nvarchar(300), Datastore nvarchar(300),Controller nvarchar(300),[Type] nvarchar(10), [HeartbeatState] nvarchar(20), [MachineCount] int )


DECLARE dbcursor CURSOR READ_ONLY FOR 
select [DatabaseName] from [Ops].[dbo].[Database_status_v] where [DatabaseName] not in ('master','model','ops','msdb','tempdb')
 and isnull([HARole],'Primary')='Primary' 

DECLARE @name nvarchar(max)
OPEN dbcursor

FETCH NEXT FROM dbcursor INTO @name
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

		Begin Try 

		  declare @stmt nvarchar(max) 
		  SET @STMT = @name+'.dbo.Resource'
		    -- select object_id(@stmt) , @name 

		  if @debug is not null 
		    Raiserror(@stmt,0,1) with nowait 

		if object_id(@STMT) is not null
		Begin

select @stmt = Replace('
select 
	Convert(nvarchar(300),serverproperty(''servername'')) [Servername]
	, ''OSGThreshold_EDS14'' [DsNAme]
	, md.[Controller]
	, md.[Type]
	, md.HeartBeatCurrent
	, md.cntOfMachines
from (
 SELECT 
	ct.name [Controller]
 	, Case WHEN md.ResourceConfigurationId is not null then ''Mobile'' else ''Client'' end [Type]
	, CASE when (r.LastHBTime > dateadd(day,-60,getdate()))  then ''Active'' else ''Orphan'' end [HeartBeatCurrent]
	, count(distinct r.id) [cntOfMachines] 
FROM 
	[OSGThreshold_EDS14].DBO.Resource r (NOLOCK) 
	inner join (select id, [name] from [OSGThreshold_EDS14].dbo.[Resource] with (Nolock) where ResourcePoolid = 3) ct on ct.id = r.PushDaemonResourceId 
	inner join [OSGThreshold_EDS14].[dbo].[ResourceConfiguration] RC  (NOLOCK) on r.id = rc.ResourceId
	left outer join 
	  (select rv.ResourceConfigurationId from [OSGThreshold_EDS14].[dbo].[ResourceConfigurationValue] rv  (NOLOCK) 
		inner join [OSGThreshold_EDS14].[dbo].[Dimension] DM (Nolock) on DM.Id = rv.DimensionId and dm.[NAME] LIKE ''Mobile%''
	) md on rc.id = md.ResourceConfigurationId 
where 1=1 
 and r.ResourceStatusId not in (6,8) 
 and r.ResourcePoolId != 3 
 --and ((r.LastHBTime > dateadd(day,-60,getdate()) ) OR (@debug=1))
Group by 
	ct.[name] 
 	, Case WHEN md.ResourceConfigurationId is not null then ''Mobile'' else ''Client'' end 
	, CASE when (r.LastHBTime > dateadd(day,-60,getdate()))  then ''Active'' else ''Orphan'' end 
) md 
','OSGThreshold_EDS14',@name)  


			if @debug > 0 
			Print @stmt 

			insert into #report([servername],[Datastore],[Controller],[Type],[HeartbeatState],[MachineCount])
			Exec (@stmt)

			select @stmt = convert(nvarchar(300),serverproperty('Servername')) 

			insert into #report([servername],[Datastore],[Controller],[Type],[HeartbeatState],[MachineCount])
			select @STMT,@name,'YDPages','CONFIG',ops.dbo.fnSetting(@name,'MaxMchineCount'),isnull(ops.dbo.fnSetting(@name,'MaxMchineCount'),1500)

		END 

		End Try

		Begin Catch

			select @ERM = isnull(@name,'Null @name') + ' Raised Error'+ char(10) + ERROR_MESSAGE()
			, @ERS = ERROR_SEVERITY() 
			, @ERN = ERROR_NUMBER() 
			
			Raiserror(@ERM,@ERS,1)

		End Catch

	END
	FETCH NEXT FROM dbcursor INTO @name
END

OnErrorExitCursor: 


CLOSE dbcursor
DEALLOCATE dbcursor

if @debug = 3 
Begin 
  select *, @debug [Debug] from #Report 
  Return 1; 
end 

IF exists(Select * from #Report)
Begin 
	if @debug > 0 
		raiserror('Alerting Test',0,1) with nowait 

select @ERM = COALESCE(@ERM+char(10),'') + isnull('Datastore: ' + datastore + ' HAS ' + Cast(sum(MachineCount) as Varchar(50)) + ' Machines associated.','Has an Aggregate Error') 
	 from #report 
	 WHERE HeartbeatState='Active' 
	 group by datastore ,servername
    having sum(MachineCount)  > convert(int,isnull(ops.dbo.fnSetting(datastore,'MaxMchineCount'),'1500'))


	if @ERm is not null 
	Begin 
		select @ERM = 'On Server: ' + Convert(nvarchar(300),serverproperty('servername')) + char(10) + 'Too many machines connected to a datastore' 
		+ char(10) + @ERM 
		+ char(10) + 'https://osgwiki.com/wiki/WTT_Troubleshooting_Guide#Too_many_machines_connected_to_a_datastore.'

		if @debug > 0 
			Raiserror(@ERM,0,1)
		else 
			if @debug is null
				exec ops.dbo.RaiseAlert @Message=@ERM,@type='Error', @Errorid=410 

	End 

END 

declare @report xml 
select @report = (
select * from #report [WTTReport] for xml auto, root('Wtt')
) 

if @report is not null 
  select @report [Report] 
else
	SELECT Convert(XML,'<Execution><Job procedure="wttactivityreport">No WTT datastores found</Job></Execution>') as [Report]
  Return 1; 
	
END
GO


-- if 1=2
BEGIN

----Exec ops.dbo.sp_help_executesproc 'wttactivityreport'

DECLARE @databasename varchar(max) = null 
	,@reporttype varchar(max) = null 
	,@debug int  = null

--SET @Debug= 1 

SELECT @databasename = @databasename --varchar
	,@reporttype = @reporttype --varchar
	--,@debug = 3 --int

EXECUTE [dbo].wttactivityreport @databasename = @databasename --varchar
	,@reporttype = @reporttype --varchar
	,@debug = @debug --int



END 
