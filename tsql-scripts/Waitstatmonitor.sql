/**********************************************
          Monitoring Wait stats
          Credit to Bhuvanesh BhuviTheDataGuy 
***********************************************/

--========================================--
/*** 1. Monitor Current sessions wait ***/
--========================================--


SELECT
  dm_ws.wait_duration_ms,
  dm_ws.wait_type,
  dm_es.status,
  dm_t.TEXT,
  dm_qp.query_plan,
  dm_ws.session_ID,
  dm_es.cpu_time,
  dm_es.memory_usage,
  dm_es.logical_reads,
  dm_es.total_elapsed_time,
  dm_es.program_name,
  DB_NAME(dm_r.database_id) DatabaseName,
  -- Optional columns
  dm_ws.blocking_session_id,
  dm_r.wait_resource,
  dm_es.login_name,
  dm_r.command,
  dm_r.last_wait_type
FROM sys.dm_os_waiting_tasks dm_ws
INNER JOIN sys.dm_exec_requests dm_r
  ON dm_ws.session_id = dm_r.session_id
INNER JOIN sys.dm_exec_sessions dm_es
  ON dm_es.session_id = dm_r.session_id
CROSS APPLY sys.dm_exec_sql_text(dm_r.sql_handle) dm_t
CROSS APPLY sys.dm_exec_query_plan(dm_r.plan_handle) dm_qp
WHERE dm_es.is_user_process = 1
GO

--===========================================--
/*** 2. Monior waits for a specific period ***/
--===========================================--

-- Got this from SQLskills.com
-- You can set the time limit in > WAITFOR DELAY '00:30:00';

