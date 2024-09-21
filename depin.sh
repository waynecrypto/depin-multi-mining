#!/bin/bash

# Function for basic installation (Selection 1)
basic_installation() {
    # Update system package list
    sudo apt update

    # Install prerequisites for NVM
    sudo apt install curl -y

    # Install NVM (Node Version Manager)
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash

    # Load NVM into the current shell session
    export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

    # Install Node.js version 16 using NVM
    nvm install 16

    # Install PM2 globally
    npm install pm2@latest -g

    # Set up PM2 to auto-start on system startup
    pm2 startup systemd -u $USER --hp $HOME
    sudo env PATH=$PATH:/home/$USER/.nvm/versions/node/$(nvm version)/bin pm2 startup systemd -u $USER --hp $HOME

    # Install Docker dependencies
    sudo apt install apt-transport-https ca-certificates curl software-properties-common -y

    # Add Docker’s official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # Set up the stable Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Update the package database again
    sudo apt update

    # Install Docker
    sudo apt install docker-ce docker-ce-cli containerd.io -y

    # Enable Docker service to start on boot
    sudo systemctl enable docker

    # Prompt the user for the PingPong device ID
    read -p "PingPong device ID: " device_id

    # Create a JSON file with the device ID
    cat <<EOF > secrets.json
{
  "pingpong_device_id": "$device_id"
}
EOF

    # Install jq for parsing JSON
    sudo apt install jq -y

    # Read the pingpong_device_id from secrets.json
    pingpong_device_id=$(jq -r '.pingpong_device_id' secrets.json)

    # Download the PINGPONG executable
    wget -O PINGPONG https://pingpong-build.s3.ap-southeast-1.amazonaws.com/linux/latest/PINGPONG

    # Make it executable
    chmod +x ./PINGPONG

    # Start PINGPONG using PM2 with the device ID
    pm2 start ./PINGPONG --name PINGPONG -- --key "$pingpong_device_id"

    # Save the PM2 process list and corresponding environments
    pm2 save
    source ~/.bashrc

    # Print completion message
    echo "Installation complete! NVM, Node.js 16, PM2, and Docker have been installed."
    echo "PINGPONG is now running under PM2 with auto-restart on reboot or crash."
}

# Function for turning on/restarting Blockmesh (Selection 2)
turn_on_blockmesh() {
    # Prompt the user for Blockmesh email and password
    read -p "Blockmesh Email: " blockmesh_email
    read -s -p "Blockmesh Password: " blockmesh_password
    echo

    # Update secrets.json with Blockmesh credentials
    jq --arg email "$blockmesh_email" --arg pwd "$blockmesh_password" '. + {blockmesh_email: $email, blockmesh_pwd: $pwd}' secrets.json > temp.json && mv temp.json secrets.json

    # Read credentials from secrets.json
    blockmesh_email=$(jq -r '.blockmesh_email' secrets.json)
    blockmesh_pwd=$(jq -r '.blockmesh_pwd' secrets.json)

    # Configure PINGPONG with Blockmesh credentials
    ./PINGPONG config set --blockmesh.email="$blockmesh_email" --blockmesh.pwd="$blockmesh_pwd"

    # Restart Blockmesh dependency
    ./PINGPONG stop --depins=blockmesh
    ./PINGPONG start --depins=blockmesh

    echo "Blockmesh has been configured and restarted."
}

# Function for turning on/restarting Dawn (Selection 3)
turn_on_dawn() {
    # Prompt the user for Dawn email and password
    read -p "Dawn Email: " dawn_email
    read -s -p "Dawn Password: " dawn_password
    echo

    # Update secrets.json with Dawn credentials
    jq --arg email "$dawn_email" --arg pwd "$dawn_password" '. + {dawn_email: $email, dawn_pwd: $pwd}' secrets.json > temp.json && mv temp.json secrets.json

    # Read credentials from secrets.json
    dawn_email=$(jq -r '.dawn_email' secrets.json)
    dawn_pwd=$(jq -r '.dawn_pwd' secrets.json)

    # Configure PINGPONG with Dawn credentials
    ./PINGPONG config set --dawn.email="$dawn_email" --dawn.pwd="$dawn_pwd"

    # Restart Dawn dependency
    ./PINGPONG stop --depins=dawn
    ./PINGPONG start --depins=dawn

    echo "Dawn has been configured and restarted."
}

# Function for turning on/restarting Grass (Selection 4)
turn_on_grass() {
    # Prompt the user for Grass access and refresh tokens
    read -p "Grass Access Token: " grass_access
    read -p "Grass Refresh Token: " grass_refresh

    # Update secrets.json with Grass tokens
    jq --arg access "$grass_access" --arg refresh "$grass_refresh" '. + {grass_access: $access, grass_refresh: $refresh}' secrets.json > temp.json && mv temp.json secrets.json

    # Read tokens from secrets.json
    grass_access=$(jq -r '.grass_access' secrets.json)
    grass_refresh=$(jq -r '.grass_refresh' secrets.json)

    # Configure PINGPONG with Grass tokens
    ./PINGPONG config set --grass.access="$grass_access" --grass.refresh="$grass_refresh"

    # Restart Grass dependency
    ./PINGPONG stop --depins=grass
    ./PINGPONG start --depins=grass

    echo "Grass has been configured and restarted."
}

# Main menu function
show_menu() {
    echo "Please select an option:"
    echo "1) Basic Installation"
    echo "2) Turn on (restart) Blockmesh"
    echo "3) Turn on (restart) Dawn"
    echo "4) Turn on (restart) Grass"
    echo "5) Exit"
    read -p "Enter your choice [1-5]: " choice

    case $choice in
        1)
            basic_installation
            ;;
        2)
            turn_on_blockmesh
            ;;
        3)
            turn_on_dawn
            ;;
        4)
            turn_on_grass
            ;;
        5)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice!"
            show_menu
            ;;
    esac
}

# Run the menu
show_menu

