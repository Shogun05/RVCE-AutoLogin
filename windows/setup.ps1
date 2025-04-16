# Get all user profiles on the system
$userProfiles = Get-ChildItem -Path 'C:\Users' -Directory | Where-Object { 
    $_.Name -ne 'Public' -and $_.Name -ne 'Default' -and $_.Name -ne 'Default User' -and $_.Name -ne 'All Users'
}

if ($userProfiles.Count -eq 0) {
    Write-Host "No user profiles found." -ForegroundColor Red
    exit 1
}

# Display available users
Write-Host "Available users:" -ForegroundColor Cyan
for ($i = 0; $i -lt $userProfiles.Count; $i++) {
    Write-Host "[$i] $($userProfiles[$i].Name)"
}

# Ask which user to set up
$validSelection = $false
while (-not $validSelection) {
    $selection = Read-Host "Enter the number of the user to set up auto-login for"
    if ($selection -match '^\d+$' -and [int]$selection -ge 0 -and [int]$selection -lt $userProfiles.Count) {
        $validSelection = $true
    } else {
        Write-Host "Invalid selection. Please try again." -ForegroundColor Yellow
    }
}

# Get selected user profile
$selectedUser = $userProfiles[[int]$selection]
$userHomePath = $selectedUser.FullName
$userName = $selectedUser.Name

Write-Host "Setting up auto-login for user: $userName" -ForegroundColor Green

# Copy login.ps1 to the selected user's home directory
Copy-Item -Path "$PSScriptRoot\login.ps1" -Destination "$userHomePath\login.ps1" -Force
Write-Host "Copied login.ps1 to $userHomePath\login.ps1"


# Check if login.ps1 exists in home directory
if (-not (Test-Path "$userHomePath\login.ps1")) {
    Write-Host "Error: login.ps1 not found in your home directory."
    Write-Host "Please run the following command and then retry this script:"
    Write-Host "Copy-Item -Path $PSScriptRoot\login.ps1 -Destination $userHomePath\login.ps1"
    exit 1
}

# Script continues if login.ps1 exists
Write-Host "Found login.ps1 in home directory. Proceeding with setup..."

$CREDENTIALS_FILE = "$env:LOCALAPPDATA\RVCE_AutoLogin\credentials"

# Check if credentials file already exists
# Check if directory exists, create it if it doesn't
$credentialsDir = "$env:LOCALAPPDATA\RVCE_AutoLogin"
if (-not (Test-Path -Path $credentialsDir)) {
    try {
        New-Item -Path $credentialsDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
        Write-Host "Created directory: $credentialsDir"
    }
    catch {
        Write-Host "Error creating directory: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Verify directory exists before proceeding
if (-not (Test-Path -Path $credentialsDir)) {
    Write-Host "Failed to create or access directory: $credentialsDir" -ForegroundColor Red
    exit 1
}

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

    try {
        # Create .credentials file with username and password
        $username | Out-File -FilePath "$CREDENTIALS_FILE" -ErrorAction Stop
        $plainPassword | Out-File -Append -FilePath "$CREDENTIALS_FILE" -ErrorAction Stop
        
        # Secure the file by restricting permissions (only owner can access)
        $acl = Get-Acl "$CREDENTIALS_FILE" -ErrorAction Stop
        $acl.SetAccessRuleProtection($true, $false)
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($env:USERNAME,"FullControl","Allow")
        $acl.SetAccessRule($rule)
        Set-Acl "$CREDENTIALS_FILE" $acl -ErrorAction Stop
        Write-Host "Credentials stored in $CREDENTIALS_FILE"
    }
    catch {
        Write-Host "Error creating credentials file: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Function to check if running as administrator
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

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
    if (Test-Admin) {
        try {
            $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File $userHomePath\login.ps1"
            $trigger = New-ScheduledTaskTrigger -AtLogon
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
            Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "RVCE Network Auto Login" -RunLevel Highest -ErrorAction Stop
            Write-Host "Created scheduled task to run the login script at logon."
        }
        catch {
            Write-Host "Failed to create scheduled task: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "The startup shortcut will still work for auto-login functionality." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "Administrator privileges required to create scheduled task." -ForegroundColor Yellow
        Write-Host "To add the scheduled task, please run this script as Administrator." -ForegroundColor Yellow
        Write-Host "However, the startup shortcut has been created and should work for auto-login." -ForegroundColor Yellow
    }
}
else {
    Write-Host "Scheduled task already exists."
}

Write-Host "Setup complete. The login script will run automatically at system startup."
# Wait for user input before closing
Write-Host "`nPress any key to close this window..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
