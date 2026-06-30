
## ------
##!/bin/bash

## Function to retrieve remote hostname
#get_remote_hostname() {
#    local user=$1
#    local host=$2
#    echo "Retrieving hostname..."
#    hostname=$(ssh $user@$host "hostname")
#    if [ $? -ne 0 ]; then
#        echo "Failed to retrieve hostname."
#        exit 1
#    fi
#    echo "$hostname"
#}

## Function to sanitize hostname for filename
#sanitize_hostname() {
#    local hostname=$1
#    # Replace invalid characters with underscore
#    sanitized=$(echo "$hostname" | tr '/' '_' | tr ':' '_')
#    echo "$sanitized"
#}

## Main script execution
#echo "Script starting..."

## Check arguments
#if [ $# -ne 2 ]; then
#    echo "Usage: $0 username remote_host"
#    exit 1
#fi

#username=$1
#remote_host=$2

## Retrieve hostname
#hostname=$(get_remote_hostname "$username" "$remote_host")

## Sanitize hostname for key name
#sanitized_hostname=$(sanitize_hostname "$hostname")

## Suggest a key name
#suggested_key_name="ssh-key-$sanitized_hostname"

## Allow user to edit the key name
#read -p "Enter key name (press Enter to use suggestion: $suggested_key_name): " key_name
#if [ -z "$key_name" ]; then
#    key_name="$suggested_key_name"
#fi

## Check for existing key with the same name
#if [ -f ~/.ssh/"$key_name" ]; then
#    read -p "Key file exists. Overwrite? (y/n): " overwrite
#    if [ "$overwrite" = "n" ]; then
#        # Generate a new unique key name
#        key_name="ssh-key-$sanitized_hostname-$(date +%s)"
#    fi
#fi

## Generate SSH keys with custom name
#echo "Generating SSH keys..."
#ssh-keygen -t rsa -f ~/.ssh/"$key_name" -N ""

#if [ $? -ne 0 ]; then
#    echo "Failed to generate SSH keys."
#    exit 1
#fi

## Copy public key to remote server
#echo "Copying public key to remote host..."
#yes | sshpass -p "your_password_here" ssh-copy-id -i ~/.ssh/"$key_name".pub "$username@$remote_host"

#if [ $? -ne 0 ]; then
#    echo "Failed to copy public key."
#    exit 1
#fi

#echo "SSH keys generated and copied successfully."

## ------
##!/bin/bash

## Function to test initial connection
#test_connection() {
#    echo "Testing connection..."
#    sshpass -p "$PASSWORD" ssh $USER@$HOST exit
#    if [ $? -ne 0 ]; then
#        echo "Connection failed. Please check your credentials and network."
#        exit 1
#    fi
#}

## Function to generate SSH key pair
#generate_ssh_key() {
#    echo "Generating SSH key..."
#    mkdir -p ~/.ssh
#    ssh-keygen -t rsa -f ~/.ssh/id_rsa -N ""
#    if [ $? -ne 0 ]; then
#        echo "Failed to generate SSH key."
#        exit 1
#    fi
#}

## Function to copy public key to remote server
#copy_public_key() {
#    echo "Copying public key to $USER@$HOST..."
#    sshpass -p "$PASSWORD" ssh-copy-id -i ~/.ssh/id_rsa.pub $USER@$HOST
#    if [ $? -ne 0 ]; then
#        echo "Failed to copy public key."
#        exit 1
#    fi
#}

## Main script execution
#echo "Script starting..."

## Check arguments
#if [ $# -ne 1 ]; then
#    echo "Usage: $0 user@host"
#    exit 1
#fi

#USERHOST=$1
#USER=$(echo "$USERHOST" | cut -d'@' -f1)
#HOST=$(echo "$USERHOST" | cut -d'@' -f2)

## Prompt for password
#read -s -p "Enter your password: " PASSWORD

#test_connection

#generate_ssh_key

#copy_public_key

#echo "SSH key setup completed successfully."

## ------
##!/bin/bash
## Check if user@host is provided as an argument
#if [ "$#" -ne 1 ]; then
#    echo "Usage: $0 user@host"
#    exit 1
#fi

#USER_HOST="$1"
#USER="${USER_HOST%@*}"
#HOST="${USER_HOST#*@}"

## Prompt for password
#read -s -p "Enter password for $USER@$HOST: " PASSWORD
#echo

