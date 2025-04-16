# Network Login Script for RVCE network (Windows version)

param (
    [string]$u = "",
    [string]$p = "",
    [switch]$h = $false
)

# Help function to display usage information
function Show-Help {
    Write-Host "Usage: .\login.ps1 -u <username> -p <password>"
    Write-Host "Network login script for RVCE network"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -u <username>    Specify the username for login"
    Write-Host "  -p <password>    Specify the password for login"
    Write-Host "  -h               Display this help message and exit"
    Write-Host ""
    Write-Host "If username and password are not provided, the script will try to use"
    Write-Host "credentials stored in the .credentials file from previous logins."
    exit 1
}

# Show help if requested
if ($h) {
    Show-Help
}

# Set credentials file path
# Set credentials file path in AppData\Local
$APP_DIR = "$env:LOCALAPPDATA\RVCE_AutoLogin"
# Create directory if it doesn't exist
if (!(Test-Path -Path $APP_DIR)) {
    New-Item -ItemType Directory -Path $APP_DIR | Out-Null
}
$CREDENTIALS_FILE = "$APP_DIR\credentials"
$LOG_FILE = "$APP_DIR\AutoLogin.log"

# Initialize variables
$username = $u
$password = $p

# Function to log messages
function Log-Message {
    param([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp: $message" | Out-File -Append -FilePath $LOG_FILE
}

# Check if username and password are provided in command line arguments
if ($username -and $password) {
    # Save credentials to file with restricted permissions
    $username | Out-File -FilePath $CREDENTIALS_FILE
    $password | Out-File -Append -FilePath $CREDENTIALS_FILE
    $acl = Get-Acl $CREDENTIALS_FILE
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($env:USERNAME,"FullControl","Allow")
    $acl.SetAccessRule($rule)
    Set-Acl $CREDENTIALS_FILE $acl
    Log-Message "Credentials saved to $CREDENTIALS_FILE"
}
else {
    # Try to read from credentials file if it exists
    if (Test-Path $CREDENTIALS_FILE) {
        Log-Message "Reading credentials from $CREDENTIALS_FILE"
        $credentials = Get-Content $CREDENTIALS_FILE
        $username = $credentials[0]
        $password = $credentials[1]
    }
    else {
        Log-Message "Error: Username and password not provided and no stored credentials found."
        Show-Help
    }
}

# Verify we have credentials before proceeding
if (-not $username -or -not $password) {
    Log-Message "Error: Could not obtain valid credentials."
    exit 1
}

# Main loop to keep checking and maintaining network connection
while ($true) {
    Log-Message "Checking network connection..."
    
    try {
        # Make web request with error handling
        $response = Invoke-WebRequest -Uri "http://rvce.edu.in" -UseBasicParsing -ErrorAction SilentlyContinue
        $responseContent = $response.Content

        # Check if already connected
        if ($responseContent -match "<title>302 Found</title>") {
            Log-Message "You are already connected to the network."
            Start-Sleep -Seconds 2400
            continue
        }

        Log-Message "Connection needed, attempting to log in..."

        # Extract the full URL from the response
        if ($responseContent -match 'window.location="([^"]+)"') {
            $link = $matches[1]
            Log-Message "Link: $link"
        } else {
            Log-Message "Could not extract link from response."
            Start-Sleep -Seconds 300
            continue
        }

        # Extract the token from the fgtauth URL
        if ($responseContent -match 'fgtauth\?([a-zA-Z0-9=_-]+)') {
            $token = $matches[1]
            Log-Message "Token: $token"
        } else {
            Log-Message "Could not extract token from response."
        }

        # Make a request to the extracted link
        $subresponse = Invoke-WebRequest -Uri $link -UseBasicParsing -SkipCertificateCheck
        $subresponseContent = $subresponse.Content
        Log-Message $subresponseContent

        # Extract 4Tredir value from the subresponse
        if ($subresponseContent -match '<input type="hidden" name="4Tredir" value="([^"]+)"') {
            $redir_value = $matches[1]
            Log-Message "4Tredir value: $redir_value"
        } else {
            Log-Message "Could not extract 4Tredir value."
        }

        # Extract magic value from the subresponse
        if ($subresponseContent -match '<input type="hidden" name="magic" value="([^"]+)"') {
            $magic_value = $matches[1]
            Log-Message "Magic value: $magic_value"
        } else {
            Log-Message "Could not extract magic value."
        }

        # Set up headers for the login request
        $headers = @{
            "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8"
            "Accept-Encoding" = "gzip, deflate, br"
            "Accept-Language" = "en-US,en;q=0.7"
            "Cache-Control" = "max-age=0"
            "Connection" = "keep-alive"
            "Content-Type" = "application/x-www-form-urlencoded"
            "Host" = "172.16.0.2:1003"
            "Origin" = "https://172.16.0.2:1003"
            "Referer" = "$link"
            "Sec-Fetch-Dest" = "document"
            "Sec-Fetch-Mode" = "navigate"
            "Sec-Fetch-Site" = "same-origin"
            "Sec-Fetch-User" = "?1"
            "Upgrade-Insecure-Requests" = "1"
            "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36"
        }

        # Set up body for the login request
        $body = @{
            "4Tredir" = "$redir_value"
            "magic" = "$magic_value"
            "username" = "$username"
            "password" = "$password"
        }

        # Make login request
        $loginResponse = Invoke-WebRequest -Uri "https://172.16.0.2:1003/" -Method Post -Headers $headers -Body $body -SkipCertificateCheck -UseBasicParsing
        Log-Message "Login response status: $($loginResponse.StatusCode)"

        Log-Message "Login attempt completed, sleeping for 40 minutes..."
    }
    catch {
        Log-Message "Error occurred: $_"
    }
    
    # Sleep for 40 minutes (2400 seconds) before checking again
    Start-Sleep -Seconds 2400
}
