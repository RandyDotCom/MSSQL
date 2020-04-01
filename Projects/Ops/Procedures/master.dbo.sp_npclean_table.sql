USE [master]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_npclean_table]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[sp_npclean_table]
GO

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_npclean_table]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_npclean_table] AS' 
END
GO

ALTER procedure [dbo].[sp_npclean_table] 
 @TargetDatabase nvarchar(300) = null,
 @TargetSchema nvarchar(300) = null,
 @TargetTable nvarchar(300) , 
 @Debug int = null 
AS
BEGIN
SET NOCOUNT ON; 
SET XACT_ABORT ON
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 

 declare @getColSQL nvarchar(max)
 declare @curCol nvarchar(300)

 declare @textCol CURSOR
 
  
 if @TargetDatabase is null 
 begin
  set @TargetDatabase = db_name()
 end
 if @TargetSchema is null
  begin
  set @TargetSchema = schema_name()
 end

 set @getColSQL =
  'select sc.name
  from ' + @TargetDatabase + '.sys.columns sc
  join ' + @TargetDatabase + '.sys.types st
  on sc.system_type_id = st.system_type_id
  join ' + @TargetDatabase + '.sys.objects so
  on sc.object_id = so.object_id
  join ' + @TargetDatabase + '.sys.schemas ss
  on so.schema_id = ss.schema_id
  where
  so.type = ''U''
  and st.name in (''text'',''ntext'',''varchar'',''char'',''nvarchar'',''nchar'')
  and sc.is_rowguidcol = 0
  and sc.is_identity = 0
  and sc.is_computed = 0
  and so.name = ''' + @TargetTable + '''
  and ss.name = ''' + @TargetSchema + ''''


 set @getColSQL = 'set @inCursor = cursor for ' + @getColSQL + ' open @incursor'


 execute sp_executesql @getColSQL,N'@inCursor cursor out',@inCursor=@textCol OUT

 fetch next from @textCol into @curCol
 while @@fetch_status = 0
 begin

  exec master.dbo.sp_npclean_col @DatabaseName = @TargetDatabase, @SchemaName = @TargetSchema, @TableName = @TargetTable, @ColumnName = @curCol
  fetch next from @textCol into @curCol
 end

 Close @textCol
 DeAllocate @textCol

end
GO