## Function to handle SSH commands with error checking
#function ssh_check {
#    local command=$@
#    echo -n "Running: $command..."
#    if ! sshpass -p "$PASSWORD" $command 2>/dev/null; then
#        echo " failed"
#        exit 1
#    fi
#    echo " succeeded"
#}

## Step 0: Verify initial connection to the remote server
#ssh_check "ssh -o StrictHostKeyChecking=no $USER@$HOST 'echo test'"

## Step 1: Generate a new SSH key locally using Ed25519
#SUGGESTED_KEY_NAME="id_ed25519_${HOST//./_}"
#read -p "Suggested key name is '$SUGGESTED_KEY_NAME'. Enter custom name or press Enter to use suggested name: " CUSTOM_KEY_NAME
#KEY_NAME="${CUSTOM_KEY_NAME:-$SUGGESTED_KEY_NAME}"
#SSH_DIR="$HOME/.ssh"
#mkdir -p "$SSH_DIR"

#echo "Generating new SSH key..."
#ssh-keygen -t ed25519 -f "$SSH_DIR/$KEY_NAME" -N "" -q

## Step 2: Copy the public key to the remote server
#echo "Copying the public key to the remote server..."
#ssh_check "ssh-copy-id -i $SSH_DIR/${KEY_NAME}.pub $USER@$HOST"

## Step 3: Verify the SSH key was copied successfully
#ssh_check "ssh -o StrictHostKeyChecking=no $USER@$HOST 'ls -l ~/.ssh/$KEY_NAME.pub'"

#echo "All steps completed successfully!"

##!/bin/bash

## Check if user@host is provided as an argument
#if [ "$#" -ne 1 ]; then
#    echo "Usage: $0 user@host"
#    exit 1
#fi

## Extract user and host from the argument
#USER_HOST="$1"
#USER="${USER_HOST%@*}"
#HOST="${USER_HOST#*@}"

## Prompt for password
#read -s -p "Enter password for $USER@$HOST: " PASSWORD
#echo

## Attempt SSH connection with specified options
#error_output=$(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$USER@$HOST" 2>&1)

## Check if authentication failed due to wrong password
#if [[ $error_output == *"Authentication failed"* ]]; then
#    echo "Authentication failed: Incorrect password."
#    exit 2
#elif [[ $error_output == *"Connection timed out"* ]]; then
#    echo "Connection timed out. Please check the remote host's availability."
#    exit 3
#else
#    # Handle other possible errors or successful connection
#    if [ $? -ne 0 ]; then
#        echo "An error occurred: $error_output"
#        exit 1
#    fi
#fi

## # Proceed with the script only if connection was successful
## echo "Successfully connected!"
## # Attempt to connect to the remote server to verify credentials
## # Using a more specific test command and capturing the exit status
## echo "Verifying credentials..."
## if ! sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$USER@$HOST" "true" 2>/dev/null; then
##     echo "Error: Authentication failed or unable to connect to $USER@$HOST."
##     echo "Please verify your credentials and network connection."
##     exit 1
## fi

## If we reach here, credentials are valid
## Suggest a key name based on the hostname
#SUGGESTED_KEY_NAME="id_ed25519_${HOST//./_}"  # Replace dots with underscores
#read -p "Suggested key name is '$SUGGESTED_KEY_NAME'. Enter custom name or press Enter to use suggested name: " CUSTOM_KEY_NAME

## Use the custom name if provided, otherwise use the suggested name
#KEY_NAME="${CUSTOM_KEY_NAME:-$SUGGESTED_KEY_NAME}"
#SSH_DIR="$HOME/.ssh"
#SSH_KEY_PATH="$SSH_DIR/$KEY_NAME"

## Step 1: Generate a new SSH key locally using Ed25519
#echo "Generating new SSH key..."
#ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -q

## Step 2: Copy the public key to the remote server
#echo "Copying the public key to the remote server..."
#if ! sshpass -p "$PASSWORD" ssh-copy-id -i "$SSH_KEY_PATH.pub" "$USER@$HOST" 2>/dev/null; then
#    echo "Error: Failed to copy SSH key to remote server"
#    exit 1
#fi

## Step 3: Verify the setup
#echo "Verifying SSH key authentication..."
#if ! ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$USER@$HOST" "true" 2>/dev/null; then
#    echo "Error: SSH key authentication setup failed"
#    exit 1
#fi

#echo "SSH key setup complete. Key stored at: $SSH_KEY_PATH"
#echo "You can now connect using: ssh -i $SSH_KEY_PATH $USER@$HOST"
