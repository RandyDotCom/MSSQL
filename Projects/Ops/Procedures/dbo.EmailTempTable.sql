USE OPS
GO

SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = N'dbo'
     AND SPECIFIC_NAME = N'EmailTempTable' )
   DROP PROCEDURE dbo.EmailTempTable
GO

CREATE PROCEDURE dbo.EmailTempTable 
	@Objectid int = null, 
	@SendTo varchar(max) = null  ,
	@Subject varchar(max) = null ,
	@tophtml varchar(max) = null , 
	@bottom varchar(max) = null ,
	@debug int = null 
AS
BEGIN
SET NOCOUNT ON; 
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 

DECLARE @html nvarchar(max) = null
	,@xhtml nvarchar(max) = null
	,@rowclasscolumnnumber int  = null
	,@orderby varchar(max) = null

EXECUTE dbo.usp_temptable2html @objid = @Objectid
	,@html = @html output
	,@xhtml = @xhtml
	,@rowclasscolumnnumber = @rowclasscolumnnumber
	,@orderby = @orderby
	,@debug = @debug


if charindex('<tr><th>css',@html) !=0 
BEGIN
	select @html = replace(@html,'<th>css</th>','')
	select @html = replace(@html,'-css</td>','">')
	select @html = replace(@html,'<tr><td>',char(10) + '<tr class="')
	-- <tr><td>green-css</td>
END

if @html is not null 
BEGIN

	SELECT 	@Subject = isnull(@subject,object_name(@Objectid))
	, @tophtml = isnull(@tophtml,'<link rel="STYLESHEET" type="text/css" href="\\wpchive\central\EIACollection\Repository\www\email.css">')
	, @bottom = isnull(@bottom,'') + '<h6>YDPages inc</h6>'

	SELECT @html = @tophtml + @html + @bottom

DECLARE
 @body_format varchar(10)  = 'HTML' --TEXT or HTML
,@importance varchar(6)  = 'High'  --  Low, Normal, High
,@sensitivity varchar(12)  = 'Normal' -- Normal, Personal, Private, Confidential
,@mailitem_id int  = null


EXEC msdb.dbo.sp_send_dbmail 
	@recipients = @SendTo 
,	@subject = @subject
,	@body = @html
,	@body_format = @body_format
,	@importance = @importance
,	@sensitivity = @sensitivity
,	@mailitem_id = @mailitem_id OUTPUT 

	

END
END
GO


IF 1=2
BEGIN
	exec sp_help_executesproc @procname='EmailTempTable', @schema='dbo'

END