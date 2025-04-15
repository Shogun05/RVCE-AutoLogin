#!/bin/bash

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

# Detect Linux distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    DISTRO=$DISTRIB_ID
elif [ -f /etc/debian_version ]; then
    DISTRO="debian"
elif [ -f /etc/redhat-release ]; then
    DISTRO="redhat"
else
    DISTRO="unknown"
fi

# Convert to lowercase
DISTRO=$(echo "$DISTRO" | tr '[:upper:]' '[:lower:]')

echo "Detected distribution: $DISTRO"

# Check if crontab command exists
if command -v crontab &> /dev/null; then
    echo "Cron is already installed."
else
    echo "Cron is not installed. Attempting to install..."
    
    # Check for root/sudo permissions
    if [ "$(id -u)" -ne 0 ] && ! sudo -n true 2>/dev/null; then
        echo "Error: This script needs sudo privileges to install packages. Please run with sudo."
        exit 1
    fi
    
    # Install crontab based on distribution
    if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" || "$DISTRO" == "linuxmint" ]]; then
        echo "Installing cron on Debian-based system..."
        sudo apt-get update || { echo "Error: Failed to update package lists"; exit 1; }
        sudo apt-get install -y cron || { echo "Error: Failed to install cron package"; exit 1; }
        sudo systemctl enable cron || { echo "Error: Failed to enable cron service"; exit 1; }
        sudo systemctl start cron || { echo "Error: Failed to start cron service"; exit 1; }
    elif [[ "$DISTRO" == "fedora" || "$DISTRO" == "centos" || "$DISTRO" == "rhel" || "$DISTRO" == "redhat" ]]; then
        echo "Installing cron on Red Hat-based system..."
        sudo yum install -y cronie || { echo "Error: Failed to install cronie package"; exit 1; }
        sudo systemctl enable crond || { echo "Error: Failed to enable crond service"; exit 1; }
        sudo systemctl start crond || { echo "Error: Failed to start crond service"; exit 1; }
    elif [[ "$DISTRO" == "arch" || "$DISTRO" == "manjaro" ]]; then
        echo "Installing cron on Arch-based system..."
        sudo pacman -S --noconfirm cronie || { echo "Error: Failed to install cronie package"; exit 1; }
        sudo systemctl enable cronie || { echo "Error: Failed to enable cronie service"; exit 1; }
        sudo systemctl start cronie || { echo "Error: Failed to start cronie service"; exit 1; }
    elif [[ "$DISTRO" == "opensuse" || "$DISTRO" == "suse" ]]; then
        echo "Installing cron on SUSE-based system..."
        sudo zypper install -y cron || { echo "Error: Failed to install cron package"; exit 1; }
        sudo systemctl enable cron || { echo "Error: Failed to enable cron service"; exit 1; }
        sudo systemctl start cron || { echo "Error: Failed to start cron service"; exit 1; }
    else
        echo "Error: Unknown distribution '$DISTRO'. Please install crontab manually."
        exit 1
    fi
    
    # Verify crontab is now available
    if ! command -v crontab &> /dev/null; then
        echo "Error: Installation appeared to succeed but crontab command is still not available"
        exit 1
    fi
fi

# Add login script to crontab to run at reboot
if ! crontab -l 2>/dev/null | grep -Fq "@reboot /bin/bash $HOME/login.sh &"; then
    (crontab -l 2>/dev/null; echo "@reboot /bin/bash $HOME/login.sh &") | crontab -
    echo "Added @reboot entry to crontab."
else
    echo "Crontab entry already exists."
fi
