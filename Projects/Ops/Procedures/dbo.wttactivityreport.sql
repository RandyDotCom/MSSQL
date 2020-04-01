USE [OPS]
GO

/****** Object:  StoredProcedure [dbo].[wttactivityreport]    Script Date: 1/26/2016 10:11:23 AM ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[wttactivityreport]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[wttactivityreport]
GO

/****** Object:  StoredProcedure [dbo].[wttactivityreport]    Script Date: 1/26/2016 10:11:23 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

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


if object_id('tempdb..#report') is not null 
  drop table #report 

create table #Report (servername nvarchar(300), Datastore nvarchar(300),Test nvarchar(50),[Count] int)


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

		if object_id(@STMT) is not null
		Begin


			  select @stmt = Replace('SELECT ''@servername'' as [servername], ''@name'' as[datastore], ''NumberofDevices'' as [Test], COUNT(ID) AS [Count] FROM [@name].[dbo].[Resource] With (NOLOCK)  Where [ResourcePoolId] <> ''3'' AND [ResourceStatusId] not in (''8'',''6'')','@name',@name)
			  select @stmt = replace(@stmt,'@servername',convert(varchar(300),serverproperty('servername')))

			if @debug>0
			 Raiserror(@stmt,0,1) with nowait
			else
			begin
			insert into #report([servername],[Datastore],[Test],[Count])
			Exec (@stmt)
			END


		  select @stmt = 'SELECT ''@servername'' as [servername], ''@name'' as[datastore], ''NumberofControllers'' as Test, COUNT(ID ) AS [Count] 
			FROM [@name].[dbo].[Resource] With (NOLOCK) Where [ResourcePoolId] = ''3'''
			select @stmt = replace(@stmt,'@servername',convert(varchar(300),serverproperty('servername')))
			select @stmt = replace(@stmt,'@name',@name) 

			if @debug>0
			 Raiserror(@stmt,0,1) with nowait
			else
			begin
			insert into #report([servername],[Datastore],[Test],[Count])
			Exec (@stmt)
			END


		END 

		End Try

		Begin Catch

			select @ERM = isnull(@name,'Null @name') + ' Raised Error'+ char(10) + ERROR_MESSAGE()
			, @ERS = ERROR_SEVERITY() 
			, @ERN = ERROR_NUMBER() 
			

			Raiserror(@ERM,@ERS,1)

			IF @ERS > 11 Goto OnErrorExitCursor

		End Catch

	END
	FETCH NEXT FROM dbcursor INTO @name
END

OnErrorExitCursor: 


CLOSE dbcursor
DEALLOCATE dbcursor

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
;
GO


if 1=2
BEGIN

----Exec ops.dbo.sp_help_executesproc 'wttactivityreport'

DECLARE @databasename varchar(max) = null 
	,@reporttype varchar(max) = null 
	,@debug int  = null 

--SELECT @databasename = @databasename --varchar
--	,@reporttype = @reporttype --varchar
--	,@debug = 1 --int

EXECUTE [dbo].wttactivityreport @databasename = @databasename --varchar
	,@reporttype = @reporttype --varchar
	,@debug = @debug --int

END 
