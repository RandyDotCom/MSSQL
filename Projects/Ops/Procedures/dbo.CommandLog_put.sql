USE [Ops]
GO

/****** Object:  StoredProcedure [dbo].[CommandLog_put]    Script Date: 9/14/2016 5:34:42 PM ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CommandLog_put]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[CommandLog_put]
GO

/****** Object:  StoredProcedure [dbo].[CommandLog_put]    Script Date: 9/14/2016 5:34:42 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CommandLog_put]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[CommandLog_put] AS' 
END
GO


ALTER procedure [dbo].[CommandLog_put]
	@ID int = null,
	@DatabaseName sysname = null,
	@SchemaName sysname = null,
	@ObjectName sysname = null,
	@ObjectType char(2) = null,
	@IndexName sysname = null,
	@IndexType tinyint = null,
	@StatisticsName sysname = null,
	@PartitionNumber int = null,
	@ExtendedInfo xml = null,
	@Command nvarchar(max) = null,
	@CommandType nvarchar(120) = null,
	@StartTime datetime = null,
	@EndTime datetime = null,
	@ErrorNumber int = null,
	@ErrorMessage nvarchar(max) = null,
	@xmlstring varchar(max) = null,
	@putdata bit = null,
	@userid int = null,
	@debug int = null
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;
  declare @erm nvarchar(max)

  
	if isnull(@putdata,0)=1 
	BEGIN
	 begin try
	  begin Transaction 
		/* Validate Data */
		  if exists (select * from [dbo].[CommandLog] where [ID]=@ID)
		  BEGIN

			UPDATE [dbo].[CommandLog] SET [DatabaseName] = @DatabaseName, [SchemaName] = @SchemaName, [ObjectName] = @ObjectName, [ObjectType] = @ObjectType, [IndexName] = @IndexName, [IndexType] = @IndexType, [StatisticsName] = @StatisticsName, [PartitionNumber] = @PartitionNumber, [ExtendedInfo] = @ExtendedInfo, [Command] = @Command, [CommandType] = @CommandType, [StartTime] = @StartTime, [EndTime] = @EndTime, [ErrorNumber] = @ErrorNumber, [ErrorMessage] = @ErrorMessage
			where [ID]=@ID

		  END
		  ELSE
		  BEGIN

			insert into [dbo].[CommandLog]([DatabaseName], [SchemaName], [ObjectName], [ObjectType], [IndexName], [IndexType], [StatisticsName], [PartitionNumber], [ExtendedInfo], [Command], [CommandType], [StartTime], [EndTime], [ErrorNumber], [ErrorMessage])
			values (@DatabaseName, @SchemaName, @ObjectName, @ObjectType, @IndexName, @IndexType, @StatisticsName, @PartitionNumber, @ExtendedInfo, @Command, @CommandType, @StartTime, @EndTime, @ErrorNumber, @ErrorMessage)

			SET @ID = scope_identity()
		  END
	  commit transaction
	end try
	begin catch 
	  rollback transaction
	    select @erm = ERROR_PROCEDURE() + 'Raised Error: ' + ERROR_MESSAGE()
		Raiserror(@ERM,11,1) with nowait 
	end catch

	END -- Valid @putdata

	exec [dbo].[CommandLog_get] @ID=@ID
		


END

GO


