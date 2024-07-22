#!/bin/bash

# Define variables
RPI_USER="peter"         # Raspberry Pi username
RPI_HOST="42.115.159.217"  # Raspberry Pi IP address (port 22 is default for SSH)
RPI_PATH="/home/peter/telegram-idle-bot/"  # Path on Raspberry Pi to deploy the project
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
tar czf project.tar.gz -C "$LOCAL_PATH" . --exclude='*.git' --exclude='.env' --exclude='*.session' --exclude='*.session-journal'

# Copy the tarball to the Raspberry Pi
echo "Copying tarball to Raspberry Pi..."
scp project.tar.gz $RPI_USER@$RPI_HOST:$RPI_PATH

# Check if the tarball was successfully copied
if [ $? -ne 0 ]; then
    echo "Error: Failed to copy tarball to Raspberry Pi."
    exit 1
fi

# Connect to Raspberry Pi and deploy
echo "Deploying on Raspberry Pi..."
ssh $RPI_USER@$RPI_HOST << EOF
    # Create deployment directory if it doesn't exist
    mkdir -p $RPI_PATH
    cd $RPI_PATH

    # Extract the tarball and clean up
    if [ -f project.tar.gz ]; then
        tar xzf project.tar.gz
        rm project.tar.gz
    else
        echo "Error: Tarball not found."
        exit 1
    fi

    # Update package list and install Node.js and npm if not installed
    if ! command -v node &> /dev/null
    then
        echo "Node.js not found, installing..."
        curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi

    # Install PM2 globally if not installed
    if ! command -v pm2 &> /dev/null
    then
        echo "PM2 not found, installing..."
        sudo npm install -g pm2
    fi

    # Install Python dependencies in a virtual environment
    if ! command -v python3 &> /dev/null
    then
        echo "python3 not found, installing..."
        sudo apt update
        sudo apt install -y python3 python3-pip
    fi

    # Create and activate a virtual environment
    python3 -m venv venv
    source venv/bin/activate

    # Install Python dependencies
    pip install -r requirements.txt

    # Start the Python script using PM2
    pm2 start bot.py --name telegram-idle-bot --interpreter python3

    # Save PM2 process list and set up PM2 to restart on reboot
    pm2 save
    pm2 startup

    # Enable PM2 service to start on boot
    sudo pm2 startup systemd -u $RPI_USER --hp /home/$RPI_USER

    # Optional: Check PM2 status
    pm2 ls
EOF

# Clean up
echo "Cleaning up local tarball..."
rm project.tar.gz

echo "Deployment completed!"
