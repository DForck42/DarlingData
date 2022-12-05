SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET STATISTICS TIME, IO OFF;
GO

/*
██╗  ██╗██╗   ██╗███╗   ███╗ █████╗ ███╗   ██╗      
██║  ██║██║   ██║████╗ ████║██╔══██╗████╗  ██║      
███████║██║   ██║██╔████╔██║███████║██╔██╗ ██║      
██╔══██║██║   ██║██║╚██╔╝██║██╔══██║██║╚██╗██║      
██║  ██║╚██████╔╝██║ ╚═╝ ██║██║  ██║██║ ╚████║      
╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝      
                                                    
███████╗██╗   ██╗███████╗███╗   ██╗████████╗███████╗
██╔════╝██║   ██║██╔════╝████╗  ██║╚══██╔══╝██╔════╝
█████╗  ██║   ██║█████╗  ██╔██╗ ██║   ██║   ███████╗
██╔══╝  ╚██╗ ██╔╝██╔══╝  ██║╚██╗██║   ██║   ╚════██║
███████╗ ╚████╔╝ ███████╗██║ ╚████║   ██║   ███████║
╚══════╝  ╚═══╝  ╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝

██████╗ ██╗      ██████╗  ██████╗██╗  ██╗
██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝
██████╔╝██║     ██║   ██║██║     █████╔╝ 
██╔══██╗██║     ██║   ██║██║     ██╔═██╗ 
██████╔╝███████╗╚██████╔╝╚██████╗██║  ██╗
╚═════╝ ╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
                                         
██╗   ██╗██╗███████╗██╗    ██╗███████╗██████╗ 
██║   ██║██║██╔════╝██║    ██║██╔════╝██╔══██╗
██║   ██║██║█████╗  ██║ █╗ ██║█████╗  ██████╔╝
╚██╗ ██╔╝██║██╔══╝  ██║███╗██║██╔══╝  ██╔══██╗
 ╚████╔╝ ██║███████╗╚███╔███╔╝███████╗██║  ██║
  ╚═══╝  ╚═╝╚══════╝ ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝

Copyright 2022 Darling Data, LLC
https://www.erikdarlingdata.com/

For usage and licensing details, run:
EXEC sp_HumanEventsBlockViewer
    @help = 1;

For working through errors:
EXEC sp_HumanEventsBlockViewer
    @debug = 1;

For support, head over to GitHub:
https://github.com/erikdarlingdata/DarlingData
*/

IF OBJECT_ID('dbo.sp_HumanEventsBlockViewer') IS NULL
   BEGIN
       EXEC ('CREATE PROCEDURE dbo.sp_HumanEventsBlockViewer AS RETURN 138;');
   END;
GO

ALTER PROCEDURE 
    dbo.sp_HumanEventsBlockViewer
(
    @session_name nvarchar(256) = N'keeper_HumanEvents_blocking',
    @target_type sysname = NULL,
    @start_date datetime2 = NULL,
    @end_date datetime2 = NULL,
    @database_name sysname = NULL,
    @help bit = 0,
    @debug bit = 0,
    @version varchar(30) = NULL OUTPUT,
    @version_date datetime = NULL OUTPUT
)
WITH RECOMPILE
AS
BEGIN
SET STATISTICS XML OFF;
SET NOCOUNT, XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

SELECT 
    @version = '1.13', 
    @version_date = '20221201';

IF @help = 1
BEGIN

    SELECT
        introduction = 
            'hi, i''m sp_HumanEventsBlockViewer!' UNION ALL
    SELECT  'you can use me in conjunction with sp_HumanEvents to quickly parse the sqlserver.blocked_process_report event' UNION ALL
    SELECT  'EXEC sp_HumanEvents @event_type = N''blocking'', @keep_alive = 1;' UNION ALL
    SELECT  'it will also work with another extended event session using the ring buffer as a target to capture blocking' UNION ALL
    SELECT  'all scripts and documentation are available here: https://github.com/erikdarlingdata/DarlingData/tree/main/sp_HumanEvents' UNION ALL
    SELECT  'from your loving sql server consultant, erik darling: erikdarlingdata.com';

    SELECT
        parameter_name =
            ap.name,
        data_type = t.name,
        description =
            CASE ap.name
                 WHEN '@session_name' THEN 'name of the extended event session to pull from'
                 WHEN '@target_type' THEN 'target of the extended event session'
                 WHEN '@start_date' THEN 'filter by date'
                 WHEN '@end_date' THEN 'filter by date'
                 WHEN '@database_name' THEN 'filter by database name'
                 WHEN '@help' THEN 'how you got here'
                 WHEN '@debug' THEN 'dumps raw temp table contents'
                 WHEN '@version' THEN 'OUTPUT; for support'
                 WHEN '@version_date' THEN 'OUTPUT; for support'
            END,
        valid_inputs =
            CASE ap.name
                 WHEN '@session_name' THEN 'extended event session name capturing sqlserver.blocked_process_report'
                 WHEN '@target_type' THEN 'event_file or ring_buffer'
                 WHEN '@start_date' THEN 'a reasonable date'
                 WHEN '@end_date' THEN 'a reasonable date'
                 WHEN '@database_name' THEN 'a database that exists on this server'
                 WHEN '@help' THEN '0 or 1'
                 WHEN '@debug' THEN '0 or 1'
                 WHEN '@version' THEN 'none; OUTPUT'
                 WHEN '@version_date' THEN 'none; OUTPUT'
            END,
        defaults =
            CASE ap.name
                 WHEN '@session_name' THEN 'keeper_HumanEvents_blocking'
                 WHEN '@target_type' THEN 'NULL'
                 WHEN '@start_date' THEN 'NULL; will shortcut to last 7 days'
                 WHEN '@end_date' THEN 'NULL'
                 WHEN '@database_name' THEN 'NULL'
                 WHEN '@help' THEN '0'
                 WHEN '@debug' THEN '0'
                 WHEN '@version' THEN 'none; OUTPUT'
                 WHEN '@version_date' THEN 'none; OUTPUT'
            END
    FROM sys.all_parameters AS ap
    JOIN sys.all_objects AS o
      ON ap.object_id = o.object_id
    JOIN sys.types AS t
      ON  ap.system_type_id = t.system_type_id
      AND ap.user_type_id = t.user_type_id
    WHERE o.name = N'sp_HumanEventsBlockViewer';

    SELECT 
        mit_license_yo = N'i am MIT licensed, so like, do whatever' UNION ALL
    SELECT N'see printed messages for full license';
    RAISERROR(N'
MIT License

Copyright 2022 Darling Data, LLC 

https://www.erikdarlingdata.com/

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), 
to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the 
following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE 
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
', 0, 1) WITH NOWAIT; 

