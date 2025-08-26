-- Initial Database Setup Script
-- This script creates a sample database and optimizes settings

USE master;
GO

-- Create a sample application database
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'SampleApp')
BEGIN
    CREATE DATABASE SampleApp;
    PRINT 'Database SampleApp created successfully.';
END
ELSE
BEGIN
    PRINT 'Database SampleApp already exists.';
END
GO

-- Switch to the new database
USE SampleApp;
GO

-- Create a sample table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Users')
BEGIN
    CREATE TABLE Users (
        Id int IDENTITY(1,1) PRIMARY KEY,
        Username nvarchar(50) NOT NULL UNIQUE,
        Email nvarchar(100) NOT NULL,
        CreatedDate datetime2 DEFAULT GETDATE(),
        IsActive bit DEFAULT 1
    );
    
    -- Insert sample data
    INSERT INTO Users (Username, Email) VALUES 
        ('admin', 'admin@example.com'),
        ('user1', 'user1@example.com'),
        ('user2', 'user2@example.com');
    
    PRINT 'Sample Users table created and populated.';
END
ELSE
BEGIN
    PRINT 'Users table already exists.';
END
GO

-- Create a sample log table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ActivityLog')
BEGIN
    CREATE TABLE ActivityLog (
        Id bigint IDENTITY(1,1) PRIMARY KEY,
        UserId int FOREIGN KEY REFERENCES Users(Id),
        Action nvarchar(100) NOT NULL,
        Description nvarchar(500),
        Timestamp datetime2 DEFAULT GETDATE(),
        IPAddress nvarchar(50)
    );
    
    -- Create index for better performance
    CREATE INDEX IX_ActivityLog_UserId_Timestamp ON ActivityLog (UserId, Timestamp);
    CREATE INDEX IX_ActivityLog_Timestamp ON ActivityLog (Timestamp);
    
    PRINT 'ActivityLog table created with indexes.';
END
ELSE
BEGIN
    PRINT 'ActivityLog table already exists.';
END
GO

-- Optimize tempdb settings
USE master;
GO

-- Get logical processor count
DECLARE @logical_cpus int;
SELECT @logical_cpus = cpu_count FROM sys.dm_os_sys_info;

-- Set tempdb files to match CPU count (up to 8)
DECLARE @tempdb_files int = CASE WHEN @logical_cpus > 8 THEN 8 ELSE @logical_cpus END;

PRINT 'Logical CPUs detected: ' + CAST(@logical_cpus AS nvarchar(10));
PRINT 'Recommended tempdb files: ' + CAST(@tempdb_files AS nvarchar(10));

-- Configure tempdb (these settings take effect after restart)
-- You can uncomment these if you want to optimize tempdb
/*
ALTER DATABASE tempdb MODIFY FILE (NAME = tempdev, SIZE = 512MB, FILEGROWTH = 128MB);
ALTER DATABASE tempdb MODIFY FILE (NAME = templog, SIZE = 128MB, FILEGROWTH = 64MB);
*/

-- Memory optimization settings
-- Set max server memory to 75% of available memory (adjust as needed)
DECLARE @max_memory_mb int;
DECLARE @total_memory_gb int;

-- Get total physical memory in GB (approximate)
SELECT @total_memory_gb = physical_memory_kb / 1024 / 1024 FROM sys.dm_os_sys_info;
SET @max_memory_mb = (@total_memory_gb * 1024 * 75) / 100; -- 75% of total

PRINT 'Total system memory (approx): ' + CAST(@total_memory_gb AS nvarchar(10)) + ' GB';
PRINT 'Recommended max server memory: ' + CAST(@max_memory_mb AS nvarchar(10)) + ' MB';

-- Uncomment to apply memory settings
/*
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'max server memory (MB)', @max_memory_mb;
RECONFIGURE;
*/

-- Create maintenance stored procedures
USE SampleApp;
GO

-- Procedure to get database size information
CREATE OR ALTER PROCEDURE sp_GetDatabaseInfo
AS
BEGIN
    SELECT 
        DB_NAME() as DatabaseName,
        
        -- Data file info
        SUM(CASE WHEN type_desc = 'ROWS' THEN size * 8.0 / 1024 END) AS DataSizeMB,
        SUM(CASE WHEN type_desc = 'ROWS' THEN FILEPROPERTY(name, 'SpaceUsed') * 8.0 / 1024 END) AS DataUsedMB,
        
        -- Log file info  
        SUM(CASE WHEN type_desc = 'LOG' THEN size * 8.0 / 1024 END) AS LogSizeMB,
        SUM(CASE WHEN type_desc = 'LOG' THEN FILEPROPERTY(name, 'SpaceUsed') * 8.0 / 1024 END) AS LogUsedMB,
        
        -- Total size
        SUM(size * 8.0 / 1024) AS TotalSizeMB
        
    FROM sys.database_files
    WHERE type IN (0, 1); -- Data and Log files only
END
GO

-- Procedure to get table sizes
CREATE OR ALTER PROCEDURE sp_GetTableSizes
AS
BEGIN
    SELECT 
        t.NAME AS TableName,
        s.Name AS SchemaName,
        p.rows AS RowCounts,
        CAST(ROUND(((SUM(a.total_pages) * 8) / 1024.00), 2) AS DECIMAL(36, 2)) AS TotalSpaceMB,
        CAST(ROUND(((SUM(a.used_pages) * 8) / 1024.00), 2) AS DECIMAL(36, 2)) AS UsedSpaceMB,
        CAST(ROUND(((SUM(a.total_pages) - SUM(a.used_pages)) * 8) / 1024.00, 2) AS DECIMAL(36, 2)) AS UnusedSpaceMB
    FROM 
        sys.tables t
    INNER JOIN      
        sys.indexes i ON t.OBJECT_ID = i.object_id
    INNER JOIN 
        sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
    INNER JOIN 
        sys.allocation_units a ON p.partition_id = a.container_id
    LEFT OUTER JOIN 
        sys.schemas s ON t.schema_id = s.schema_id
    WHERE 
        t.NAME NOT LIKE 'dt%' 
        AND t.is_ms_shipped = 0
        AND i.OBJECT_ID > 255 
    GROUP BY 
        t.Name, s.Name, p.Rows
    ORDER BY 
        TotalSpaceMB DESC;
END
GO

PRINT 'Database setup completed successfully!';
PRINT 'Sample database "SampleApp" created with Users and ActivityLog tables.';
PRINT 'Maintenance procedures created: sp_GetDatabaseInfo, sp_GetTableSizes';
PRINT '';
PRINT 'Usage examples:';
PRINT '  EXEC sp_GetDatabaseInfo;';
PRINT '  EXEC sp_GetTableSizes;';
PRINT '  SELECT * FROM Users;';
GO
