use Ops 
GO

SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = N'dbo'
     AND SPECIFIC_NAME = N'InstanceReport_get' )
   DROP PROCEDURE dbo.InstanceReport_get
GO

-- =============================================
-- Author:		Randy
-- Create date: 20150715
-- Description:	Returns a report about important aspects of the SQL server instance
-- =============================================
CREATE PROCEDURE dbo.InstanceReport_get 
	@outputtype varchar(50) = null, 
	@outputto varchar(max) = null  ,
	@debug int = null 
AS
BEGIN
SET NOCOUNT ON; 
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 

  select @outputtype='XML' 
  SELECT @outputto='CLIENT' 

  select * from ops.dbo.xmlReports 

END
GO


IF 1=2
BEGIN
	exec ..sp_help_executesproc @procname='InstanceReport_get', @schema='dbo'

DECLARE @outputtype varchar(50) = null 
	,@outputto varchar(max) = null 
	,@debug int  = null 

SELECT @outputtype = @outputtype --varchar
	,@outputto = @outputto --varchar
	,@debug = 1 --int

EXECUTE [dbo].InstanceReport_get @outputtype = @outputtype --varchar
	,@outputto = @outputto --varchar
	,@debug = @debug --int


END