USE [Ops]
GO

/****** Object:  UserDefinedFunction [dbo].[fnRandomNumber]    Script Date: 2/12/2015 4:32:48 PM ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[fnRandomNumber]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[fnRandomNumber]
GO

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Randy
-- Create date: 20150212
-- Description:	Returns a Random Number between 1 and 100
-- =============================================
CREATE FUNCTION fnRandomNumber 
(
	@seed uniqueidentifier, @range int
)
RETURNS int
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result int
	select @Result = abs(checksum(@seed) % @range)
	RETURN @Result

END
GO

--SELECT ops.dbo.fnRandomNumber(newid(),100)