USE OPS 
GO

SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = N'dbo'
     AND SPECIFIC_NAME = N'RaiseAlert' )
   DROP PROCEDURE dbo.RaiseAlert
GO

-- =============================================
-- Author:		Randy
-- Create date: 2016
-- Description:	Writes a windows event that is passed up to SCOM. XP_Cmdshell must be enabled 

-- =============================================
CREATE PROCEDURE dbo.RaiseAlert 
	@Message nvarchar(3800) = null  ,-- xp_cmdshell Limitation 
	@Type varchar(20) = null, 
	@ErrorID int = null, 
	@debug int = null 
AS
BEGIN
SET NOCOUNT ON; 
SET XACT_ABORT ON
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 
declare @cmd nvarchar(4000)

if @debug is not null
raiserror(@Message,0,1) with nowait 

SELECT @TYPE = CASE when @type in ('Error','WARNING','Information') then @Type else 'Error' end 
, @ErrorID = case when isnull(@ErrorID,0) between 1 and 9999 then @ErrorID else 0 end 
, @Message = CASE when len(isnull(@Message,'')) < len('You are fucked') then isnull(@message,'Null') + char(9) + '  The Error Message is not an adequate in length, please track this down and add verbosity to the alert message' else @Message end 

select @Message = replace(Replace(replace(@message,char(13),' '),char(10),' '),char(9),' ')

if @debug is not null
 raiserror(@Message,0,1) with nowait 

select @cmd = 'Write-EventLog -ComputerName '+ Convert( varchar(300), SERVERPROPERTY('machinename')) +' -LogName Application -Source EIACollection -EntryType '+ @Type +' -EventId '+ cast(@ErrorID as varchar(10)) +' -Message """' + @Message + '"""'
--Raiserror(@CMD,0,1) with nowait 

select @cmd = 'powershell.exe -command "& {' + @cmd + '}"'

if @debug is not null
 Raiserror(@CMD,0,1) with nowait 

declare @cmdout table (line varchar(max)) 
declare @RC int 

if isnull(@debug,0) <= 1 
Begin 


 insert into @cmdout(Line) 
 exec @rc = xp_cmdshell @command_string=@cmd 

if isnull(@RC,0) != 0 
Begin
   
   select @ERM = 'xp_cmdshell returned code:' + isnull(cast(@RC as varchar(10)),'NULL')
   select @ERM = coalesce(@ERM + char(10),'') + isnull(line,'') from @cmdout 

     Raiserror(@ERM,0,1) with nowait 

	 IF @Debug = 1 
	  select * from @cmdout 

	 Return 0;
END 

END

END
GO


IF 1=2
BEGIN
	exec sp_help_executesproc @procname='RaiseAlert'

	DECLARE @Message nvarchar(max) = null 
	,@Type varchar(20) = null 
	,@ErrorID int  = null 
	,@debug int  = null 

SELECT @Message = 'The Servers listed below have been found in Multiple Scom FEEDS 
OSGT3TPPESVC01,OSGT3TPPESVC02,WPCWTTBCTLPPE' --nvarchar
	,@Type = 'Error' --varchar
	,@ErrorID = 5000 --int
	,@debug = @debug --int

		

		EXECUTE ops.[dbo].RaiseAlert @Message = @Message --nvarchar
			,@Type = 'Error' --varchar
			,@ErrorID = 5000 --int
			,@debug = null --int



END