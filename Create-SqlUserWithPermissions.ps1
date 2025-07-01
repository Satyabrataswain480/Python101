param(
    [Parameter(Mandatory = $true)] [string]$SqlServer,
    [Parameter(Mandatory = $true)] [string]$AdminUser,
    [Parameter(Mandatory = $true)] [string]$AdminPassword,
    [Parameter(Mandatory = $true)] [string]$SqlUser,
    [Parameter(Mandatory = $true)] [string]$SqlUserPassword,
    [Parameter(Mandatory = $true)] [string]$MainDb,
    [Parameter(Mandatory = $true)] [string]$ReadModelDb
)

Import-Module SqlServer

$createUserSql = @"
IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = '$SqlUser')
BEGIN
    CREATE LOGIN [$SqlUser] WITH PASSWORD = '$SqlUserPassword', CHECK_POLICY = OFF;
END;

USE [$MainDb];
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = '$SqlUser')
BEGIN
    CREATE USER [$SqlUser] FOR LOGIN [$SqlUser];
    ALTER ROLE db_datareader ADD MEMBER [$SqlUser];
    ALTER ROLE db_datawriter ADD MEMBER [$SqlUser];
END;

USE [$ReadModelDb];
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = '$SqlUser')
BEGIN
    CREATE USER [$SqlUser] FOR LOGIN [$SqlUser];
    ALTER ROLE db_datareader ADD MEMBER [$SqlUser];
    ALTER ROLE db_datawriter ADD MEMBER [$SqlUser];
END;
"@

Write-Host "Executing SQL to create user and assign permissions..."

$connectionString = "Server=$SqlServer;Database=master;User ID=$AdminUser;Password=$AdminPassword;TrustServerCertificate=True;"
Invoke-Sqlcmd -Query $createUserSql -ConnectionString $connectionString
Write-Host "SQL user '$SqlUser' ensured with permissions on $MainDb and $ReadModelDb."