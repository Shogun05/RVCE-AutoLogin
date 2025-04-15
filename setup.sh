#!/bin/bash

cp ./login.sh $HOME/login.sh

# Check if login.sh exists in $HOME
if [ ! -f "$HOME/login.sh" ]; then
    echo "Error: login.sh not found in your home directory."
    echo "Please run the following command and then retry this script:"
    echo "cp ./login.sh $HOME/login.sh"
    exit 1
fi

# Script continues if login.sh exists
echo "Found login.sh in home directory. Proceeding with setup..."
chmod +x $HOME/login.sh

# Prompt for credentials and store them
echo "Please enter your network login credentials:"
read -p "Username: " username
read -sp "Password: " password
echo

# Create .credentials file with username and password
echo "$username" > "$HOME/.credentials"
echo "$password" >> "$HOME/.credentials"

# Secure the file by restricting permissions (only owner can read/write)
chmod 600 "$HOME/.credentials"
echo "Credentials stored in $HOME/.credentials"
# Add login script to crontab to run at reboot
if ! crontab -l 2>/dev/null | grep -Fq "@reboot /bin/bash $HOME/login.sh &"; then
    (crontab -l 2>/dev/null; echo "@reboot /bin/bash $HOME/login.sh &") | crontab -
    echo "Added @reboot entry to crontab."
else
    echo "Crontab entry already exists."
fi