RETURN;

END;

/*Set some variables for better decision-making later*/
DECLARE
    @azure bit = 
        CASE 
            WHEN CONVERT
                 (
                     int, 
                     SERVERPROPERTY('EngineEdition')
                 ) = 5
            THEN 1
            ELSE 0
        END,
    @session_id int,
    @target_session_id int,
    @file_name nvarchar(4000),
    @inputbuf_bom nvarchar(1) = CONVERT(nvarchar(1), 0x0a00, 0);

/*Use some sane defaults for input parameters*/
SELECT
    @start_date =
    CASE
        WHEN @start_date IS NULL
            THEN
                DATEADD
                (
                    MINUTE,
                    DATEDIFF
                    (
                        MINUTE,
                        SYSDATETIME(),
                        GETUTCDATE()
                    ),
                    ISNULL
                    (
                        @start_date,
                        DATEADD
                        (
                            DAY,
                            -7,
                            SYSDATETIME()
                        )
                    )
                )
            ELSE @start_date
        END,
    @end_date =
        CASE
            WHEN @end_date IS NULL
            THEN
                DATEADD
                (
                    MINUTE,
                    DATEDIFF
                    (
                        MINUTE,
                        SYSDATETIME(),
                        GETUTCDATE()
                    ),
                    ISNULL
                    (
                        @end_date,
                        SYSDATETIME()
                    )
                )
            ELSE @end_date
        END;

/*Temp tables for staging results*/
CREATE TABLE
    #x
(
    x xml
);

CREATE TABLE
    #blocking_xml
(
    human_events_xml xml
);

CREATE TABLE
    #block_findings
(
    id int IDENTITY PRIMARY KEY,
    check_id int NOT NULL,
    database_name nvarchar(256) NULL,
    object_name nvarchar(1000) NULL,
    finding_group nvarchar(100) NULL,
    finding nvarchar(4000) NULL
);

/*Look to see if the session exists and is running*/
IF @azure = 0
BEGIN
    IF NOT EXISTS
    (
        SELECT 
            1/0
        FROM sys.server_event_sessions AS ses
        JOIN sys.dm_xe_sessions AS dxs 
          ON dxs.name = ses.name
        WHERE ses.name = @session_name
        AND   dxs.create_time IS NOT NULL
    )
    BEGIN
        RAISERROR('A session with the name %s does not exist or is not currently active.', 0, 1, @session_name) WITH NOWAIT;
        RETURN;
    END;
END;

IF @azure = 1
BEGIN
    IF NOT EXISTS
    (
        SELECT 
            1/0
        FROM sys.database_event_sessions AS ses
        JOIN sys.dm_xe_database_sessions AS dxs 
          ON dxs.name = ses.name
        WHERE ses.name = @session_name
        AND   dxs.create_time IS NOT NULL
    )
    BEGIN
        RAISERROR('A session with the name %s does not exist or is not currently active.', 0, 1, @session_name) WITH NOWAIT;
        RETURN;
    END;
END;

/*Figure out if we have a file or ring buffer target*/
IF @target_type IS NULL
BEGIN
    IF @azure = 0
    BEGIN
        SELECT TOP (1)
            @target_type = 
                t.target_name
        FROM sys.dm_xe_sessions AS s
        JOIN sys.dm_xe_session_targets AS t
          ON s.address = t.event_session_address
        WHERE s.name = @session_name
        ORDER BY t.target_name;
    END;
    
    IF @azure = 1
    BEGIN
        SELECT TOP (1)
            @target_type = 
                t.target_name
        FROM sys.dm_xe_database_sessions AS s
        JOIN sys.dm_xe_database_session_targets AS t
          ON s.address = t.event_session_address
        WHERE s.name = @session_name
        ORDER BY t.target_name;
    END;
