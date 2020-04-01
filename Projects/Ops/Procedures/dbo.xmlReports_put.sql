use ops
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[xmlReports_put]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[xmlReports_put]
GO

SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[xmlReports_put]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[xmlReports_put] AS' 
END
GO

ALTER procedure [dbo].[xmlReports_put]
	@Property varchar(50) = null,
	@Context varchar(50) = null,
	@xData xml = null,
	@Filename varchar(max) = null, 
	@arcpath varchar(max) = null, 
	@DateCollected datetime = null,
	@xdid int = null output,
	@debug int = null
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @ERM NVARCHAR(MAX), @ERS INT

	Select @property=isnull(@property,system_user) 
	Select @context = isnull(@context, Convert(varchar(100),getdate())) 
	select @DateCollected = isnull(@DateCollected,getdate())

declare @stmt nvarchar(max) 

if @xdata is null 
BEGIN
 if @Filename is not null 
 BEGIN 

	if @debug is not null
	Begin
	  select @ERM = 'Importing ' + @filename 
	  Raiserror(@Filename,0,1) with nowait 
	end 

	declare @xd table (xdata xml) 
	
	SELECT @STMT = N'SELECT * FROM OPENROWSET( BULK ''' + @Filename + ''', SINGLE_BLOB) AS x'
	IF @debug is not null Raiserror(@STMT,0,1) with nowait 

	insert into @xd(xdata) 
	Exec (@stmt) 
	select @xdata = xdata from @xd 
		
 END
END

if @debug=2 
Begin 
  select * from @xd 
  Select @xData 
  Return 1; 
end 

if @xData is null 
  Begin
	select @ERM = 'Data For ' + @Property + '[' + @context + '] was Null'
	Raiserror(@ERM,11,1) 
	Return 0;
  End 

  /* Rename Context for Errors other then regKey errors which are common */
  if @xdata.exist('//Error')=1 
  BEGIN

   /* Rename Context for Errors When Errors are not expected May Be Depricate this */
	if @context not in ('RegKeys','MissingOUData')  
		select @context = @context + ' Errors'

  END
  else
  begin
	/*Remove Errors if Contextually successfull*/
	delete from dbo.xmlreports where property=@property and context = (@context + ' Errors')
  end 

IF @xdid is not null 
Begin
	if not exists (select * from [dbo].[xmlReports] where [xdid]=@xdid)
	Begin
		Raiserror('Record not found, unusal error',11,1) 
		Return 0;
	END  
END
ELSE
Begin
	SELECT @xdid = xdid from [dbo].[xmlReports] where Property = @Property and Context=@context 
END

	begin try 
	  begin Transaction 
		/* Validate Data */
		  if @xdid is not null
		  BEGIN

			UPDATE [dbo].[xmlReports]
				 SET [Property] = @Property
				 , [Context] = @Context
				 , [DateCollected]=@dateCollected
				 , [xData] = @xData
			where [xdid]=@xdid

		  END
		  ELSE
		  BEGIN

			insert into [dbo].[xmlReports]([Property], [Context], [xData])
			values (@Property, @Context, @xData)

			SET @xdid = scope_identity()
		  END
	  commit transaction
	end try
	begin catch 
	  rollback transaction
	    select @erm = ERROR_PROCEDURE() + 'Raised Error: ' + ERROR_MESSAGE()
		Raiserror(@ERM,11,1) with nowait 
		return 0; 
	end catch



if @arcpath is not null 
Begin 
	declare @command nvarchar(4000)
		select @command='MOVE "' + @filename + '" "' + @arcpath+ '"' 
		if @debug > 0 
		 Raiserror(@command,0,1) with nowait
		Exec xp_cmdshell @command , no_output 

end 

	if @debug > 0 
	Begin
		select @ERM = @Property + ' ' + @context + ' ' + cast(@xdid as varchar(100))
		Raiserror(@ERM,0,1) with nowait 

	end

if @debug >= 2
	exec [dbo].[xmlReports_get] @xdid=@xdid
		

END


GO

IF 1=2 
BEGIN

exec sp_help_executesproc @procname='xmlReports_put', @schema='dbo'

DECLARE @xdid int  = null 
	,@Property varchar(50) = null 
	,@Context varchar(50) = null 
	,@DateCollected datetime  = null 
	,@xData xml  = null 
	,@Filename varchar(max) = null 
	,@arcpath varchar(max) = null 
	,@debug int  = null 

SELECT @xdid = @xdid  --int
	,@Property = @Property --varchar
	,@Context = @Context --varchar
	,@DateCollected = @DateCollected --datetime
	,@xData = @xData --xml
	,@Filename = @Filename --varchar
	,@arcpath = @arcpath --varchar
	,@debug = @debug --int

EXECUTE [dbo].xmlReports_put @xdid = @xdid OUTPUT  --int
	,@Property = @Property --varchar
	,@Context = @Context --varchar
	,@DateCollected = @DateCollected --datetime
	,@xData = @xData --xml
	,@Filename = @Filename --varchar
	,@arcpath = @arcpath --varchar
	,@debug = @debug --int

END 

