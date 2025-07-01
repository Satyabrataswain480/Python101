param(
    [string]$ComputerName,
    [string]$Username,
    [string]$Password
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)
New-PSSession -ComputerName $ComputerName -Credential $credential -UseSSL