END;

/* Dump whatever we got into a temp table */
IF @target_type = N'ring_buffer'
BEGIN
    IF @azure = 0
    BEGIN   
        INSERT
            #x WITH(TABLOCKX)
        (
            x
        )
        SELECT 
            x = TRY_CAST(t.target_data AS xml)
        FROM sys.dm_xe_session_targets AS t
        JOIN sys.dm_xe_sessions AS s
          ON s.address = t.event_session_address
        WHERE s.name = @session_name
        AND   t.target_name = N'ring_buffer';
    END;
    
    IF @azure = 1 
    BEGIN
        INSERT
            #x WITH(TABLOCKX)
        (
            x
        )
        SELECT 
            x = TRY_CAST(t.target_data AS xml)
        FROM sys.dm_xe_database_session_targets AS t
        JOIN sys.dm_xe_database_sessions AS s
          ON s.address = t.event_session_address
        WHERE s.name = @session_name
        AND   t.target_name = N'ring_buffer';
    END;
END;

IF @target_type = N'event_file'
BEGIN   
    IF @azure = 0
    BEGIN
        SELECT
            @session_id = 
                t.event_session_id,
            @target_session_id = 
                t.target_id
        FROM sys.server_event_session_targets t
        JOIN sys.server_event_sessions s
          ON s.event_session_id = t.event_session_id
        WHERE t.name = @target_type 
        AND   s.name = @session_name;

        SELECT
            @file_name =
                CASE 
                    WHEN f.file_name LIKE N'%.xel'
                    THEN REPLACE(f.file_name, N'.xel', N'*.xel')
                    ELSE f.file_name + N'*.xel'
                END
        FROM 
        (
            SELECT 
                file_name = 
                        CONVERT
                        (
                            nvarchar(4000),
                            f.value
                        )
            FROM sys.server_event_session_fields AS f
            WHERE f.event_session_id = @session_id
            AND   f.object_id = @target_session_id
            AND   f.name = N'filename'
        ) AS f;
    END;
    
    IF @azure = 1
    BEGIN
        SELECT
            @session_id = 
                t.event_session_id,
            @target_session_id = 
                t.target_id
        FROM sys.dm_xe_database_session_targets t
        JOIN sys.dm_xe_database_sessions s 
          ON s.event_session_id = t.event_session_id
        WHERE t.name = @target_type 
        AND   s.name = @session_name;

        SELECT
            @file_name =
                CASE 
                    WHEN f.file_name LIKE N'%.xel'
                    THEN REPLACE(f.file_name, N'.xel', N'*.xel')
                    ELSE f.file_name + N'*.xel'
                END
        FROM 
        (
            SELECT 
                file_name = 
                        CONVERT
                        (
                            nvarchar(4000),
                            f.value
                        )
            FROM sys.server_event_session_fields AS f
            WHERE f.event_session_id = @session_id
            AND   f.object_id = @target_session_id
            AND   f.name = N'filename'
        ) AS f;
    END;

    INSERT
        #x WITH(TABLOCKX)
    (
        x
    )    
    SELECT
        x = TRY_CAST(f.event_data AS xml)
    FROM sys.fn_xe_file_target_read_file
         (
             @file_name, 
             NULL, 
             NULL, 
             NULL
         ) AS f;
END;


IF @target_type = N'ring_buffer'
BEGIN
    INSERT
        #blocking_xml WITH(TABLOCKX)
    (
        human_events_xml
    )
    SELECT 
        human_events_xml = e.x.query('.')
    FROM #x AS x
    CROSS APPLY x.x.nodes('/RingBufferTarget/event') AS e(x)
    WHERE e.x.exist('@name[ .= "blocked_process_report"]') = 1
    AND   e.x.exist('@timestamp[. >= sql:variable("@start_date")]') = 1
    AND   e.x.exist('@timestamp[. <  sql:variable("@end_date")]') = 1
    OPTION(RECOMPILE);
END;

IF @target_type = N'event_file'
BEGIN
    INSERT
        #blocking_xml WITH(TABLOCKX)
    (
        human_events_xml
    )
    SELECT 
        human_events_xml = e.x.query('.')
    FROM #x AS x
    CROSS APPLY x.x.nodes('/event') AS e(x)
    WHERE e.x.exist('@name[ .= "blocked_process_report"]') = 1
    AND   e.x.exist('@timestamp[. >= sql:variable("@start_date")]') = 1
    AND   e.x.exist('@timestamp[. <  sql:variable("@end_date")]') = 1
    OPTION(RECOMPILE);
END;

IF @debug = 1
BEGIN
    SELECT table_name = N'#blocking_xml', bx.* FROM #blocking_xml AS bx;
