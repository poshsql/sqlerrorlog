USE [TEST]
GO
/****** Object:  StoredProcedure [dbo].[GetErrorLogEvents]    Script Date: 5/7/2013 8:06:02 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




ALTER PROCEDURE [dbo].[spDBA_GETErrorLogEvents] ( @debug int = 0, @NumberOfMinutes int = 5,
    @mailto varchar(100)='ss@gmail.com')
AS
set nocount on
--GetErrorLogEvents @NumberOfMinutes=20000,@debug=1
 
declare @count  smallint,
        @SQL    varchar(1000),
		@runtime datetime

set @runtime = getdate()
 
 
if object_id('tempdb..#errors') is not null
begin
   drop table #errors
end
 
CREATE TABLE #errors
(
	RowID int IDENTITY PRIMARY KEY,
	EntryTime datetime,
	source varchar(50),
	LogEntry varchar(4000)
)
	--Read just two files
	select @SQL = 'exec master..xp_readerrorlog '
	insert into #errors (entrytime, source, logentry)
	execute (@SQL)
	select @SQL = 'exec master..xp_readerrorlog 1'
	insert into #errors (entrytime, source, logentry)
	execute (@SQL)
 
delete #errors 
where (logentry not like '%err%'
		AND logentry not like '%warn%'
		AND logentry not like '%kill%'
		AND logentry not like '%dead%'
		AND logentry not like '%cannot%'
		AND logentry not like '%could%'
		AND logentry not like '%fail%'
		AND logentry not like '%not%'
		AND logentry not like '%stop%'
		AND logentry not like '%terminate%'
		AND logentry not like '%bypass%'
		AND logentry not like '%roll%'
		AND logentry not like '%truncate%'
		AND logentry not like '%upgrade%'
		AND logentry not like '%victim%'
		AND logentry not like '%recover%'
		AND logentry not like '%IO requests taking longer than%')
		OR logentry like '%errorlog%'
		OR logentry like '%error log%'
		OR logentry like '%dbcc%'
		OR logentry like '%error%severity%state%'
		OR logentry like '%SQL Trace stopped%'
		OR LogEntry like 'Login failed for user%'
		OR LogEntry like '%msdb.dbo.ExternalMailQueue%This is an informational message only. No user action is required%'
		OR LogEntry like 'The Service Broker endpoint is in disabled or stopped state%'
		OR LogEntry like '%msdb.dbo.ExternalMailQueue%'
		OR LogEntry like '%suppressed%'
		OR LogEntry like '%This is an informational message only. No user action is required.'
		OR LogEntry like 'An error occurred in Service Broker internal activation while trying to scan the user queue%'
 
DELETE #Errors 
WHERE EntryTime IS NULL OR EntryTime <  dateadd(mi, (-1*@NumberOfMinutes), @runtime)
 
-- If local only return the events table back to the Results Grid
IF @debug = 1
BEGIN
	SELECT *
	FROM #errors
	
END
ELSE -- Insert the errors into the SystemEvents table to trigger notification.
BEGIN
 	declare @sum as varchar(max)
	select @sum = 
	cast(( 
	SELECT 
		TD = EntryTime,'',
		TD = Source,'',
		TD = LogEntry
FROM #errors
	FOR XML PATH('TR'))  
 as varchar(max))

 

 if @sum is null return --if nothing no mail

  	declare @sum1 as varchar(max)
	select @sum1 = 
	cast(( 
	SELECT 
		TD = EntryTime,'',
		TD = Source,'',
		TD = LogEntry
FROM #errors
WHERE logentry like '%resolving%'
	FOR XML PATH('TR'))  
 as varchar(max))



 
 Declare 
        @EmailBody varchar(max) = '',    
        @EmailFinal varchar(max) = '',
        @HTMLHT varchar(512)    

Set @HTMLHT = 
    '<head>
            <STYLE TYPE="text/css">
                            <!--
                            TD{font-family: consolas; font-size: 10pt; white-space: wrap;}
                            --->
            </STYLE>
    </head>'


SET @EmailBody =    
    N'<BR>
	<TABLE border="2" frame="hsides" rules="groups" 
          summary="ErrorLog SQL">
			<CAPTION>ErrorLog - SQL</CAPTION>

			<THEAD valign="top" >
			<TR>
				<TH>EntryTime
				<TH>Log
				<TH>Source
			<TBODY>
			$$ReplaceSummery$$
			</TABLE>
			<BR>'



    Set @EmailBody = REPLACE (@EmailBody, '<TD>','<TD nowrap>')
--	Set @sum = REPLACE (@sum, '<TD>sleeping</TD>','<TD bgcolor=red>sleeping</TD>')
	Set @EmailBody = REPLACE (@EmailBody, '$$ReplaceSummery$$',@sum)
	--Set @EmailBody = REPLACE (@EmailBody, '$$ReplaceInputbuffer$$',@ib)
    Set @EmailFinal = @HTMLHT + @EmailBody


	--select @Emailfinal

EXEC msdb.dbo.sp_send_dbmail
				@profile_name = 'profilename',
				@recipients = @mailto,
				@subject = 'Errorlog Enteries',
				@body_format = 'html',
				@importance = 'High',
				@body = @EmailFinal

END

DROP TABLE #Errors




