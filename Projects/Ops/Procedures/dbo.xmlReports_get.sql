IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[xmlReports_get]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[xmlReports_get]
GO
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[xmlReports_get]') AND type in (N'P', N'PC'))
BEGIN
	EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[xmlReports_get] AS' 
END
GO


ALTER procedure [dbo].[xmlReports_get]
	@xdid int = null,
	@Property varchar(50) = null,
	@Context varchar(50) = null,
	@xData xml = null,
	@debug int = null
AS
BEGIN
  SET NOCOUNT ON;
  declare @erm nvarchar(max)

  
SELECT 
	[Property], 
	[Context], 
	[xData] 
FROM
	[dbo].[xmlReports]
WHERE 1=1
	and ((isnull(@xdid,0) = 0) OR ([xdid] = @xdid))
	and ((isnull(@Property,'') = '') OR ([Property] = @Property))
	and ((isnull(@Context,'') = '') OR ([Context] = @Context))


END

GO

IF 1=2 
BEGIN
 exec sp_help_executesproc @procname='xmlReports_get'

 DECLARE @xdid int  = null  --int
	,@Property varchar(50) = null  --varchar
	,@Context varchar(50) = null  --varchar
	,@xData xml  = null  --xml
	,@debug int  = null  --int

SELECT @xdid = @xdid
	,@Property = @Property
	,@Context = @Context
	,@xData = @xData
	,@debug = @debug

EXECUTE xmlReports_get @xdid = @xdid
	,@Property = @Property
	,@Context = @Context
	,@xData = @xData
	,@debug = @debug

END
