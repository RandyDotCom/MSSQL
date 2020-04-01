

declare @ERM nvarchar(max) 

select @ERM = Coalesce(@ERM+char(13)+char(10),'') + '<Error Servername="' + Convert(nvarchar(300),md.ServerName) + '" Object="'+ convert(nvarchar(300),md.ObjectName) +'" Owner="' + convert(nvarchar(300),md.owner) + '" />'
from (
select 
	ServerProperty('ServerName') [ServerName]
  ,   'Database:' + d.name [ObjectName] 
  , p.name [owner]
from 
  master.sys.databases d
  inner join master.sys.server_principals p on d.owner_sid = p.sid 
where p.name != 'sa' 
union 
select 
	ServerProperty('ServerName') [ServerName]
  ,   'Endpoint ' + d.name [ObjectName] 
  , p.name [owner]
from master.sys.endpoints d
inner join master.sys.server_principals p on d.principal_id = p.principal_id 
where p.name != 'sa' 
) MD 

if @ERM is not null 
  Raiserror(@ERM,11,1) 