IF EXISTS (SELECT
    *
  FROM [tempdb].[sys].[objects]
  WHERE [name] = N'##SQLskillsStats1')
  DROP TABLE [##SQLskillsStats1];

IF EXISTS (SELECT
    *
  FROM [tempdb].[sys].[objects]
  WHERE [name] = N'##SQLskillsStats2')
  DROP TABLE [##SQLskillsStats2];
GO

SELECT
  [wait_type],
  [waiting_tasks_count],
  [wait_time_ms],
  [max_wait_time_ms],
  [signal_wait_time_ms] INTO ##SQLskillsStats1
FROM sys.dm_os_wait_stats;
GO

WAITFOR DELAY '00:30:00';
GO

SELECT
  [wait_type],
  [waiting_tasks_count],
  [wait_time_ms],
  [max_wait_time_ms],
  [signal_wait_time_ms] INTO ##SQLskillsStats2
FROM sys.dm_os_wait_stats;
GO

WITH [DiffWaits]
AS (SELECT
  -- Waits that weren't in the first snapshot
  [ts2].[wait_type],
  [ts2].[wait_time_ms],
  [ts2].[signal_wait_time_ms],
  [ts2].[waiting_tasks_count]
FROM [##SQLskillsStats2] AS [ts2]
LEFT OUTER JOIN [##SQLskillsStats1] AS [ts1]
  ON [ts2].[wait_type] = [ts1].[wait_type]
WHERE [ts1].[wait_type] IS NULL
AND [ts2].[wait_time_ms] > 0
UNION
SELECT
  -- Diff of waits in both snapshots
  [ts2].[wait_type],
  [ts2].[wait_time_ms] - [ts1].[wait_time_ms] AS [wait_time_ms],
  [ts2].[signal_wait_time_ms] - [ts1].[signal_wait_time_ms] AS [signal_wait_time_ms],
  [ts2].[waiting_tasks_count] - [ts1].[waiting_tasks_count] AS [waiting_tasks_count]
FROM [##SQLskillsStats2] AS [ts2]
LEFT OUTER JOIN [##SQLskillsStats1] AS [ts1]
  ON [ts2].[wait_type] = [ts1].[wait_type]
WHERE [ts1].[wait_type] IS NOT NULL
AND [ts2].[waiting_tasks_count] - [ts1].[waiting_tasks_count] > 0
AND [ts2].[wait_time_ms] - [ts1].[wait_time_ms] > 0),
[Waits]
AS (SELECT
  [wait_type],
  [wait_time_ms] / 1000.0 AS [WaitS],
  ([wait_time_ms] - [signal_wait_time_ms]) / 1000.0 AS [ResourceS],
  [signal_wait_time_ms] / 1000.0 AS [SignalS],
  [waiting_tasks_count] AS [WaitCount],
  100.0 * [wait_time_ms] / SUM([wait_time_ms]) OVER () AS [Percentage],
  ROW_NUMBER() OVER (ORDER BY [wait_time_ms] DESC) AS [RowNum]
FROM [DiffWaits]
WHERE [wait_type] NOT IN (
N'BROKER_EVENTHANDLER', N'BROKER_RECEIVE_WAITFOR',
N'BROKER_TASK_STOP', N'BROKER_TO_FLUSH',
N'BROKER_TRANSMITTER', N'CHECKPOINT_QUEUE',
N'CHKPT', N'CLR_AUTO_EVENT',
N'CLR_MANUAL_EVENT', N'CLR_SEMAPHORE',
N'DBMIRROR_DBM_EVENT', N'DBMIRROR_EVENTS_QUEUE',
N'DBMIRROR_WORKER_QUEUE', N'DBMIRRORING_CMD',
N'DIRTY_PAGE_POLL', N'DISPATCHER_QUEUE_SEMAPHORE',
N'EXECSYNC', N'FSAGENT',
N'FT_IFTS_SCHEDULER_IDLE_WAIT', N'FT_IFTSHC_MUTEX',
N'HADR_CLUSAPI_CALL', N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
N'HADR_LOGCAPTURE_WAIT', N'HADR_NOTIFICATION_DEQUEUE',
N'HADR_TIMER_TASK', N'HADR_WORK_QUEUE',
N'KSOURCE_WAKEUP', N'LAZYWRITER_SLEEP',
N'LOGMGR_QUEUE', N'ONDEMAND_TASK_QUEUE',
N'PWAIT_ALL_COMPONENTS_INITIALIZED',
N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
N'QDS_SHUTDOWN_QUEUE',
N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
N'REQUEST_FOR_DEADLOCK_SEARCH', N'RESOURCE_QUEUE',
N'SERVER_IDLE_CHECK', N'SLEEP_BPOOL_FLUSH',
N'SLEEP_DBSTARTUP', N'SLEEP_DCOMSTARTUP',
N'SLEEP_MASTERDBREADY', N'SLEEP_MASTERMDREADY',
N'SLEEP_MASTERUPGRADED', N'SLEEP_MSDBSTARTUP',
N'SLEEP_SYSTEMTASK', N'SLEEP_TASK',
N'SLEEP_TEMPDBSTARTUP', N'SNI_HTTP_ACCEPT',
N'SP_SERVER_DIAGNOSTICS_SLEEP', N'SQLTRACE_BUFFER_FLUSH',
N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
N'SQLTRACE_WAIT_ENTRIES', N'WAIT_FOR_RESULTS',
N'WAITFOR', N'WAITFOR_TASKSHUTDOWN',
N'WAIT_XTP_HOST_WAIT', N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG',
N'WAIT_XTP_CKPT_CLOSE', N'XE_DISPATCHER_JOIN',
N'XE_DISPATCHER_WAIT', N'XE_TIMER_EVENT'))
SELECT
  [W1].[wait_type] AS [WaitType],
  CAST([W1].[WaitS] AS decimal(16, 2)) AS [Wait_S],
  CAST([W1].[ResourceS] AS decimal(16, 2)) AS [Resource_S],
  CAST([W1].[SignalS] AS decimal(16, 2)) AS [Signal_S],
  [W1].[WaitCount] AS [WaitCount],
  CAST([W1].[Percentage] AS decimal(5, 2)) AS [Percentage],
  CAST(([W1].[WaitS] / [W1].[WaitCount]) AS decimal(16, 4)) AS [AvgWait_S],
  CAST(([W1].[ResourceS] / [W1].[WaitCount]) AS decimal(16, 4)) AS [AvgRes_S],
  CAST(([W1].[SignalS] / [W1].[WaitCount]) AS decimal(16, 4)) AS [AvgSig_S]
FROM [Waits] AS [W1]
INNER JOIN [Waits] AS [W2]
  ON [W2].[RowNum] <= [W1].[RowNum]
GROUP BY [W1].[RowNum],
         [W1].[wait_type],
         [W1].[WaitS],
         [W1].[ResourceS],
         [W1].[SignalS],
         [W1].[WaitCount],
         [W1].[Percentage]
HAVING SUM([W2].[Percentage]) - [W1].[Percentage] < 95; -- percentage threshold
GO

-- Cleanup
IF EXISTS (SELECT
    *
  FROM [tempdb].[sys].[objects]
  WHERE [name] = N'##SQLskillsStats1')
  DROP TABLE [##SQLskillsStats1];

IF EXISTS (SELECT
    *
  FROM [tempdb].[sys].[objects]
  WHERE [name] = N'##SQLskillsStats2')
  DROP TABLE [##SQLskillsStats2];
GO

