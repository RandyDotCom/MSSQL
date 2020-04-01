USE Ops
GO

IF OBJECT_ID (N'dbo.fnSetting') IS NOT NULL
   DROP FUNCTION dbo.fnSetting
GO

CREATE FUNCTION dbo.fnSetting (@Context varchar(50),@name varchar(50))
RETURNS nvarchar(max)
WITH EXECUTE AS CALLER
AS
BEGIN
  declare @R nvarchar(max) 
    SELECT @R = Value from dbo.Settings where Context=@Context and Name=@name 
	Return @R
	     
END
GO
