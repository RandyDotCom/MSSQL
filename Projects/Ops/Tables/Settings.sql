USE [ops]
GO

SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;SET ANSI_PADDING ON
GO

declare @ERM nvarchar(max)

BEGIN TRY 
  Begin Transaction 

  IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Settings]') AND type in (N'U'))
  BEGIN

  SELECT [Context]
      ,[Name]
      ,[Value]
  into dbo.TempSettings 
  FROM [dbo].[Settings]

	exec ('DROP TABLE [dbo].[Settings]')

 END 


	Exec (N'CREATE TABLE [dbo].[Settings](
	[idSettings] [int] IDENTITY(1,1) NOT NULL,
	[Context] [varchar](50) NULL,
	[Name] [varchar](200) NULL,
	[Value] [nvarchar](max) NULL,
 CONSTRAINT [PK_Settings] PRIMARY KEY CLUSTERED 
(
	[idSettings] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]') 


IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TempSettings]') AND type in (N'U'))
BEGIN 

INSERT INTO [dbo].[Settings]
           ([Context]
           ,[Name]
           ,[Value])
SELECT [Context]
      ,[Name]
      ,[Value]
  FROM dbo.TempSettings 

  exec ('DROP TABLE [dbo].[TempSettings]')

END 

Commit Transaction 
End Try 
Begin Catch 
	Rollback Transaction 
	 select @ERM = Error_message() 
	 Raiserror(@ERM,11,1) with nowait 

end Catch

While @@TRANCOUNT > 0 
Begin
	Rollback Transaction 
end 
GO

/* To prevent any potential data loss issues, you should review this script in detail before running it outside the context of the database designer.*/
BEGIN TRANSACTION
SET QUOTED_IDENTIFIER ON
SET ARITHABORT ON
SET NUMERIC_ROUNDABORT OFF
SET CONCAT_NULL_YIELDS_NULL ON
SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
COMMIT
BEGIN TRANSACTION
GO
CREATE TABLE dbo.Tmp_Settings
	(
	idSettings int NOT NULL IDENTITY (1, 1),
	Context varchar(200) NULL,
	Name varchar(MAX) NULL,
	Value nvarchar(MAX) NULL
	)  ON [PRIMARY]
	 TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE dbo.Tmp_Settings SET (LOCK_ESCALATION = TABLE)
GO
SET IDENTITY_INSERT dbo.Tmp_Settings ON
GO
IF EXISTS(SELECT * FROM dbo.Settings)
	 EXEC('INSERT INTO dbo.Tmp_Settings (idSettings, Context, Name, Value)
		SELECT idSettings, Context, CONVERT(varchar(MAX), Name), Value FROM dbo.Settings WITH (HOLDLOCK TABLOCKX)')
GO
SET IDENTITY_INSERT dbo.Tmp_Settings OFF
GO
DROP TABLE dbo.Settings
GO
EXECUTE sp_rename N'dbo.Tmp_Settings', N'Settings', 'OBJECT' 
GO
ALTER TABLE dbo.Settings ADD CONSTRAINT
	PK_Settings PRIMARY KEY CLUSTERED 
	(
	idSettings
	) WITH( PAD_INDEX = OFF, FILLFACTOR = 90, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

GO
COMMIT
GO

--select * from ops.dbo.settings