END;

    SELECT 
        event_time = 
            DATEADD
            (
                MINUTE, 
                DATEDIFF
                (
                    MINUTE, 
                    GETUTCDATE(), 
                    SYSDATETIME()
                ), 
                c.value('@timestamp', 'datetime2')
            ),        
        database_name = DB_NAME(c.value('(data[@name="database_id"]/value/text())[1]', 'int')),
        database_id = c.value('(data[@name="database_id"]/value/text())[1]', 'int'),
        object_id = c.value('(data[@name="object_id"]/value/text())[1]', 'int'),
        transaction_id = c.value('(data[@name="transaction_id"]/value/text())[1]', 'bigint'),
        resource_owner_type = c.value('(data[@name="resource_owner_type"]/text)[1]', 'nvarchar(256)'),
        monitor_loop = c.value('(//@monitorLoop)[1]', 'int'),
        spid = bd.value('(process/@spid)[1]', 'int'),
        ecid = bd.value('(process/@ecid)[1]', 'int'),            
        query_text_pre = bd.value('(process/inputbuf/text())[1]', 'nvarchar(MAX)'),
        wait_time = bd.value('(process/@waittime)[1]', 'bigint'),
        transaction_name = bd.value('(process/@transactionname)[1]', 'nvarchar(256)'),
        last_transaction_started = bd.value('(process/@lasttranstarted)[1]', 'datetime2'),
        last_transaction_completed = CONVERT(datetime2, NULL),
        wait_resource = bd.value('(process/@waitresource)[1]', 'nvarchar(100)'),
        lock_mode = bd.value('(process/@lockMode)[1]', 'nvarchar(10)'),
        status = bd.value('(process/@status)[1]', 'nvarchar(10)'),
        priority = bd.value('(process/@priority)[1]', 'int'),
        transaction_count = bd.value('(process/@trancount)[1]', 'int'),
        client_app = bd.value('(process/@clientapp)[1]', 'nvarchar(256)'),
        host_name = bd.value('(process/@hostname)[1]', 'nvarchar(256)'),
        login_name = bd.value('(process/@loginname)[1]', 'nvarchar(256)'),
        isolation_level = bd.value('(process/@isolationlevel)[1]', 'nvarchar(50)'),
        log_used = bd.value('(process/@logused)[1]', 'bigint'),
        clientoption1 = bd.value('(process/@clientoption1)[1]', 'bigint'),
        clientoption2 = bd.value('(process/@clientoption1)[1]', 'bigint'),
        activity = CASE WHEN oa.c.exist('//blocked-process-report/blocked-process') = 1 THEN 'blocked' END,
        blocked_process_report = c.query('.')
    INTO #blocked
    FROM #blocking_xml AS bx
    OUTER APPLY bx.human_events_xml.nodes('/event') AS oa(c)
    OUTER APPLY oa.c.nodes('//blocked-process-report/blocked-process') AS bd(bd);

    ALTER TABLE #blocked 
    ADD query_text 
    AS REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
       REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
       REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
           query_text_pre COLLATE Latin1_General_BIN2,
       NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
       NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
       NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),NCHAR(0),N'?') 
    PERSISTED;
    
    IF @debug = 1 BEGIN SELECT '#blocked' AS table_name, * FROM #blocked AS wa; END;
    
    SELECT 
        event_time = 
            DATEADD
            (
                MINUTE, 
                DATEDIFF
                (
                    MINUTE, 
                    GETUTCDATE(), 
                    SYSDATETIME()
                ), 
                c.value('@timestamp', 'datetime2')
            ),        
        database_name = DB_NAME(c.value('(data[@name="database_id"]/value/text())[1]', 'int')),
        database_id = c.value('(data[@name="database_id"]/value/text())[1]', 'int'),
        object_id = c.value('(data[@name="object_id"]/value/text())[1]', 'int'),
        transaction_id = c.value('(data[@name="transaction_id"]/value/text())[1]', 'bigint'),
        resource_owner_type = c.value('(data[@name="resource_owner_type"]/text)[1]', 'nvarchar(256)'),
        monitor_loop = c.value('(//@monitorLoop)[1]', 'int'),
        spid = bg.value('(process/@spid)[1]', 'int'),
        ecid = bg.value('(process/@ecid)[1]', 'int'),
        query_text_pre = bg.value('(process/inputbuf/text())[1]', 'nvarchar(MAX)'),
        wait_time = bg.value('(process/@waittime)[1]', 'bigint'),
        transaction_name = bg.value('(process/@transactionname)[1]', 'nvarchar(256)'),
        last_transaction_started = bg.value('(process/@lastbatchstarted)[1]', 'datetime2'),
        last_transaction_completed = bg.value('(process/@lastbatchcompleted)[1]', 'datetime2'),
        wait_resource = bg.value('(process/@waitresource)[1]', 'nvarchar(100)'),
        lock_mode = bg.value('(process/@lockMode)[1]', 'nvarchar(10)'),
        status = bg.value('(process/@status)[1]', 'nvarchar(10)'),
        priority = bg.value('(process/@priority)[1]', 'int'),
        transaction_count = bg.value('(process/@trancount)[1]', 'int'),
        client_app = bg.value('(process/@clientapp)[1]', 'nvarchar(256)'),
        host_name = bg.value('(process/@hostname)[1]', 'nvarchar(256)'),
        login_name = bg.value('(process/@loginname)[1]', 'nvarchar(256)'),
        isolation_level = bg.value('(process/@isolationlevel)[1]', 'nvarchar(50)'),
        log_used = bg.value('(process/@logused)[1]', 'bigint'),
        clientoption1 = bg.value('(process/@clientoption1)[1]', 'bigint'),
        clientoption2 = bg.value('(process/@clientoption1)[1]', 'bigint'),
        activity = CASE WHEN oa.c.exist('//blocked-process-report/blocking-process') = 1 THEN 'blocking' END,
        blocked_process_report = c.query('.')
    INTO #blocking
    FROM #blocking_xml AS bx
    OUTER APPLY bx.human_events_xml.nodes('/event') AS oa(c)
    OUTER APPLY oa.c.nodes('//blocked-process-report/blocking-process') AS bg(bg);
    
    ALTER TABLE #blocking 
    ADD query_text 
    AS REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
       REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
       REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
           query_text_pre COLLATE Latin1_General_BIN2,
       NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
       NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
       NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),NCHAR(0),N'?') 
    PERSISTED;

    IF @debug = 1 BEGIN SELECT '#blocking' AS table_name, * FROM #blocking AS wa; END;
    
    SELECT
        kheb.event_time,
        kheb.database_name,
        contentious_object = 
            ISNULL
            (
                kheb.contentious_object, 
                N'Unresolved: ' +
                N'database: ' +
                kheb.database_name +
                N' object_id: ' + 
                RTRIM(kheb.object_id) 
            ),
        kheb.activity,
        kheb.spid,
        kheb.ecid,
        query_text =
            CASE 
                WHEN kheb.query_text
                     LIKE @inputbuf_bom + N'Proc |[Database Id = %' ESCAPE N'|'
                THEN 
                    (
                        SELECT
                            [processing-instruction(query)] =                                       
                                OBJECT_SCHEMA_NAME
                                (
                                        SUBSTRING
                                        (
                                            kheb.query_text,
                                            CHARINDEX(N'Object Id = ', kheb.query_text) + 12,
                                            LEN(kheb.query_text) - (CHARINDEX(N'Object Id = ', kheb.query_text) + 12)
                                        )
                                        ,
                                        SUBSTRING
                                        (
                                            kheb.query_text, 
                                            CHARINDEX(N'Database Id = ', kheb.query_text) + 14, 
                                            CHARINDEX(N'Object Id', kheb.query_text) - (CHARINDEX(N'Database Id = ', kheb.query_text) + 14)
                                        )
                                ) + 
                                N'.' + 
                                OBJECT_NAME
                                (
                                     SUBSTRING
                                     (
                                         kheb.query_text,
                                         CHARINDEX(N'Object Id = ', kheb.query_text) + 12,
                                         LEN(kheb.query_text) - (CHARINDEX(N'Object Id = ', kheb.query_text) + 12)
                                     )
                                     ,
                                     SUBSTRING
                                     (
                                         kheb.query_text, 
                                         CHARINDEX(N'Database Id = ', kheb.query_text) + 14, 
                                         CHARINDEX(N'Object Id', kheb.query_text) - (CHARINDEX(N'Database Id = ', kheb.query_text) + 14)
                                     )
                                )
                        FOR XML
                            PATH(N''),
                            TYPE
                    )
                ELSE
                    (
                        SELECT 
                            [processing-instruction(query)] = 
                                kheb.query_text
                        FOR XML
                            PATH(N''),
                            TYPE
                    )
            END,
        wait_time_ms = 
            kheb.wait_time,
        kheb.status,
        kheb.isolation_level,
        kheb.lock_mode,
        c_sh.sql_handles,
        c_pn.proc_names,
        kheb.resource_owner_type,
        kheb.transaction_count,
        kheb.transaction_name,
        kheb.last_transaction_started,
        kheb.last_transaction_completed,
        client_option_1 = 
              SUBSTRING
              (    
                  CASE WHEN kheb.clientoption1 & 1 = 1 THEN ', DISABLE_DEF_CNST_CHECK' ELSE '' END + 
                  CASE WHEN kheb.clientoption1 & 2 = 2 THEN ', IMPLICIT_TRANSACTIONS' ELSE '' END + 
                  CASE WHEN kheb.clientoption1 & 4 = 4 THEN ', CURSOR_CLOSE_ON_COMMIT' ELSE '' END + 
                  CASE WHEN kheb.clientoption1 & 8 = 8 THEN ', ANSI_WARNINGS' ELSE '' END + 
                  CASE WHEN kheb.clientoption1 & 16 = 16 THEN ', ANSI_PADDING' ELSE '' END + 
                  CASE WHEN kheb.clientoption1 & 32 = 32 THEN ', ANSI_NULLS' ELSE '' END + 
                  CASE WHEN kheb.clientoption1 & 64 = 64 THEN ', ARITHABORT' ELSE '' END + 
                  CASE WHEN kheb.clientoption1 & 128 = 128 THEN ', ARITHIGNORE' ELSE '' END + 
                  CASE WHEN kheb.clientoption1 & 256 = 256 THEN ', QUOTED_IDENTIFIER' ELSE '' END + 
                  CASE WHEN kheb.clientoption1 & 512 = 512 THEN ', NOCOUNT' ELSE '' END + 
                  CASE WHEN kheb.clientoption1 & 1024 = 1024 THEN ', ANSI_NULL_DFLT_ON' ELSE '' END + 
                  CASE WHEN kheb.clientoption1 & 2048 = 2048 THEN ', ANSI_NULL_DFLT_OFF' ELSE '' END + 
                  CASE WHEN kheb.clientoption1 & 4096 = 4096 THEN ', CONCAT_NULL_YIELDS_NULL' ELSE '' END + 
                  CASE WHEN kheb.clientoption1 & 8192 = 8192 THEN ', NUMERIC_ROUNDABORT' ELSE '' END + 
                  CASE WHEN kheb.clientoption1 & 16384 = 16384 THEN ', XACT_ABORT' ELSE '' END,
                  3,
                  8000
              ),
          client_option_2 = 
              SUBSTRING
              (
                  CASE WHEN kheb.clientoption2 & 1024 = 1024 THEN ', DB CHAINING' ELSE '' END + 
                  CASE WHEN kheb.clientoption2 & 2048 = 2048 THEN ', NUMERIC ROUNDABORT' ELSE '' END + 
                  CASE WHEN kheb.clientoption2 & 4096 = 4096 THEN ', ARITHABORT' ELSE '' END + 
                  CASE WHEN kheb.clientoption2 & 8192 = 8192 THEN ', ANSI PADDING' ELSE '' END + 
                  CASE WHEN kheb.clientoption2 & 16384 = 16384 THEN ', ANSI NULL DEFAULT' ELSE '' END + 
                  CASE WHEN kheb.clientoption2 & 65536 = 65536 THEN ', CONCAT NULL YIELDS NULL' ELSE '' END + 
                  CASE WHEN kheb.clientoption2 & 131072 = 131072 THEN ', RECURSIVE TRIGGERS' ELSE '' END + 
                  CASE WHEN kheb.clientoption2 & 1048576 = 1048576 THEN ', DEFAULT TO LOCAL CURSOR' ELSE '' END + 
                  CASE WHEN kheb.clientoption2 & 8388608 = 8388608 THEN ', QUOTED IDENTIFIER' ELSE '' END + 
                  CASE WHEN kheb.clientoption2 & 16777216 = 16777216 THEN ', AUTO CREATE STATISTICS' ELSE '' END + 
                  CASE WHEN kheb.clientoption2 & 33554432 = 33554432 THEN ', CURSOR CLOSE ON COMMIT' ELSE '' END + 
                  CASE WHEN kheb.clientoption2 & 67108864 = 67108864 THEN ', ANSI NULLS' ELSE '' END + 
                  CASE WHEN kheb.clientoption2 & 268435456 = 268435456 THEN ', ANSI WARNINGS' ELSE '' END + 
                  CASE WHEN kheb.clientoption2 & 536870912 = 536870912 THEN ', FULL TEXT ENABLED' ELSE '' END + 
                  CASE WHEN kheb.clientoption2 & 1073741824 = 1073741824 THEN ', AUTO UPDATE STATISTICS' ELSE '' END + 
                  CASE WHEN kheb.clientoption2 & 1469283328 = 1469283328 THEN ', ALL SETTABLE OPTIONS' ELSE '' END,
                  3,
                  8000
              ),
        kheb.wait_resource,
        kheb.priority,
        kheb.log_used,
        kheb.client_app,
        kheb.host_name,
        kheb.login_name,
        kheb.transaction_id,
        kheb.blocked_process_report
    INTO #blocks
    FROM 
    (                
        SELECT 
            bg.*, 
            contentious_object = 
                OBJECT_NAME
                (
                    bg.object_id, 
                    bg.database_id
                )
        FROM #blocking AS bg
        WHERE (bg.database_name = @database_name OR @database_name IS NULL)
        
        UNION ALL 
        
        SELECT 
            bd.*, 
            contentious_object = 
                OBJECT_NAME
                (
                    bd.object_id, 
                    bd.database_id
                ) 
        FROM #blocked AS bd      
        WHERE (bd.database_name = @database_name OR @database_name IS NULL)
    ) AS kheb
    CROSS APPLY 
    (
      SELECT 
          sql_handles = 
              STUFF
              (
                  (
                      SELECT DISTINCT
                          ',' +
                          RTRIM
                          (
                              n.c.value('@sqlhandle', 'varchar(130)')
                          )
                      FROM kheb.blocked_process_report.nodes('//executionStack/frame') AS n(c)
                      WHERE n.c.value('@sqlhandle', 'varchar(130)') <> 0x
                      FOR XML
                          PATH(''),
                          TYPE
                  ).value('./text()[1]', 'varchar(max)'),
                  1,
                  1,
                  ''
              )                    
    ) AS c_sh
    CROSS APPLY 
    (
      SELECT 
          proc_names = 
              STUFF
              (
                  (
                      SELECT DISTINCT
                          ',' +
                          RTRIM
                          (
                              n.c.value('@procname', 'nvarchar(1024)')
                          )
                      FROM kheb.blocked_process_report.nodes('//executionStack/frame') AS n(c)
                      FOR XML
                          PATH(''),
                          TYPE
                  ).value('./text()[1]', 'nvarchar(max)'),
                  1,
                  1,
                  ''
              )                    
    ) AS c_pn;
    
    SELECT
        b.*
    FROM
    (
        SELECT
            b.*,
            n = 
                ROW_NUMBER() OVER
                (
                    PARTITION BY
                        b.transaction_id,
                        b.spid,
                        b.ecid
                    ORDER BY
                        b.event_time DESC
                )
        FROM #blocks AS b
    ) AS b
    WHERE b.n = 1
    ORDER BY 
        b.event_time DESC,
        CASE 
            WHEN b.activity = 'blocking' 
            THEN 1
            ELSE 999 
        END
    OPTION(RECOMPILE);

