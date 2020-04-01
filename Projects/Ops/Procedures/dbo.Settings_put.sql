SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = N'dbo'
     AND SPECIFIC_NAME = N'Settings_put' )
   DROP PROCEDURE dbo.Settings_put
GO

-- =============================================
-- Author:		Randy
-- Create date: 201409013
-- Description:	Set Settings Values
-- =============================================
CREATE PROCEDURE dbo.Settings_put 
	@Context Varchar(50) = null, 
	@Name Varchar(50) = null  ,
	@Value nvarchar(max) = null,
	@purge bit = null, 
	@debug int = null 
AS
BEGIN
SET NOCOUNT ON; 
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 

if isnull(@purge,0)=1 
BEGIN
	delete from dbo.Settings 
	where Context = @Context 
	and ((isnull(@name,'')='') OR ([Name]=@Name)) 
Return 1;
END 

  IF (@Context is null) or (@name is null) or (@Value is null) 
  BEGIN
	SELECT @ERM = 'All 3 Values are required (Context, Name, Value) 
	values(' + isnull(@context,'NULL') +','+ isnull(@name,'NULL')+',' + isnull(@Value,'NULL')  + ')' 
	Raiserror(@ERM,11,1) 
	Return 0;
  END
  ELSE
  Begin
    
		if not exists(select * from dbo.settings where context=@Context and Name = @Name) 
		BEGIN
			insert into dbo.Settings([Context], [Name], [Value]) Values (@Context, @Name, @Value)

		END
		ELSE
		BEGIN
			update dbo.Settings Set [Value]=@Value where [Context]=@Context and name=@Name 
		END
	
	END
END
GO


IF 1=2
BEGIN
	exec sp_help_executesproc @procname='Settings_put'

END