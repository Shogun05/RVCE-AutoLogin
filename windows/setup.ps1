# Copy login.ps1 to the user's home directory
Copy-Item -Path .\login.ps1 -Destination $HOME\login.ps1

# Check if login.ps1 exists in home directory
if (-not (Test-Path "$HOME\login.ps1")) {
    Write-Host "Error: login.ps1 not found in your home directory."
    Write-Host "Please run the following command and then retry this script:"
    Write-Host "Copy-Item -Path .\login.ps1 -Destination $HOME\login.ps1"
    exit 1
}

# Script continues if login.ps1 exists
Write-Host "Found login.ps1 in home directory. Proceeding with setup..."

$CREDENTIALS_FILE = "$env:LOCALAPPDATA\RVCE_AutoLogin\credentials"

# Check if credentials file already exists
if (Test-Path "$CREDENTIALS_FILE") {
    Write-Host "Credentials file already exists in $env:LOCALAPPDATA\RVCE_AutoLogin\credentials"
    Write-Host "Using existing credentials..."
}
else {
    # Prompt for credentials and store them
    Write-Host "Please enter your network login credentials:"
    $username = Read-Host -Prompt "Username"
    $password = Read-Host -Prompt "Password" -AsSecureString
    
    # Convert secure string to plain text for storage
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

    # Create .credentials file with username and password
    $username | Out-File -FilePath "$CREDENTIALS_FILE"
    $plainPassword | Out-File -Append -FilePath "$CREDENTIALS_FILE"
}

# Secure the file by restricting permissions (only owner can access)
$acl = Get-Acl "$CREDENTIALS_FILE"
$acl.SetAccessRuleProtection($true, $false)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($env:USERNAME,"FullControl","Allow")
$acl.SetAccessRule($rule)
Set-Acl "$CREDENTIALS_FILE" $acl
Write-Host "Credentials stored in $CREDENTIALS_FILE"

# Add login script to Windows startup (equivalent to crontab @reboot)
$startupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$shortcutPath = "$startupFolder\RVCENetworkLogin.lnk"

if (-not (Test-Path $shortcutPath)) {
    # Create a shortcut to run the script at startup
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($shortcutPath)
    $Shortcut.TargetPath = "powershell.exe"
    $Shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File $HOME\login.ps1"
    $Shortcut.Save()
    Write-Host "Added startup shortcut to run the login script."
}
else {
    Write-Host "Startup shortcut already exists."
}

# Create a scheduled task as an alternative startup method
$taskName = "RVCENetworkLogin"
$taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if (-not $taskExists) {
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File $HOME\login.ps1"
    $trigger = New-ScheduledTaskTrigger -AtLogon
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "RVCE Network Auto Login" -RunLevel Highest
    Write-Host "Created scheduled task to run the login script at logon."
}
else {
    Write-Host "Scheduled task already exists."
}

Write-Host "Setup complete. The login script will run automatically at system startup."
# Wait for user input before closing
Write-Host "`nPress any key to close this window..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
