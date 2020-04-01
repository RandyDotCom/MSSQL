USE [Ops]
GO

/****** Object:  StoredProcedure [dbo].[CommandLog_get]    Script Date: 9/14/2016 5:35:32 PM ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CommandLog_get]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[CommandLog_get]
GO

/****** Object:  StoredProcedure [dbo].[CommandLog_get]    Script Date: 9/14/2016 5:35:32 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CommandLog_get]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[CommandLog_get] AS' 
END
GO


ALTER procedure [dbo].[CommandLog_get]
	@ID int = null,
	@DatabaseName sysname = null,
	@SchemaName sysname = null,
	@ObjectName sysname = null,
	@ObjectType char(2) = null,
	@IndexName sysname = null,
	@IndexType tinyint = null,
	@StatisticsName sysname = null,
	@PartitionNumber int = null,
	@ExtendedInfo xml = null,
	@Command nvarchar(max) = null,
	@CommandType nvarchar(120) = null,
	@StartTime datetime = null,
	@EndTime datetime = null,
	@ErrorNumber int = null,
	@ErrorMessage nvarchar(max) = null,
	@xmlstring varchar(max) = null,
	@putdata bit = null,
	@userid int = null,
	@debug int = null
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;
  declare @erm nvarchar(max)

  
SELECT top 1000
	[DatabaseName], 
	[SchemaName], 
	[ObjectName], 
	[ObjectType], 
	[IndexName], 
	[IndexType], 
	[StatisticsName], 
	[PartitionNumber], 
	[ExtendedInfo], 
	[Command], 
	[CommandType], 
	[StartTime], 
	[EndTime], 
	[ErrorNumber], 
	[ErrorMessage] 
FROM
	[dbo].[CommandLog]
WHERE 1=1
	and ((isnull(@ID,0) = 0) OR ([ID] = @ID))

order by ID DESC 

END

GO