INSERT
    #block_findings
(
    check_id,
    database_name,
    object_name,
    finding_group,
    finding
)
SELECT
    check_id = -1,
    database_name = N'erikdarlingdata.com',
    object_name = N'sp_HumanEventsBlockViewer version ' + CONVERT(nvarchar(30), @version) + N'.',
    finding_group = N'https://github.com/erikdarlingdata/DarlingData',
    finding = N'blocking for period ' + CONVERT(nvarchar(10), @start_date, 23) + N' through ' + CONVERT(nvarchar(10), @end_date, 23) + N'.';

INSERT
    #block_findings
(
    check_id,
    database_name,
    object_name,
    finding_group,
    finding
)
SELECT
    check_id = 
        1,
    database_name = 
        b.database_name,
    object_name = 
        N'-',
    finding_group = 
        N'Database Locks',
    finding = 
        N'The database ' +
        b.database_name + 
        N' has been involved in ' +
        CONVERT(nvarchar(20), COUNT_BIG(DISTINCT b.transaction_id)) +
        N' blocking sessions.'
FROM #blocks AS b
GROUP BY b.database_name;

INSERT
    #block_findings
(
    check_id,
    database_name,
    object_name,
    finding_group,
    finding
)
SELECT
    check_id = 
        2,
    database_name = 
        b.database_name,
    object_name = 
        b.contentious_object,
    finding_group = 
        N'Object Locks',
    finding = 
        N'The object ' +
        b.contentious_object + 
        CASE 
            WHEN b.contentious_object LIKE N'Unresolved%'
            THEN N''
            ELSE N' in database ' + 
                 b.database_name 
        END + 
        N' has been involved in ' +
        CONVERT(nvarchar(20), COUNT_BIG(DISTINCT b.transaction_id)) +
        N' blocking sessions.'
