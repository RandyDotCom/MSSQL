--=========================================
-- Create scalar-valued function template
--=========================================

USE ydpagesvapp
GO

IF OBJECT_ID (N'dbo.htmldesymbol') IS NOT NULL
   DROP FUNCTION dbo.htmldesymbol
GO

CREATE FUNCTION dbo.htmldesymbol (@blob nvarchar(2000))
RETURNS varchar(2000)
WITH EXECUTE AS CALLER
AS
BEGIN
declare @findstr nvarchar(111) , @strlen tinyint 
, @desc nvarchar(2000) 
, @KillString varchar(20) 

SET @desc = @blob 

SELECT @findstr = N'%-[0-9][0-9][0-9];%', @Strlen=5

select @desc = [description]  
from dbo.Members where NickName='Tiffany.Marie.Xoxox'

while @strlen <=7 
Begin
  select @killstring=substring(@desc,patindex(@findstr,@desc),@strlen) 
  select @desc = replace(@desc,@killstring,' ')
  
  if patindex(@findstr,@desc)=0
   select @strlen=@strlen+1
   , @findstr = replace(@findstr,';','[0-9];')
  
end 
return @desc 

  
END
GO
