USE [master]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_npclean_col]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[sp_npclean_col]
GO
SET ANSI_NULLS ON ;SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_npclean_col]') AND type in (N'P', N'PC'))
BEGIN
	EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_npclean_col] AS' 
END
GO

ALTER procedure [dbo].[sp_npclean_col]
	@DatabaseName nvarchar(300) = null,
	@SchemaName nvarchar(300) = null,
	@TableName nvarchar(300) ,
	@ColumnName nvarchar(300) ,
	@Debug int = null 
AS
BEGIN
SET NOCOUNT ON; 
SET XACT_ABORT ON
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 

 Declare @FullTableName nvarchar(300)
 declare @UpdateSQL nvarchar(4000)

 if @DatabaseName is null begin
  set @DatabaseName = db_name()
 end
 if @SchemaName is null begin
  set @SchemaName = schema_name()
 end

 set @FullTableName = '[' + @DatabaseName + '].[' + @SchemaName + '].[' + @TableName + ']'
 set @UpdateSQL = 'update ' + @FullTableName + ' set [' + @ColumnName + '] = dbo.fn_npclean_string([' + @ColumnName + ']) where [' + @ColumnName + '] like ''%[^ -~0-9A-Z]%'''

 declare @rc int 
 Begin Try 
	if @debug is not null
	  Raiserror(@updateSQL,0,1)  
	if isnull(@Debug,0) < 1 
		exec @RC = sp_ExecuteSQL @UpdateSQL

 end Try 
 Begin Catch 
	select @ERM = ERROR_MESSAGE() 
	Raiserror(@ERM,1,1) with nowait 
	Return 0; 
 end catch 
end
GO