FROM #blocks AS b
GROUP BY 
    b.database_name,
    b.contentious_object;

INSERT
    #block_findings
(
    check_id,
    database_name,
    object_name,
    finding_group,
    finding
)
SELECT
    check_id = 
        3,
    database_name = 
        b.database_name,
    object_name = 
        N'You Might Need RCSI',
    finding_group = 
        N'Blocking Involving Selects',
    finding = 
        N'There have been ' +
        CONVERT(nvarchar(20), COUNT_BIG(DISTINCT b.transaction_id)) +
        N' select queries involved in blocking sessions in ' +
        b.database_name +
        N'.'
FROM #blocks AS b
WHERE b.lock_mode IN 
      (
          N'S',
          N'IS'
      )
GROUP BY 
    b.database_name;

INSERT
    #block_findings
(
    check_id,
    database_name,
    object_name,
    finding_group,
    finding
)
SELECT
    check_id = 
        4,
    database_name = 
        b.database_name,
    object_name = 
        N'-',
    finding_group = 
        N'Repeatable Read Blocking',
    finding = 
        N'There have been ' +
        CONVERT(nvarchar(20), COUNT_BIG(DISTINCT b.transaction_id)) +
        N' repeatable read queries involved in blocking sessions in ' +
        b.database_name +
        N'.'
