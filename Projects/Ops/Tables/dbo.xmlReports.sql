/*

*/

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[xmlReports]') AND type in (N'U'))
	DROP TABLE [dbo].[xmlReports]
GO

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;SET ANSI_PADDING ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[xmlReports]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[xmlReports](
	[xdid] [int] IDENTITY(1,1) NOT NULL,
	[Property] [nvarchar](128) NULL,
	[Context] [nvarchar](255) NULL,
	[xData] [xml] NULL,
	[DateCollected] [datetime] NOT NULL CONSTRAINT [DF_xmlReports_DateCollected]  DEFAULT (getdate()),
 CONSTRAINT [PK_xmlReports_1] PRIMARY KEY CLUSTERED 
(
	[xdid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
GO




--/* To prevent any potential data loss issues, you should review this script in detail before running it outside the context of the database designer.*/
--BEGIN TRANSACTION
--SET QUOTED_IDENTIFIER ON
--SET ARITHABORT ON
--SET NUMERIC_ROUNDABORT OFF
--SET CONCAT_NULL_YIELDS_NULL ON
--SET ANSI_NULLS ON
--SET ANSI_PADDING ON
--SET ANSI_WARNINGS ON
--COMMIT
--BEGIN TRANSACTION
--GO
--if Exists(select * from sys.objects where name='DF_xmlReports_DateCollected' and type='D')
--BEGIN
--ALTER TABLE dbo.xmlReports
--	DROP CONSTRAINT DF_xmlReports_DateCollected
--END
--GO
--CREATE TABLE dbo.Tmp_xmlReports
--	(
--	xdid int NOT NULL IDENTITY (1, 1),
--	Property nvarchar(128) NULL,
--	Context nvarchar(255) NULL,
--	xData xml NULL,
--	DateCollected datetime NOT NULL
--	)  ON [PRIMARY]
--	 TEXTIMAGE_ON [PRIMARY]
--GO
--ALTER TABLE dbo.Tmp_xmlReports SET (LOCK_ESCALATION = TABLE)
--GO
--ALTER TABLE dbo.Tmp_xmlReports ADD CONSTRAINT
--	DF_xmlReports_DateCollected DEFAULT (getdate()) FOR DateCollected
--GO
--SET IDENTITY_INSERT dbo.Tmp_xmlReports ON
--GO
--IF EXISTS(SELECT * FROM dbo.xmlReports)
--	 EXEC('INSERT INTO dbo.Tmp_xmlReports (xdid, Property, Context, xData, DateCollected)
--		SELECT xdid, CONVERT(nvarchar(128), Property), CONVERT(nvarchar(255), Context), xData, DateCollected FROM dbo.xmlReports WITH (HOLDLOCK TABLOCKX)')
--GO
--SET IDENTITY_INSERT dbo.Tmp_xmlReports OFF
--GO
--DROP TABLE dbo.xmlReports
--GO
--EXECUTE sp_rename N'dbo.Tmp_xmlReports', N'xmlReports', 'OBJECT' 
--GO
--ALTER TABLE dbo.xmlReports ADD CONSTRAINT
--	PK_xmlReports_1 PRIMARY KEY CLUSTERED 
--	(
--	xdid
--	) WITH( PAD_INDEX = OFF, FILLFACTOR = 90, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

--GO
--CREATE NONCLUSTERED INDEX ix__Context_Property ON dbo.xmlReports
--	(
--	Context,
--	Property
--	) WITH( PAD_INDEX = OFF, FILLFACTOR = 90, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
--GO
--COMMIT

--ExitScript: 
--WHILE @@TRANCOUNT > 0 
--BEGIN
--	ROLLBACK 
--END
--GO

