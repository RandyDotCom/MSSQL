
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_help_executesproc]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[sp_help_executesproc]
GO

SET ANSI_NULLS ON ; SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_help_executesproc]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_help_executesproc] AS' 
END
GO

ALTER PROCEDURE [dbo].[sp_help_executesproc]
	@procname sysname = null --'help_get'
	, @schema sysname = null 
	, @verbose bit = null OUTPUT 
	, @debug int = null 
AS
BEGIN
SET NOCOUNT ON; 
DECLARE 
	@name sysname
	, @object_id int 
	, @builddate datetime
	, @erm nvarchar(max) 


select 
	  @name = ob.name 
	, @object_id = ob.object_id 
	, @builddate = ob.modify_date 
	, @schema = sc.name
from sys.objects ob 
 inner join sys.schemas sc on sc.schema_id = ob.schema_id
where 1=1 
 and ob.name = @procname 
 and sc.name = isnull(@schema,'dbo')
 and type in ('P')


 select @schema = isnull(@schema,'dbo') 

 IF @name is null 
 Begin
   SELECT @ERM = 'Procedure ' + ISNULL(@procname,' NULL ') + ' was not found' 
   Raiserror(@ERM,11,1) with nowait; Return 0; 
end 

Declare @declare varchar(max) , @execute varchar(max) , @select varchar(max) 

select 
	@execute = coalesce(@execute +char(10)+char(9)+',','') +  ap.name + ' = ' + ap.name 
		+ case when ap.is_output =1 then ' OUTPUT ' else '' end +
	' --' + tp.name
	, @declare = coalesce(@declare +char(10)+char(9)+',' ,'') + ap.name + ' ' + tp.name +
	case when tp.name in ('char','nchar','varchar','nvarchar') then '(' 
		+ case when ap.max_length > 256 then 'max'
		when ap.max_length = -1 then 'max' 
		else cast(ap.max_length as varchar(100)) end + ')' 
	else ' ' end + ' = null '
   
from -- select * from 
	sys.all_parameters ap
	inner join sys.types tp on tp.system_type_id = ap.system_type_id and tp.user_type_id = ap.user_type_id
where ap.object_id = @object_id 

select @erm = 'DECLARE ' + @declare + char(13) + char(10) + 
'
SELECT ' + replace(@execute,' OUTPUT','') + char(13) + char(10) + 
'
EXECUTE ['+ @schema +'].' + @name + ' ' + @execute 
Raiserror(@ERM,0,1) 

if @verbose =1 
 exec sp_helptext @name 

END

GO
--exec KillDatabaseUsers
--exec sp_help_executesproc 'KillDatabaseUsers'