FROM #blocks AS b
WHERE b.isolation_level LIKE N'repeatable%'
GROUP BY 
    b.database_name;


INSERT
    #block_findings
(
    check_id,
    database_name,
    object_name,
    finding_group,
    finding
)
SELECT
    check_id = 
        5,
    database_name = 
        b.database_name,
    object_name = 
        N'-',
    finding_group = 
        N'Serializable Blocking',
    finding = 
        N'There have been ' +
        CONVERT(nvarchar(20), COUNT_BIG(DISTINCT b.transaction_id)) +
        N' serializable queries involved in blocking sessions in ' +
        b.database_name +
        N'.'
FROM #blocks AS b
WHERE b.isolation_level LIKE N'serializable%'
GROUP BY 
    b.database_name;

INSERT
    #block_findings
(
    check_id,
    database_name,
    object_name,
    finding_group,
    finding
)
SELECT
    check_id = 
        6,
    database_name = 
        b.database_name,
    object_name = 
        N'-',
    finding_group = 
        N'Sleeping Query Blocking',
    finding = 
        N'There have been ' +
        CONVERT(nvarchar(20), COUNT_BIG(DISTINCT b.transaction_id)) +
        N' sleeping queries involved in blocking sessions in ' +
        b.database_name +
        N'.'
FROM #blocks AS b
WHERE b.status = N'sleeping'
GROUP BY 
    b.database_name;

INSERT
    #block_findings
