#!/bin/bash

# Define variables
RPI_USER="peterpi"         # Raspberry Pi username
RPI_HOST="42.115.159.217"  # Raspberry Pi IP address (port 22 is default for SSH)
RPI_PATH="/home/peterpi/GitHub/telegram-idle-bot"  # Path on Raspberry Pi to deploy the project
LOCAL_PATH=$(pwd)         # Current directory (assuming deploy.sh is in the project root)

# Build the project (if necessary)
# For Python, this might involve creating a virtual environment and installing dependencies
echo "Setting up the Python environment..."
# Uncomment and modify the following lines if you use a virtual environment
# python3 -m venv venv
# source venv/bin/activate
# pip install -r requirements.txt

# Create a tarball of the project excluding sensitive files
echo "Creating tarball of the project..."
tar czf project.tar.gz -C "$LOCAL_PATH" . --exclude="*.git" --exclude=".env" --exclude="*.session" --exclude="*.session-journal"

# Copy the tarball to the Raspberry Pi
echo "Copying tarball to Raspberry Pi..."
scp project.tar.gz $RPI_USER@$RPI_HOST:$RPI_PATH

# Connect to Raspberry Pi and deploy
echo "Deploying on Raspberry Pi..."
ssh $RPI_USER@$RPI_HOST << EOF
    cd $RPI_PATH
    tar xzf project.tar.gz
    rm project.tar.gz
    
    # Create or activate a virtual environment
    python3 -m venv venv
    source venv/bin/activate
    
    # Install dependencies
    pip install -r requirements.txt

    # Install pm2 if not already installed
    if ! command -v pm2 &> /dev/null
    then
        echo "pm2 not found, installing..."
        npm install -g pm2
    fi

    # Start the Python script using pm2
    pm2 start bot.py --name telegram-idle-bot --interpreter python3

    # Save pm2 process list and set up pm2 to restart on reboot
    pm2 save
    pm2 startup
EOF

# Clean up
echo "Cleaning up local tarball..."
rm project.tar.gz

echo "Deployment completed!"
