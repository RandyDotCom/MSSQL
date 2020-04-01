USE OPS
go

SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = N'dbo'
     AND SPECIFIC_NAME = N'PartitionTable' )
   DROP PROCEDURE dbo.PartitionTable
GO

---- =============================================
---- Author:		Randy
---- Create date: 20171020
---- Description:	PartitionsTables
---- =============================================
--CREATE PROCEDURE dbo.PartitionTable 
--	@dbname nvarchar(300) = null 
--	,@PartitionSchemaName nvarchar(300) = null  
--	,@Table nvarchar(300) = null
--	, @PartitionPrefix nvarchar(300) = null
--	, @debug int = null 

--AS
--BEGIN
--SET NOCOUNT ON; 
--Raiserror('ABORTED',11,1) with nowait 
--REturn 0; 

--DECLARE @ERM nvarchar(max), @ERS int, @ERN int 

--Create Table #TODOList (
--	[Purpose] nvarchar(300)
--	,[Tsql] nvarchar(max)	
--	,[Result] nvarchar(max)  
--	, [ID] int identity(1,1)
--)
--DECLARE @TSQL nvarchar(max) 

--select @TSQL = COALESCE()


--END
--GO


--IF 1=2
--BEGIN
--	exec sp_help_executesproc @procname='PartitionTable', @schema='dbo'

--DECLARE @dbname nvarchar(max) = null 
--	,@PartitionSchemaName nvarchar(max) = null 
--	,@Table nvarchar(max) = null 
--	,@PartitionPrefix nvarchar(max) = null 
--	,@debug int  = null 

--SELECT @dbname = 'MRDashboard' --nvarchar
--	,@PartitionSchemaName = 'CrawlDateSchema' --nvarchar
--	,@Table = 'TexusMRResource' --nvarchar
--	,@debug = @debug --int
--	,@PartitionPrefix = @PartitionPrefix --nvarchar
	

--EXECUTE [dbo].PartitionTable @dbname = @dbname --nvarchar
--	,@PartitionSchemaName = @PartitionSchemaName --nvarchar
--	,@Table = @Table --nvarchar
--	,@PartitionPrefix = @PartitionPrefix --nvarchar
--	,@debug = @debug --int


--END