USE [Ops]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[BackupFiles_temp]') AND type in (N'U'))
DROP TABLE [dbo].[BackupFiles_temp]
GO

--SET ANSI_NULLS ON ; SET QUOTED_IDENTIFIER ON;SET ANSI_PADDING ON
--GO

--IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[BackupFiles_temp]') AND type in (N'U'))
--BEGIN
--CREATE TABLE [dbo].[BackupFiles_temp](
--	[FileID] [int] IDENTITY(1,1) NOT NULL,
--	[BackupName] [nvarchar](128) NULL,
--	[BackupDescription] [nvarchar](255) NULL,
--	[BackupType] [smallint] NULL,
--	[ExpirationDate] [datetime] NULL,
--	[Compressed] [bit] NULL,
--	[Position] [smallint] NULL,
--	[DeviceType] [tinyint] NULL,
--	[UserName] [nvarchar](128) NULL,
--	[ServerName] [nvarchar](128) NULL,
--	[DatabaseName] [nvarchar](128) NULL,
--	[DatabaseVersion] [int] NULL,
--	[DatabaseCreationDate] [datetime] NULL,
--	[BackupSize] [numeric](20, 0) NULL,
--	[FirstLSN] [numeric](25, 0) NULL,
--	[LastLSN] [numeric](25, 0) NULL,
--	[CheckpointLSN] [numeric](25, 0) NULL,
--	[DatabaseBackupLSN] [numeric](25, 0) NULL,
--	[BackupStartDate] [datetime] NULL,
--	[BackupFinishDate] [datetime] NULL,
--	[SortOrder] [smallint] NULL,
--	[CodePage] [smallint] NULL,
--	[UnicodeLocaleId] [int] NULL,
--	[UnicodeComparisonStyle] [int] NULL,
--	[CompatibilityLevel] [tinyint] NULL,
--	[SoftwareVendorId] [int] NULL,
--	[SoftwareVersionMajor] [int] NULL,
--	[SoftwareVersionMinor] [int] NULL,
--	[SoftwareVersionBuild] [int] NULL,
--	[MachineName] [nvarchar](128) NULL,
--	[Flags ] [int] NULL,
--	[BindingID] [uniqueidentifier] NULL,
--	[RecoveryForkID] [uniqueidentifier] NULL,
--	[Collation] [nvarchar](128) NULL,
--	[FamilyGUID] [uniqueidentifier] NULL,
--	[HasBulkLoggedData] [bit] NULL,
--	[IsSnapshot] [bit] NULL,
--	[IsReadOnly] [bit] NULL,
--	[IsSingleUser] [bit] NULL,
--	[HasBackupChecksums] [bit] NULL,
--	[IsDamaged] [bit] NULL,
--	[BeginsLogChain] [bit] NULL,
--	[HasIncompleteMetaData] [bit] NULL,
--	[IsForceOffline] [bit] NULL,
--	[IsCopyOnly] [bit] NULL,
--	[FirstRecoveryForkID] [uniqueidentifier] NULL,
--	[ForkPointLSN] [numeric](25, 0) NULL,
--	[RecoveryModel] [nvarchar](60) NULL,
--	[DifferentialBaseLSN] [numeric](25, 0) NULL,
--	[DifferentialBaseGUID] [uniqueidentifier] NULL,
--	[BackupTypeDescription] [nvarchar](60) NULL,
--	[BackupSetGUID] [uniqueidentifier] NULL,
--	[CompressedBackupSize] [bigint] NULL,
--	[containment] [tinyint] NULL,
--	[KeyAlgorithm] [nvarchar](32) NULL,
--	[EncryptorThumbprint] [varbinary](20) NULL,
--	[EncryptorType] [nvarchar](32) NULL,
-- CONSTRAINT [PK_BackupFiles_temp] PRIMARY KEY CLUSTERED 
--(
--	[FileID] ASC
--)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
--) ON [PRIMARY]
--END
--GO

--SET ANSI_PADDING OFF
--GO


