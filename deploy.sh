#!/bin/bash

# Define variables
LOCAL_PATH=$(pwd)                          # Current directory (assuming deploy.sh is in the project root)
PROJECT_NAME=$(basename "$LOCAL_PATH")     # Extract project name from the root folder name
RPI_USER="peter"                          # Raspberry Pi username
RPI_HOST="peterpi.local"                  # Raspberry Pi hostname or IP address
RPI_PATH="/home/peter/$PROJECT_NAME/"     # Path on Raspberry Pi to deploy the project

# Create a tarball of the project, excluding sensitive files
echo "Creating tarball of the project..."
tar czf project.tar.gz --exclude='.git' --exclude='.gitignore' --exclude='venv' --exclude='deploy.sh' -C "$LOCAL_PATH" .

# Check if tarball was created successfully
if [ ! -f project.tar.gz ]; then
    echo "Error: Failed to create tarball."
    exit 1
fi

# Add Raspberry Pi host to known_hosts to avoid SSH host key verification issues
echo "Adding Raspberry Pi host to known_hosts..."
# ssh-keyscan -H $RPI_HOST >> ~/.ssh/known_hosts

# Ensure deployment directory exists on Raspberry Pi
echo "Ensuring deployment directory exists on Raspberry Pi..."
ssh $RPI_USER@$RPI_HOST "mkdir -p $RPI_PATH"

# Copy the tarball to the Raspberry Pi
echo "Copying tarball to Raspberry Pi..."
scp project.tar.gz $RPI_USER@$RPI_HOST:$RPI_PATH

# Check if SCP was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to copy tarball to Raspberry Pi."
    rm project.tar.gz
    exit 1
fi

# Verify that the tarball was copied successfully
echo "Verifying tarball presence on Raspberry Pi..."
ssh $RPI_USER@$RPI_HOST "ls -l $RPI_PATH/project.tar.gz"

# Connect to Raspberry Pi to perform the extraction and setup
echo "Connecting to Raspberry Pi to perform setup..."
ssh $RPI_USER@$RPI_HOST << EOF
    set -e  # Exit immediately if a command exits with a non-zero status

    echo "Checking if application is already running with PM2..."
    if pm2 describe $PROJECT_NAME &> /dev/null; then
        echo "Application is already running. Stopping it..."
        pm2 stop $PROJECT_NAME
    fi

    echo "Removing existing files in the deployment directory except for project.tar.gz..."
    find $RPI_PATH -mindepth 1 -maxdepth 1 ! -name 'project.tar.gz' -exec rm -rf {} +

    echo "Changing to the deployment directory..."
    cd $RPI_PATH || { echo "Failed to cd into $RPI_PATH"; exit 1; }

    echo "Listing files in the directory to verify tarball presence..."
    ls -l

    echo "Checking if project.tar.gz exists..."
    if [ -f project.tar.gz ]; then
        echo "project.tar.gz found. Proceeding with extraction..."
        
        echo "Extracting tarball..."
        tar xzf project.tar.gz
        rm project.tar.gz  # Remove the tarball after extraction
    else
        echo "Error: project.tar.gz not found."
        exit 1
    fi

    echo "Checking and installing Python if needed..."
    if ! command -v python3 &> /dev/null; then
        echo "Python3 not found, installing..."
        sudo apt update
        sudo apt install -y python3 python3-pip
    fi

    echo "Creating and activating virtual environment..."
    python3 -m venv venv
    source venv/bin/activate

    echo "Installing Python dependencies..."
    if [ -f requirements.txt ]; then
        pip install -r requirements.txt
    else
        echo "Error: requirements.txt not found."
        exit 1
    fi

    echo "Running build script if present..."
    if [ -f build.sh ]; then
        ./build.sh
    fi

    echo "Starting Python application with PM2..."
    pm2 start bot.py --name $PROJECT_NAME --interpreter python3

    echo "Saving PM2 process list and setting up PM2 to restart on reboot..."
    pm2 save
    pm2 startup systemd -u $RPI_USER --hp /home/$RPI_USER
    pm2 ls
EOF

# Clean up local tarball
echo "Cleaning up local tarball..."
rm project.tar.gz

echo "Deployment completed!"
