USE [msdb]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[jobduration]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
	DROP FUNCTION [dbo].[jobduration]
GO
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[jobduration] (@run_duration int)
RETURNS varchar(100)
AS
BEGIN
-- =============================================
-- Author:		Randy
-- Create date: 2017
-- Description:	ReturnsDuration as a string
-- =============================================
	DECLARE @Result varchar(100),@ts varchar(6)

	SELECT @ts = CASE WHEN @run_duration is null then Null 
		WHEN @run_duration < 1 then null 
		else Right('000000' + cast(@run_duration as varchar(8)),6)
		END 

		select @Result = case when left(@ts,2)='00' then '' else convert(varchar(2),convert(int,left(@ts,2))) + ' Hours ' end 
		+ CASE WHen SUBSTRING(@ts,3,2)='00' then '' else convert(varchar(2),convert(int,SUBSTRING(@ts,3,2))) + ' Minutes ' end 
		+ CASE WHen right(@ts,2)='00' then '' else convert(varchar(2),convert(int,right(@ts,2))) + ' Seconds' end 
		
	RETURN @Result

END
GO

--select dbo.jobduration(032337)
