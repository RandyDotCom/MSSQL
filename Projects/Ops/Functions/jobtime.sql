/*=========================================
-- Create scalar-valued function template
--=========================================
Revise 
C:\Users\v-ranpi\Documents\SQL Server Management Studio\Projects\msdb\Functions\jobtime.sql 

*/
USE msdb
GO

IF OBJECT_ID (N'jobtime') IS NOT NULL
   DROP FUNCTION dbo.jobtime
GO

CREATE FUNCTION dbo.jobtime (
	@run_date int, 
	@run_time int, 
	@run_duration int)
RETURNS datetime
WITH EXECUTE AS CALLER
AS
BEGIN

Declare @Return datetime 
Declare @runtimestring varchar(20) 
SELECT @Return = convert(datetime,(Convert(Varchar(20),@Run_Date)))  


--if 1=2
Begin

SELECT @runtimestring =  right('0000000000000' + CAST(@run_time as varchar(10)) ,6)
SELECT @Return = DATEADD(Hour,CAST(LEFT(@runtimestring ,2) as int),@return)
SELECT @Return = DATEADD(minute,CAST(substring(@runtimestring,3,2) as int),@return)
SELECT @Return = DATEADD(second,CAST(right(@runtimestring,2) as int),@return)



SELECT @run_duration=ISNULL(@run_duration,0) 

SELECT @runtimestring =  right('00000000' + CAST(@run_duration as varchar(10)),6)

SELECT @Return = DATEADD(Hour,CAST(LEFT(@runtimestring ,2) as int),@return)
SELECT @Return = DATEADD(minute,CAST(substring(@runtimestring,3,2) as int),@return)
SELECT @Return = DATEADD(second,CAST(Right(@runtimestring,2) as int),@return)

end 

     RETURN @Return
END
GO

--IF 1=2
--BEGIN


--select top 10 
--	jb.name
--	--, max(msdb.dbo.jobtime(jh.run_date,jh.run_time,null)) [LastRunStart] 
--	, jh.run_date
--	, jh.run_time
--	, jh.run_duration
--	, msdb.dbo.jobtime(jh.run_date,jh.run_time,null) [StepStart]
--	, msdb.dbo.jobtime(jh.run_date,jh.run_time,jh.run_duration) [StepEnd]
--from 
--  msdb..sysjobs jb
--  left outer join dbo.sysjobhistory jh on jh.job_id = jb.job_id and jb.start_step_id=jh.step_id 
--where 1=1 
-- --and (jh.step_id = jb.start_step_id or jh.step_id is null) 
--order by 
-- jh.run_date desc 



--declare @runtimestring varchar(100) 
--, @run_time int = 90523
--, @run_date int = 20140315
--, @return datetime = null 

--SELECT @return = convert(datetime,(Convert(Varchar(20),@Run_Date)))  

--SELECT @runtimestring =  right('0000000000000' + CAST(@run_time as varchar(10)) ,6)
--SELECT @Return = DATEADD(Hour,CAST(LEFT(@runtimestring ,2) as int),@return)
--SELECT @Return = DATEADD(minute,CAST(substring(@runtimestring,3,2) as int),@return)
--SELECT @Return = DATEADD(second,CAST(right(@runtimestring,2) as int),@return)

--END  


-- GO
 