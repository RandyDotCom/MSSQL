use ops 
go 

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_temptable2html]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[usp_temptable2html]
GO

CREATE PROCEDURE dbo.usp_temptable2html 
	@objid int = null 
	, @html nvarchar(max) = null OUTPUT
	, @xhtml nvarchar(max) = null OUTPUT
	, @rowclasscolumnnumber int = null
	, @orderby varchar(max) = null  
	, @debug int = null 
WITH EXECUTE AS CALLER
AS
BEGIN
SET NOCOUNT ON; 
DECLARE @ERM nvarchar(max) 
-- SELECT @orderby = ISNULL('order by ' + @orderby,'')

declare @sql nvarchar(max) , @tbl varchar(200) , @hdr varchar(max) , @body varchar(max) , @rcss varchar(max)

SELECT @tbl = ob.name from tempdb.sys.objects ob where ob.[object_id] = @objid 

IF @tbl is null 
BEGIN
	SELECT @ERM = 'TempTable Not found'
	Raiserror(@ERM,11,1) 
	Return 0 
END	

SELECT 
  @sql = COALESCE(@sql + ',','') + CHAR(10) + 'isnull(convert(varchar(max),[' + tc.name + ']),'''') as [td]'
 , @hdr = COALESCE(@hdr,'') + '<th>' + tc.name + '</th>' 
 , @rcss = coalesce(@rcss,'') + case when tc.column_id = @rowclasscolumnnumber then '<tr class="isnull(convert(varchar(max),[' + tc.name + ']),'''')">' else '<tr>' end 
FROM -- select * from 
	tempdb.sys.columns tc 
	inner join tempdb.sys.types tt on tc.[user_type_id] = tt.[user_type_id] 
where 1=1 
  and tc.[object_id] = @objid 	 
 
 --print @rcss
 --Print @hdr   
 DECLARE @rtn table (db nvarchar(max)) 
 
SELECT @sql = '
SELECT  
( SELECT ' + @sql + ' 
from ' + @tbl + ' [tr] ' +
--+ ISNULL('order by ' + @orderby ,'') +
+ char(10) + ' for xml auto, elements, root(''table'') 
) xd' 
--PRINT @SQL 

insert into @rtn 
exec(@sql)

--select * from @rtn

SELECT @HTML = db from @rtn 
SELECT @html = REPLACE(@html,'<table border="1" cellpadding="1" cellspacing="0">','<table><tr>'+@hdr+'</tr>') 

/* XML Validation Test */
Begin Try 
 
  select @xhtml = Convert(nvarchar(max),CONVERT(xml,@html)) 
 select @ERM = CONVERT(varchar(max),@html) 

  if @ERM != @html 
    Raiserror('Mutual conversion errors',0,1)   
 
END Try 
Begin catch

  select @ERM = ERROR_MESSAGE()

End Catch
Declare @css nvarchar(max) ='<style>
body {background-color:grey;}
table {border:solid 1px black;}
table.MsoNormalTable {border:solid 1px black;}
td,th {border:solid 1px black; padding: 0px 0px 0px 0px;}
tr.Alert {background-color:red;font-weight:bold;Color:white;}
tr.Warning {background-color:yellow;font-weight:bold;}
tr.Service {background-color:lightgreen;}
h6 {background-color:maroon;color:yellow;}
</style>'

     select @html = @css + @html 
END
GO


IF 1=2
BEGIN

SET NOCOUNT ON; 
exec sp_help_executesproc @procname='usp_temptable2html'

select * into #needs from [dbo].[OuSearchNeeds]
declare @OBjectid int 
SET @OBjectid=object_id('tempdb..#needs')


DECLARE @body nvarchar(max) = NULL

EXEC usp_temptable2html @objid=@OBjectid, @HTML=@body output 

Print @body

END 
GO 
