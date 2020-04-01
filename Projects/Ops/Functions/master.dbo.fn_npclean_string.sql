USE [master]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[fn_npclean_string]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
	DROP FUNCTION [dbo].[fn_npclean_string]
GO

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[fn_npclean_string]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
BEGIN
execute dbo.sp_executesql @statement = N'CREATE function [dbo].[fn_npclean_string] (
 @strIn as varchar(max)
)
returns varchar(max)
as
BEGIN
 DECLARE @IPTR AS INT
 SET @IPTR = PATINDEX(''%[^ -~0-9A-Z]%'', @STRIN COLLATE LATIN1_GENERAL_BIN)
 WHILE @IPTR > 0 BEGIN
  SET @STRIN = REPLACE(@STRIN COLLATE LATIN1_GENERAL_BIN, SUBSTRING(@STRIN, @IPTR, 1), '''')
  SET @IPTR = PATINDEX(''%[^ -~0-9A-Z]%'', @STRIN COLLATE LATIN1_GENERAL_BIN)
 END
 RETURN @STRIN
END' 
END
GO

