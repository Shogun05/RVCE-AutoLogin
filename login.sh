#!/bin/bash

# Help function to display usage information
show_help() {
  echo "Usage: $0 [-u <username>] [-p <password>]"
  echo "Network login script for RVCE network"
  echo ""
  echo "Options:"
  echo "  -u <username>    Specify the username for login"
  echo "  -p <password>    Specify the password for login"
  echo "  -h               Display this help message and exit"
  echo ""
  echo "If username and password are not provided, the script will try to use"
  echo "credentials stored in the .credentials file from previous logins."
  exit 1
}

# Set credentials file path
CREDENTIALS_FILE="$HOME/.credentials"

# Initialize variables
username=""
password=""

# Parse command line arguments - do this only once
while getopts "u:p:h" opt; do
  case $opt in
    u)
      username="$OPTARG"
      ;;
    p)
      password="$OPTARG"
      ;;
    h|*)
      show_help
      ;;
  esac
done

# Check if username and password are provided in command line arguments
if [ -n "$username" ] && [ -n "$password" ]; then
  # Save credentials to file with restricted permissions
  echo "$username" > "$CREDENTIALS_FILE"
  echo "$password" >> "$CREDENTIALS_FILE"
  chmod 600 "$CREDENTIALS_FILE"
  echo "Credentials saved to $CREDENTIALS_FILE" >> "$HOME/my_script.log"
else
  # Try to read from credentials file if it exists
  if [ -f "$CREDENTIALS_FILE" ]; then
    echo "Reading credentials from $CREDENTIALS_FILE" >> "$HOME/my_script.log"
    username=$(sed -n '1p' "$CREDENTIALS_FILE")
    password=$(sed -n '2p' "$CREDENTIALS_FILE")
  else
    echo "Error: Username and password not provided and no stored credentials found." >> "$HOME/my_script.log"
    show_help
  fi
fi

# Verify we have credentials before proceeding
if [ -z "$username" ] || [ -z "$password" ]; then
  echo "Error: Could not obtain valid credentials." >> "$HOME/my_script.log"
  exit 1
fi

# Main loop to keep checking and maintaining network connection
while true; do
  echo "$(date): Checking network connection..." >> "$HOME/my_script.log"
  
  # Send a GET request to http://rvce.edu.in using curl and extract URLs from the response
  response=$(curl -s -X GET "http://rvce.edu.in")

  # Check if the response contains "302 Found" title, which indicates already connected
  if echo "$response" | grep -q "<title>302 Found</title>"; then
    echo "$(date): You are already connected to the network." >> "$HOME/my_script.log"
    sleep 2400
    continue
  fi

  echo "$(date): Connection needed, attempting to log in..." >> "$HOME/my_script.log"

  # Extract the full URL from the response
  link=$(echo "$response" | grep -oP 'window.location="\K[^"]+')

  # Extract the token after the question mark from the fgtauth URL
  token=$(echo "$response" | grep -oP 'fgtauth\?\K[a-zA-Z0-9=_-]+')
  echo "Link: $link" >> "$HOME/my_script.log"
  echo "Token: $token" >> "$HOME/my_script.log"

  # Make a request to the extracted link
  subresponse=$(curl -s -L -k "$link")
  echo "$subresponse" >> "$HOME/my_script.log"

  # Extract 4Tredir value from the subresponse
  redir_value=$(echo "$subresponse" | grep -oP '<input type="hidden" name="4Tredir" value="\K[^"]+')
  echo "4Tredir value: $redir_value" >> "$HOME/my_script.log"

  # Extract magic value from the subresponse
  magic_value=$(echo "$subresponse" | grep -oP '<input type="hidden" name="magic" value="\K[^"]+')
  echo "Magic value: $magic_value" >> "$HOME/my_script.log"

  curl -k -X POST \
    -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8" \
    -H "Accept-Encoding: gzip, deflate, br, zstd" \
    -H "Accept-Language: en-US,en;q=0.7" \
    -H "Cache-Control: max-age=0" \
    -H "Connection: keep-alive" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -H "Host: 172.16.0.2:1003" \
    -H "Origin: https://172.16.0.2:1003" \
    -H "Referer: $link" \
    -H "Sec-Fetch-Dest: document" \
    -H "Sec-Fetch-Mode: navigate" \
    -H "Sec-Fetch-Site: same-origin" \
    -H "Sec-Fetch-User: ?1" \
    -H "Sec-GPC: 1" \
    -H "Upgrade-Insecure-Requests: 1" \
    -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36" \
    -H "sec-ch-ua: \"Brave\";v=\"135\", \"Not-A.Brand\";v=\"8\", \"Chromium\";v=\"135\"" \
    -H "sec-ch-ua-mobile: ?0" \
    -H "sec-ch-ua-platform: \"Linux\"" \
    -d "4Tredir=$redir_value" \
    -d "magic=$magic_value" \
    -d "username=$username" \
    -d "password=$password" \
    -L \
    https://172.16.0.2:1003/ >> "$HOME/my_script.log"
    
  echo "$(date): Login attempt completed, sleeping for 40 minutes..." >> "$HOME/my_script.log"
  sleep 2400
done