(
    check_id,
    database_name,
    object_name,
    finding_group,
    finding
)
SELECT
    check_id = 
        7,
    database_name = 
        b.database_name,
    object_name = 
        N'-',
    finding_group = 
        N'Implicit Transaction Blocking',
    finding = 
        N'There have been ' +
        CONVERT(nvarchar(20), COUNT_BIG(DISTINCT b.transaction_id)) +
        N' implicit transaction queries involved in blocking sessions in ' +
        b.database_name +
        N'.'
FROM #blocks AS b
WHERE b.transaction_name = N'implicit_transaction'
GROUP BY 
    b.database_name;

INSERT
    #block_findings
(
    check_id,
    database_name,
    object_name,
    finding_group,
    finding
)
SELECT
    check_id = 
        7,
    database_name = 
        b.database_name,
    object_name = 
        N'-',
    finding_group = 
        N'User Transaction Blocking',
    finding = 
        N'There have been ' +
        CONVERT(nvarchar(20), COUNT_BIG(DISTINCT b.transaction_id)) +
        N' user transaction queries involved in blocking sessions in ' +
        b.database_name +
        N'.'
FROM #blocks AS b
WHERE b.transaction_name = N'user_transaction'
GROUP BY 
    b.database_name;

INSERT
    #block_findings
(
    check_id,
    database_name,
    object_name,
    finding_group,
    finding
)
SELECT
    check_id = 8,
    b.database_name,
    object_name = N'-',
    finding_group = N'Login, App, and Host blocking',
    finding =
        N'This database has had ' +
        CONVERT
        (
            nvarchar(20),
            COUNT_BIG(DISTINCT b.transaction_id)
        ) +
        N' instances of blocking involving the login ' +
        ISNULL
        (
            b.login_name,
            N'UNKNOWN'
        ) +
        N' from the application ' +
        ISNULL
        (
            b.client_app,
            N'UNKNOWN'
        ) +
        N' on host ' +
        ISNULL
        (
            b.host_name,
            N'UNKNOWN'
        ) +
        N'.'
FROM #blocks AS b
GROUP BY
    b.database_name,
    b.login_name,
    b.client_app,
    b.host_name;


WITH
    b AS
(
    SELECT
        b.database_name,
        b.transaction_id,
        wait_time_ms = 
            MAX(b.wait_time_ms)
    FROM #blocks AS b
    GROUP BY 
        b.database_name, 
        b.transaction_id
)
INSERT
    #block_findings
(
    check_id,
    database_name,
    object_name,
    finding_group,
    finding
)
SELECT
    check_id = 
        1000,
    b.database_name,
    object_name = 
        N'-',
    finding_group = 
        N'Total database block wait time',
    finding = 
        N'This database has had ' +
        CONVERT
        (
            nvarchar(30),
            (
                SUM
                (
                    CONVERT
                    (
                        bigint,
                        b.wait_time_ms
                    )
                ) / 1000 / 86400
            )
        ) +
        N' ' +
        CONVERT
          (
              nvarchar(30),
              DATEADD
              (
                  MILLISECOND,
                  (
                      SUM
                      (
                          CONVERT
                          (
                              bigint,
                              b.wait_time_ms
                          )
                      )
                  ),
                  0
              ),
              14
          ) +
        N' [dd hh:mm:ss:ms] of deadlock wait time.'
FROM b AS b
GROUP BY
    b.database_name;

WITH
    b AS
(
    SELECT
        b.database_name,
        b.transaction_id,
        b.contentious_object,
        wait_time_ms = 
            MAX(b.wait_time_ms)
    FROM #blocks AS b
    GROUP BY 
        b.database_name, 
        b.contentious_object,
        b.transaction_id
)
INSERT
    #block_findings
(
    check_id,
    database_name,
    object_name,
    finding_group,
    finding
)
SELECT
    check_id = 
        1001,
    b.database_name,
    object_name = 
        b.contentious_object,
    finding_group = 
        N'Total database and object block wait time',
    finding = 
        N'This object has had ' +
        CONVERT
        (
            nvarchar(30),
            (
                SUM
                (
                    CONVERT
                    (
                        bigint,
                        b.wait_time_ms
                    )
                ) / 1000 / 86400
            )
        ) +
        N' ' +
        CONVERT
          (
              nvarchar(30),
              DATEADD
              (
                  MILLISECOND,
                  (
                      SUM
                      (
                          CONVERT
                          (
                              bigint,
                              b.wait_time_ms
                          )
                      )
                  ),
                  0
              ),
              14
          ) +
        N' [dd hh:mm:ss:ms] of deadlock wait time in database ' +
        b.database_name
FROM b AS b
GROUP BY
    b.database_name,
    b.contentious_object;

INSERT
    #block_findings
(
    check_id,
    database_name,
    object_name,
    finding_group,
    finding
)
SELECT
    check_id = 2147483647,
    database_name = N'erikdarlingdata.com',
    object_name = N'sp_HumanEventsBlockViewer version ' + CONVERT(nvarchar(30), @version) + N'.',
    finding_group = N'https://github.com/erikdarlingdata/DarlingData',
    finding = N'thanks for using me!';



SELECT
    bf.check_id,
    bf.database_name,
    bf.object_name,
    bf.finding_group,
    bf.finding
FROM #block_findings AS bf
ORDER BY bf.check_id;

END; --Final End
GO