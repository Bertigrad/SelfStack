#!/bin/bash

# This script is open-source and available on GitHub: https://github.com/Bertigrad/SelfStack
# Feel free to contribute, report issues, or suggest improvements.
# SelfStack is designed to help automate the setup and management of TeamSpeak and SinusBot servers.
# Created and maintained by Bertigrad.

# Color definitions
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
WHITE="\e[37m"
BOLD="\e[1m"
UNDERLINE="\e[4m"
RESET="\e[0m"  # Color reset

# Define the current script version
script_version="v0.1.0"

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

exit_script() {
    clear
    echo -e "${GREEN}Exiting... Goodbye!${RESET}"
    exit 0
}

# Function to detect the operating system
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# Operating system check
check_os() {
    os=$(detect_os)
    if [[ "$os" != "ubuntu" && "$os" != "debian" ]]; then
        echo -e "${RED}Unsupported operating system: $os. This script only runs on Debian and Ubuntu.${RESET}"
        exit 1
    fi
}

check_ip_permission() {
    if [ ! -f "$SCRIPT_DIR/ip_permission.txt" ]; then
        echo -e "${YELLOW}Do you want to allow fetching your public IPv4 address? (y/n): ${RESET}"
        read -p "> " fetch_ip

        if [[ "$fetch_ip" == "y" || "$fetch_ip" == "Y" ]]; then
            echo "allowed" > $SCRIPT_DIR/ip_permission.txt
            return 0  # Permission granted
        else
            echo "denied" > $SCRIPT_DIR/ip_permission.txt
            return 1  # Permission denied
        fi
    else
        # Check previously set permission
        if grep -q "allowed" $SCRIPT_DIR/ip_permission.txt; then
            return 0  # Permission granted
        else
            return 1  # Permission denied
        fi
    fi
}

# Function to check TeamSpeak 3 installation
check_teamspeak_installed() {
    if [ -d "/home/ts3user/teamspeak3-server_linux_amd64" ] && [ -f "/home/ts3user/teamspeak3-server_linux_amd64/ts3server_startscript.sh" ]; then
        ts3_installed=true
        ts3_status="(Installed)"
    else
        ts3_installed=false
        ts3_status="(Not Installed)"
    fi
}

# Function to check SinusBot installation
check_sinusbot_installed() {
    if [ -d "/opt/sinusbot" ] && [ -f "/opt/sinusbot/sinusbot" ]; then
        sinusbot_installed=true
        sinusbot_status="(Installed)"
    else
        sinusbot_installed=false
        sinusbot_status="(Not Installed)"
    fi
}

check_audiobot_installed() {
    if [ -d "/opt/audiobot" ] && [ -f "/opt/audiobot/TS3AudioBot" ]; then
        audiobot_installed=true
        audiobot_status="(Installed)"
    else
        audiobot_installed=false
        audiobot_status="(Not Installed)"
    fi
}

check_for_updates() {
    local repo_owner="Bertigrad"
    local repo_name="SelfStack"
    local script_name="SelfStack.sh"
    local local_version="$script_version"
    local latest_version
    local download_url

    echo -e "${YELLOW}Checking for updates...${RESET}"

    # Check the latest release version from GitHub API
    latest_version=$(curl -s "https://api.github.com/repos/$repo_owner/$repo_name/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')

    # If GitHub API fails to retrieve version info, show an error
    if [ -z "$latest_version" ]; then
        echo -e "${RED}Failed to check for updates. Please try again later.${RESET}"
        return 1
    fi

    # Compare current version with the latest available version
    if [ "$local_version" != "$latest_version" ]; then
        echo -e "${YELLOW}A new version ($latest_version) is available.${RESET}"
        
        # URL to download the new version of the script
        download_url="https://raw.githubusercontent.com/$repo_owner/$repo_name/$latest_version/$script_name"
        
        # Download the new version of the script
        echo -e "${YELLOW}Downloading and updating to version $latest_version...${RESET}"
        curl -o "$script_name.new" "$download_url"
        
        # Make the new script executable
        chmod +x "$script_name.new"

        # Replace the current script with the new version
        mv "$script_name.new" "$script_name"

        echo -e "${GREEN}Updated to version $latest_version! Restarting the script...${RESET}"

        # Execute the new script version and pass along any arguments
        exec ./$script_name "$@"
    else
        echo -e "${GREEN}You are using the latest version ($local_version).${RESET}"
    fi
}



# Function to install TeamSpeak 3
install_teamspeak() {
    echo -e "${GREEN}Installing TeamSpeak 3...${RESET}"

    # Installing dependencies
    echo -e "${YELLOW}Updating package list and installing dependencies...${RESET}"
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y wget tar bzip2

    # Check if TeamSpeak user exists
    echo -e "${YELLOW}Creating TeamSpeak user...${RESET}"
    sudo useradd -m -s /bin/bash ts3user

    # Downloading TeamSpeak 3 server
    echo -e "${YELLOW}Downloading TeamSpeak 3 server...${RESET}"
    wget https://files.teamspeak-services.com/releases/server/3.13.7/teamspeak3-server_linux_amd64-3.13.7.tar.bz2 -P /tmp

    # Extracting TeamSpeak 3 server
    echo -e "${YELLOW}Installing TeamSpeak 3...${RESET}"
    sudo tar -xvf /tmp/teamspeak3-server_linux_amd64-3.13.7.tar.bz2 -C /home/ts3user
    rm -rf /tmp/teamspeak3-server_linux_amd64-3.13.7.tar.bz2
    sudo chown -R ts3user:ts3user /home/ts3user/teamspeak3-server_linux_amd64

    # Accepting TeamSpeak license
    touch /home/ts3user/teamspeak3-server_linux_amd64/.ts3server_license_accepted
    sudo chown ts3user:ts3user /home/ts3user/teamspeak3-server_linux_amd64/.ts3server_license_accepted

    # Starting TeamSpeak 3 server
    clear
    echo -e "${YELLOW}Starting TeamSpeak 3 server...${RESET}"
    sudo -u ts3user /home/ts3user/teamspeak3-server_linux_amd64/ts3server_startscript.sh start &> /home/ts3user/ts3server.log
    sleep 3

    # Check IP permission
    if check_ip_permission; then
        ipv4_address=$(curl -4 -s ifconfig.me)
    else
        ipv4_address="ip address"
    fi

    # Ask if the user wants to set up TeamSpeak to start on boot
    echo -e "${MAGENTA}Do you want to set up TeamSpeak to start on boot? (y/n)${RESET}"
    read -p "> " start_on_boot

    if [[ "$start_on_boot" == "y" || "$start_on_boot" == "Y" ]]; then
        # Setting up TeamSpeak to start on boot
        echo -e "${YELLOW}Setting up TeamSpeak to start on boot...${RESET}"
        sudo tee /etc/systemd/system/teamspeak.service > /dev/null <<EOL
[Unit]
Description=TeamSpeak 3 Server
After=network.target

[Service]
WorkingDirectory=/home/ts3user/teamspeak3-server_linux_amd64
User=ts3user
Group=ts3user
Type=forking
ExecStart=/home/ts3user/teamspeak3-server_linux_amd64/ts3server_startscript.sh start
ExecStop=/home/ts3user/teamspeak3-server_linux_amd64/ts3server_startscript.sh stop
ExecReload=/home/ts3user/teamspeak3-server_linux_amd64/ts3server_startscript.sh restart
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
EOL

    # Service enable ve start
    sudo -u ts3user /home/ts3user/teamspeak3-server_linux_amd64/ts3server_startscript.sh stop
    sleep 2
    sudo systemctl daemon-reload
    sudo systemctl enable teamspeak
    sudo systemctl start teamspeak

    echo -e "${GREEN}TeamSpeak service has been set to start on boot and has been started successfully.${RESET}"
    else
    echo -e "${YELLOW}Skipping setting up TeamSpeak to start on boot.${RESET}"
    sleep 1
    fi
    
    echo -e "${GREEN}Installation completed successfully!${RESET}"
    # Get the login name, admin password, and token
    admin_password=$(grep -oP 'password= "\K[^"]+' /home/ts3user/ts3server.log)
    token=$(grep -oP 'token=\K[^"]+' /home/ts3user/ts3server.log)
    login_name=$(grep -oP 'loginname= "\K[^"]+' /home/ts3user/ts3server.log)

    # Bilgileri kullanıcıya gösterme
    if [ -n "$login_name" ]; then
    echo -e "${GREEN}Login Name: ${login_name}${RESET}"
    else
    echo -e "${RED}Login Name not found!${RESET}"
    fi

    if [ -n "$admin_password" ]; then
    echo -e "${GREEN}Admin Password: ${admin_password}${RESET}"
    else
    echo -e "${RED}Admin Password not found!${RESET}"
    fi

    if [ -n "$token" ]; then
    echo -e "${GREEN}Token: ${token}${RESET}"
    else
    echo -e "${RED}Token not found!${RESET}"
    fi
    rm -rf /home/ts3user/ts3server.log
    
    echo -e "${CYAN}You can connect to the server using the following IPv4 address: ${RESET}$ipv4_address"
}

# Function to install Mumble
install_mumble() {
    echo -e "${GREEN}Installing Mumble...${RESET}"
    
    # Need to update the package list and install dependencies
    echo -e "${YELLOW}Updating package list and installing dependencies...${RESET}"
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y mumble-server

    # Check IP permission
    if check_ip_permission; then
        ipv4_address=$(curl -4 -s ifconfig.me)
    else
        ipv4_address="ip address"
    fi

    echo -e "${GREEN}Mumble installation completed!${RESET}"
    echo -e "${CYAN}You can now connect to the server using the following IPv4 address:${RESET} $ipv4_address"
}

install_sinusbot() {
    echo -e "${GREEN}Installing SinusBot...${RESET}"
    echo -e "${YELLOW}Updating package lists...${RESET}"
    sudo apt-get update

    echo -e "${YELLOW}Installing required dependencies...${RESET}"
    sudo apt-get install -y x11vnc xvfb libxcursor1 ca-certificates curl bzip2 libnss3 libegl1-mesa x11-xkb-utils libasound2 libpci3 libxslt1.1 libxkbcommon0 libxss1 libxcomposite1 screen

    echo -e "${YELLOW}Updating CA certificates...${RESET}"
    sudo update-ca-certificates

    echo -e "${YELLOW}Installing libglib2.0-0...${RESET}"
    sudo apt-get install -y libglib2.0-0

    # SinusBot kullanıcısını oluştur
    if id "sinusbot" &>/dev/null; then
        echo -e "${GREEN}SinusBot user already exists.${RESET}"
    else
        echo -e "${YELLOW}Creating SinusBot user...${RESET}"
        sudo useradd -m -s /bin/bash sinusbot
        echo -e "${GREEN}SinusBot user created.${RESET}"
    fi

    # Create the SinusBot directory
    echo -e "${YELLOW}Creating SinusBot directory...${RESET}"
    sudo mkdir -p /opt/sinusbot

    # Set permissions for the SinusBot user
    echo -e "${YELLOW}Granting permissions to SinusBot user...${RESET}"
    sudo chown -R sinusbot:sinusbot /opt/sinusbot

    # Run the following commands as the SinusBot user
    echo -e "${YELLOW}Switching to SinusBot user...${RESET}"
    cd /opt/sinusbot
    
    echo -e "${YELLOW}Downloading SinusBot...${RESET}"
    sudo -u sinusbot wget https://www.sinusbot.com/dl/sinusbot.current.tar.bz2

    echo -e "${YELLOW}Extracting SinusBot...${RESET}"
    sudo -u sinusbot tar -xjf sinusbot.current.tar.bz2

    echo -e "${YELLOW}Removing SinusBot archive...${RESET}"
    rm -rf sinusbot.current.tar.bz2

    echo -e "${YELLOW}Copying default config.ini...${RESET}"
    sudo -u sinusbot cp config.ini.dist config.ini
    rm -rf config.ini.dist

    # Download TeamSpeak 3 Client
    VERSION="3.5.6"
    echo -e "${YELLOW}Downloading TeamSpeak 3 Client version ${VERSION}...${RESET}"
    sudo -u sinusbot wget https://files.teamspeak-services.com/releases/client/$VERSION/TeamSpeak3-Client-linux_amd64-$VERSION.run

    echo -e "${YELLOW}Setting permissions for TeamSpeak 3 Client...${RESET}"
    chmod 0755 TeamSpeak3-Client-linux_amd64-$VERSION.run

    echo -e "${CYAN}Please press Enter to continue, then 'q' to quit the license agreement, and 'y' to accept the license...${RESET}"
    sleep 2 

    echo -e "${YELLOW}Installing TeamSpeak 3 Client...${RESET}"
    sudo -u sinusbot ./TeamSpeak3-Client-linux_amd64-$VERSION.run

    echo -e "${YELLOW}Removing TeamSpeak 3 Client installer...${RESET}"
    rm -rf TeamSpeak3-Client-linux_amd64-$VERSION.run

    # Edit the config.ini file
    sed -i 's|TS3Path =.*|TS3Path = "/opt/sinusbot/TeamSpeak3-Client-linux_amd64/ts3client_linux_amd64"|' config.ini
    echo -e "${YELLOW}Removing libqxcb-glx-integration.so...${RESET}"
    rm TeamSpeak3-Client-linux_amd64/xcbglintegrations/libqxcb-glx-integration.so

    # Create the plugins directory and copy the soundbot plugin
    echo -e "${YELLOW}Creating plugins directory...${RESET}"
    sudo -u sinusbot mkdir TeamSpeak3-Client-linux_amd64/plugins

    echo -e "${YELLOW}Copying soundbot plugin...${RESET}"
    sudo -u sinusbot cp plugin/libsoundbot_plugin.so TeamSpeak3-Client-linux_amd64/plugins/

    echo -e "${YELLOW}Installing youtube-dl...${RESET}"
    wget -q https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/local/bin/youtube-dl
    chmod a+rx /usr/local/bin/youtube-dl
    sed -i '1iYoutubeDLPath = "/usr/local/bin/youtube-dl"' config.ini
    youtube-dl -U --restrict-filename

    echo -e "${YELLOW}Setting permissions for SinusBot...${RESET}"
    chmod 755 sinusbot

    # Start the SinusBot to get the password
    echo -e "${YELLOW}Starting SinusBot to retrieve password...${RESET}"
    export Q=$(su sinusbot -c './sinusbot --initonly')
    password=$(echo "$Q" | awk '/password/{ print $10 }' | tr -d "'")
    if [ -z "$password" ]; then
        echo -e "${RED}Failed to read password, try a reinstall again.${RESET}"
        exit 1
    fi
    # Download the SinusBot service file
    echo -e "${YELLOW}Downloading SinusBot service file...${RESET}"
    sudo curl -o /lib/systemd/system/sinusbot.service https://raw.githubusercontent.com/SinusBot/linux-startscript/master/sinusbot.service

    # Edit the SinusBot service file
    echo -e "${YELLOW}Editing the SinusBot service file...${RESET}"
    sudo sed -i 's|YOUR_USER|sinusbot|' /lib/systemd/system/sinusbot.service
    sudo sed -i 's|YOURPATH_TO_THE_BOT_BINARY|/opt/sinusbot/sinusbot|' /lib/systemd/system/sinusbot.service
    sudo sed -i 's|YOURPATH_TO_THE_BOT_DIRECTORY|/opt/sinusbot|' /lib/systemd/system/sinusbot.service

    # Enable the SinusBot service
    echo -e "${YELLOW}Enabling SinusBot service...${RESET}"
    systemctl daemon-reload
    sudo systemctl enable sinusbot.service
    sleep 2
    # Start the SinusBot service
    echo -e "${YELLOW}Starting SinusBot service...${RESET}"
    sudo systemctl start sinusbot.service

    # Check IP permission
    if check_ip_permission; then
        ipv4_address=$(curl -4 -s ifconfig.me)
    else
        ipv4_address="ip address"
    fi
    clear
    echo -e "${GREEN}SinusBot installation completed!${RESET}"
    echo -e "${GREEN}You can access the SinusBot panel at http://$ipv4_address:8087${RESET}"
    echo -e "${GREEN}Username: admin${RESET}"
    echo -e "${GREEN}Password: $password ${RESET}"
}

install_audiobot() {
    echo -e "${YELLOW}Installing dependencies...${RESET}"
    sudo apt-get update
    sudo apt-get install -y libopus-dev ffmpeg tar bzip2 wget screen

    echo -e "${YELLOW}Creating directory for AudioBot...${RESET}"
    mkdir -p /opt/audiobot
    cd /opt/audiobot

    echo -e "${YELLOW}Downloading TS3AudioBot...${RESET}"
    wget -O bot.tar.gz https://github.com/Bertigrad/SelfStack/raw/refs/heads/main/Audiobot/ts3audiobot.tar.gz

    echo -e "${YELLOW}Extracting TS3AudioBot archive...${RESET}"
    tar -xzf bot.tar.gz

    echo -e "${YELLOW}Cleaning up the archive file...${RESET}"
    rm -f bot.tar.gz

    echo -e "${YELLOW}Installing youtube-dl...${RESET}"
    wget -q https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/local/bin/youtube-dl
    chmod a+rx /usr/local/bin/youtube-dl
    /usr/local/bin/youtube-dl -U --restrict-filename

    # Get the server address from the user
    read -p "Please enter the server address: " server_address

    # Ask if the server has a password
    read -p "Does the server have a password? (y/n): " has_password
    if [ "$has_password" == "y" ]; then
        read -p "Please enter the server password: " server_password
    else
        server_password=""
    fi

    # Get admin permission ID from the user
    read -p "Please enter the admin group ID(s) (comma-separated if multiple): " admin_group_ids

    # Get admin UID from user
    read -p "Please enter the admin user's Teamspeak UID: " admin_uid

    # Get the DJ permission ID from the user
    read -p "Please enter the DJ group ID(s) (comma-separated if multiple): " dj_group_ids

    echo -e "${YELLOW}Updating bot configuration files...${RESET}"

    # edit bot.toml
    sed -i "s/address = \"\"/address = \"$server_address\"/g" /opt/audiobot/bots/default/bot.toml
    sed -i "s/server_password = { pw = \"\" }/server_password = { pw = \"$server_password\" }/g" /opt/audiobot/bots/default/bot.toml

    # edit rights.toml
    sed -i "s/groupid = \[admingroupid\]/groupid = [$admin_group_ids]/g" /opt/audiobot/rights.toml
    sed -i "s/useruid = \[ \"adminuid\" \]/useruid = \[ \"$admin_uid\" \]/g" /opt/audiobot/rights.toml
    sed -i "s/groupid = \[djgroupid\]/groupid = [$dj_group_ids]/g" /opt/audiobot/rights.toml

    echo -e "${YELLOW}Starting TS3AudioBot in the background using screen...${RESET}"

    # Start the bot in the background using screen
    screen -dmS audiobot /opt/audiobot/TS3AudioBot

    # Check IP permission
    if check_ip_permission; then
        ipv4_address=$(curl -4 -s ifconfig.me)
    else
        ipv4_address="ip address"
    fi
    clear
    echo -e "${GREEN}TS3AudioBot installation and setup complete!${RESET}"
    echo "You can access the bot's web panel at: http://$ipv4_address:58913"
    echo "To log in to the panel, send a private message to the bot in your Teamspeak server."
    echo "Use the command (!api token) and then enter the token you receive in the panel."
}

voice_server_menu(){
    clear
    echo -e "${CYAN}${BOLD}*********************************${RESET}"
    echo -e "${CYAN}${BOLD}*                               *${RESET}"
    echo -e "${CYAN}${BOLD}*       ${GREEN}Voice Servers Menu${CYAN}      *${RESET}"
    echo -e "${CYAN}${BOLD}*                               *${RESET}"
    echo -e "${CYAN}${BOLD}*********************************${RESET}"
    echo ""
    echo -e "${YELLOW}${BOLD}>> Voice Servers Menu${RESET}"
    echo ""
    echo -e "${BLUE}${BOLD}1)${RESET} ${WHITE}Setup Voice Servers${RESET}"
    echo -e "${BLUE}${BOLD}2)${RESET} ${WHITE}Manage Voice Servers${RESET}"
    echo -e "${BLUE}${BOLD}3)${RESET} ${WHITE}Go Back to Main Menu${RESET}"
    echo -e "${BLUE}${BOLD}0)${RESET} ${WHITE}Exit${RESET}"
    echo ""
    echo -e "${MAGENTA}${BOLD}Please enter your choice: ${RESET}"
    read -p "> " voice_choice

    case $voice_choice in
        1)
            voice_server_setup_menu
            ;;
        2)
            voice_server_manage_menu
            ;;
        3)
            main_menu
            ;;
        0)
            exit_script
            ;;
        *)
            clear
            echo -e "${RED}${BOLD}Invalid choice!${RESET} Please enter a valid option [1-3]."
            voice_server_menu
            ;;
        esac
}

# Voice server alt menüsü
voice_server_setup_menu() {
    clear

    check_teamspeak_installed
    check_sinusbot_installed
    check_audiobot_installed

    echo -e "${CYAN}${BOLD}*********************************************${RESET}"
    echo -e "${CYAN}${BOLD}*                                           *${RESET}"
    echo -e "${CYAN}${BOLD}*      ${GREEN}Voice Servers Installation Menu${CYAN}      *${RESET}"
    echo -e "${CYAN}${BOLD}*                                           *${RESET}"
    echo -e "${CYAN}${BOLD}*********************************************${RESET}"
    echo ""
    echo -e "${YELLOW}${BOLD}>> Select Voice Server to Install${RESET}"
    echo ""
    echo -e "${BLUE}${BOLD}1)${RESET} ${WHITE}Install TeamSpeak 3 Server ${RED}${ts3_status}${RESET}"
    echo -e "${BLUE}${BOLD}2)${RESET} ${WHITE}Install Mumble Server ${RESET}"
    echo -e "${BLUE}${BOLD}3)${RESET} ${WHITE}Install SinusBot ${RED}${sinusbot_status}${RESET}"
    echo -e "${BLUE}${BOLD}4)${RESET} ${WHITE}Install Audiobot ${RED}${audiobot_status}${RESET}"
    echo -e "${BLUE}${BOLD}5)${RESET} ${WHITE}Go Back to Main Menu${RESET}"
    echo -e "${BLUE}${BOLD}0)${RESET} ${WHITE}Exit${RESET}"
    echo ""
    echo -e "${MAGENTA}${BOLD}Please enter your choice: ${RESET}"
    read -p "> " voice_choice_setup

    case $voice_choice_setup in
        1)
            clear
            install_teamspeak # TeamSpeak 3 Installing function
            ;;
        2)
            clear
            install_mumble  # Mumble Installing function
            ;;
        3)
            clear
            install_sinusbot  # SinusBot Installing function
            ;;
        4)
            clear
            install_audiobot  # Audiobot Installing function
            ;;
        5)
            main_menu  # Return to main menu
            ;;
        0)
            exit_script  # Exit the script
            ;;
        *)
            clear
            echo -e "${RED}${BOLD}Invalid choice!${RESET} Please enter a valid option [1-4]."
            voice_server_menu  # Show the sub-menu again in case of an invalid entry
            ;;
    esac
}

voice_server_manage_menu(){
    clear

    check_teamspeak_installed
    check_sinusbot_installed
    check_audiobot_installed

    echo -e "${CYAN}${BOLD}**********************************${RESET}"
    echo -e "${CYAN}${BOLD}*                                *${RESET}"
    echo -e "${CYAN}${BOLD}*   ${GREEN}Voice Servers Manage Menu${CYAN}    *${RESET}"
    echo -e "${CYAN}${BOLD}*                                *${RESET}"
    echo -e "${CYAN}${BOLD}**********************************${RESET}"
    echo ""
    echo -e "${YELLOW}${BOLD}>> Select Voice Server to Manage${RESET}"
    echo ""
    echo -e "${BLUE}${BOLD}1)${RESET} ${WHITE}Manage Teamspeak 3 ${RED}${ts3_status}${RESET}"
    echo -e "${BLUE}${BOLD}2)${RESET} ${WHITE}Manage Sinusbot ${RED}${sinusbot_status}${RESET}"
    echo -e "${BLUE}${BOLD}3)${RESET} ${WHITE}Manage Audiobot ${RED}${audiobot_status}${RESET}"
    echo -e "${BLUE}${BOLD}4)${RESET} ${WHITE}Go Back to Main Menu${RESET}"
    echo -e "${BLUE}${BOLD}0)${RESET} ${WHITE}Exit${RESET}"
    echo ""
    echo -e "${MAGENTA}${BOLD}Please enter your choice: ${RESET}"
    read -p "> " voice_manage_choice

    case $voice_manage_choice in
    1)
        if [ "$ts3_installed" = true ]; then
            clear
            manage_teamspeak
        else
            clear
            echo -e "${RED}${BOLD}TeamSpeak 3 is not installed!${RESET} Please install it first."
            sleep 2
            voice_server_manage_menu
        fi
        ;;
    2)
        if [ "$sinusbot_installed" = true ]; then
            clear
            manage_sinusbot
        else
            clear
            echo -e "${RED}${BOLD}SinusBot is not installed!${RESET} Please install it first."
            sleep 2
            voice_server_manage_menu
        fi
        ;;
    3)
        if [ "$audiobot_installed" = true ]; then
            clear
            manage_audiobot
        else
            clear
            echo -e "${RED}${BOLD}Audiobot is not installed!${RESET} Please install it first."
            sleep 2
            voice_server_manage_menu
        fi
        ;;
    4)
        main_menu
        ;;
    0)
        exit_script
        ;;
    *)
        clear
        echo -e "${RED}${BOLD}Invalid choice!${RESET} Please enter a valid option [1-3]."
        voice_server_manage_menu
        ;;
    esac
}

manage_teamspeak(){
    clear
    echo -e "${CYAN}${BOLD}**********************************${RESET}"
    echo -e "${CYAN}${BOLD}*                                *${RESET}"
    echo -e "${CYAN}${BOLD}*       ${GREEN}Manage Teamspeak 3${CYAN}       *${RESET}"
    echo -e "${CYAN}${BOLD}*                                *${RESET}"
    echo -e "${CYAN}${BOLD}**********************************${RESET}"
    echo ""
    echo -e "${YELLOW}${BOLD}>> Teamspeak Manage Menu${RESET}"
    echo ""
    echo -e "${BLUE}${BOLD}1)${RESET} ${WHITE}Start Teamspeak 3 Server${RESET}"
    echo -e "${BLUE}${BOLD}2)${RESET} ${WHITE}Stop Teamspeak 3 Server${RESET}"
    echo -e "${BLUE}${BOLD}3)${RESET} ${WHITE}Restart Teamspeak 3 Server${RESET}"
    echo -e "${BLUE}${BOLD}4)${RESET} ${WHITE}Delete Teamspeak 3 Server${RESET}"
    echo -e "${BLUE}${BOLD}5)${RESET} ${WHITE}Go Back to Main Menu${RESET}"
    echo -e "${BLUE}${BOLD}0)${RESET} ${WHITE}Exit${RESET}"
    echo ""
    echo -e "${MAGENTA}${BOLD}Please enter your choice: ${RESET}"
    read -p "> " manage_teamspeak_choice

    case $manage_teamspeak_choice in
    1)
        clear
        # Is TeamSpeak service defined?
        if systemctl list-units --type=service | grep -q "teamspeak.service"; then
        # Is TeamSpeak service running?
        if systemctl is-active --quiet teamspeak; then
        echo -e "${YELLOW}TeamSpeak service is already running."
        else
        echo -e "${YELLOW}Starting TeamSpeak service..."
        systemctl start teamspeak
        if [ $? -eq 0 ]; then
            echo -e "TeamSpeak service started successfully.${RESET}"
        else
            echo -e "Failed to start TeamSpeak service. Check logs for more details.${RESET}"
        fi
        fi
        else
        echo -e "${YELLOW}TeamSpeak service not found, checking manually..."

        # Is there a manually running TeamSpeak process?
        if cd /home/ts3user/teamspeak3-server_linux_amd64 && ./ts3server_startscript.sh status | grep -q "Server is running"; then
        echo -e "TeamSpeak is already running manually.${RESET}"
        else
        echo -e "Starting TeamSpeak manually...${RESET}"
        sudo -u ts3user ./ts3server_startscript.sh start
        echo -e "TeamSpeak started successfully.${RESET}"
        fi
    fi
;;
    2)
        clear
        # Is TeamSpeak service defined?
        if systemctl list-units --type=service | grep -q "teamspeak.service"; then
        # Is TeamSpeak service running?
        if systemctl is-active --quiet teamspeak; then
        echo -e "${YELLOW}Stopping TeamSpeak service..."
        systemctl stop teamspeak
        if [ $? -eq 0 ]; then
            echo -e "TeamSpeak service stopped successfully.${RESET}"
        else
            echo -e "Failed to stop TeamSpeak service. Check logs for more details.${RESET}"
        fi
        else
        echo -e "TeamSpeak service is already stopped.${RESET}"
        fi
        else
        echo -e "${YELLOW}TeamSpeak service not found, checking manually..."

        # Is there a manually running TeamSpeak process?
        if cd /home/ts3user/teamspeak3-server_linux_amd64 && ./ts3server_startscript.sh status | grep -q "Server is running"; then
        echo -e "Stopping TeamSpeak manually..."
        sudo -u ts3user ./ts3server_startscript.sh stop
        if [ $? -eq 0 ]; then
            echo -e "TeamSpeak stopped successfully.${RESET}"
        else
            echo -e "Failed to stop TeamSpeak. Check logs for more details.${RESET}"
        fi
        else
        echo -e "${YELLOW}No running instance of TeamSpeak found.${RESET}"
        fi
    fi
;;
    3)
        clear
        # Is TeamSpeak service defined?
        if systemctl list-units --type=service | grep -q "teamspeak.service"; then
        echo -e "${YELLOW}Restarting TeamSpeak service..."
        systemctl restart teamspeak
        if [ $? -eq 0 ]; then
            echo -e "TeamSpeak service restarted successfully.${RESET}"
        else
            echo -e "Failed to restart TeamSpeak service. Check logs for more details.${RESET}"
        fi
        else
        echo -e "${YELLOW}TeamSpeak service not found, checking manually..."

        # Is there a manually running TeamSpeak process?
        if cd /home/ts3user/teamspeak3-server_linux_amd64 && ./ts3server_startscript.sh status | grep -q "Server is running"; then
        echo -e "${YELLOW}Restarting TeamSpeak manually..."
        sudo -u ts3user ./ts3server_startscript.sh restart
        if [ $? -eq 0 ]; then
            echo -e "TeamSpeak restarted successfully.${RESET}"
        else
            echo -e "Failed to restart TeamSpeak. Check logs for more details.${RESET}"
        fi
        else
        echo -e "${YELLOW}No running instance of TeamSpeak found.${RESET}"
        fi
    fi
;;
    4)
        clear
        echo -e "${RED}WARNING: This will delete the TeamSpeak server and all associated data!${RESET}"
        echo -e "${YELLOW}Do you want to continue? (y/n)"
        read -p "> " delete_teamspeak

        if [[ "$delete_teamspeak" == "y" || "$delete_teamspeak" == "Y" ]]; then
        # Is TeamSpeak service defined?
        if systemctl list-units --type=service | grep -q "teamspeak.service"; then
        echo -e "Stopping TeamSpeak service..."
        systemctl stop teamspeak
        echo -e "Deleting TeamSpeak service...${RESET}"
        systemctl disable teamspeak
        rm -rf /etc/systemd/system/teamspeak.service
        systemctl daemon-reload
        systemctl reset-failed
        else
        echo -e "TeamSpeak service not found, checking manually...${RESET}"

        # Is there a manually running TeamSpeak process?
        if cd /home/ts3user/teamspeak3-server_linux_amd64 && ./ts3server_startscript.sh status | grep -q "Server is running"; then
        echo -e "Stopping TeamSpeak manually..."
        sudo -u ts3user ./ts3server_startscript.sh stop
        echo -e "Deleting TeamSpeak manually...${RESET}"
        rm -rf /home/ts3user/teamspeak3-server_linux_amd64
        else
        echo -e "No running instance of TeamSpeak found."
        fi
    fi
    echo -e "${GREEN}TeamSpeak server has been deleted successfully.${RESET}"
    else
    echo -e "${YELLOW}Skipping TeamSpeak server deletion.${RESET}"
    fi
;;
    0)
        exit_script
        ;;
    *)
        clear
        echo -e "${RED}${BOLD}Invalid choice!${RESET} Please enter a valid option [1-4]."
        manage_teamspeak
        ;;
esac
}

manage_sinusbot(){
    clear
    echo -e "${CYAN}${BOLD}**********************************${RESET}"
    echo -e "${CYAN}${BOLD}*                                *${RESET}"
    echo -e "${CYAN}${BOLD}*         ${GREEN}Manage SinusBot${CYAN}        *${RESET}"
    echo -e "${CYAN}${BOLD}*                                *${RESET}"
    echo -e "${CYAN}${BOLD}**********************************${RESET}"
    echo ""
    echo -e "${YELLOW}${BOLD}>> SinusBot Manage Menu${RESET}"
    echo ""
    echo -e "${BLUE}${BOLD}1)${RESET} ${WHITE}Start SinusBot${RESET}"
    echo -e "${BLUE}${BOLD}2)${RESET} ${WHITE}Stop SinusBot${RESET}"
    echo -e "${BLUE}${BOLD}3)${RESET} ${WHITE}Restart SinusBot${RESET}"
    echo -e "${BLUE}${BOLD}4)${RESET} ${WHITE}Delete SinusBot${RESET}"
    echo -e "${BLUE}${BOLD}5)${RESET} ${WHITE}Go Back to Main Menu${RESET}"
    echo -e "${BLUE}${BOLD}0)${RESET} ${WHITE}Exit${RESET}"
    echo ""
    echo -e "${MAGENTA}${BOLD}Please enter your choice: ${RESET}"
    read -p "> " manage_sinusbot_choice

    case $manage_sinusbot_choice in
    1)
        clear
        # Is SinusBot service running?
        if systemctl is-active --quiet sinusbot; then
        echo -e "${YELLOW}SinusBot service is already running."
        else
        echo -e "${YELLOW}Starting SinusBot service..."
        systemctl start sinusbot
        if [ $? -eq 0 ]; then
            echo -e "SinusBot service started successfully.${RESET}"
        else
            echo -e "Failed to start SinusBot service. Check logs for more details.${RESET}"
        fi
        fi
;;
    2)
        clear
        # Is SinusBot service running?
        if systemctl is-active --quiet sinusbot; then
        echo -e "${YELLOW}Stopping SinusBot service..."
        systemctl stop sinusbot
        if [ $? -eq 0 ]; then
            echo -e "SinusBot service stopped successfully.${RESET}"
        else
            echo -e "Failed to stop SinusBot service. Check logs for more details.${RESET}"
        fi
        else
        echo -e "${YELLOW}SinusBot service is already stopped.${RESET}"
        fi
;;
    3)
        clear
        echo -e "${YELLOW}Restarting SinusBot service..."
        systemctl restart sinusbot
        if [ $? -eq 0 ]; then
        echo -e "SinusBot service restarted successfully.${RESET}"
        else
        echo -e "Failed to restart SinusBot service. Check logs for more details.${RESET}"
        fi
;;
    4)
        clear
        echo -e "${RED}WARNING: This will delete the SinusBot server and all associated data!${RESET}"
        echo -e "${YELLOW}Do you want to continue? (y/n)"
        read -p "> " delete_sinusbot

        if [[ "$delete_sinusbot" == "y" || "$delete_sinusbot" == "Y" ]]; then
        echo "Stopping SinusBot service..."
        systemctl stop sinusbot
        echo "Deleting SinusBot service..."
        systemctl disable sinusbot
        rm -rf /lib/systemd/system/sinusbot.service
        systemctl daemon-reload
        systemctl reset-failed
        rm -rf /opt/sinusbot
        echo -e "${GREEN}SinusBot server has been deleted successfully.${RESET}"
        else
        echo -e "${YELLOW}Skipping SinusBot server deletion.${RESET}"
        fi
;;
    5)
        main_menu
        ;;
    0)
        exit_script
        ;;
    *)
        clear
        echo -e "${RED}${BOLD}Invalid choice!${RESET} Please enter a valid option [1-4]."
        manage_sinusbot
        ;;
esac
}

manage_audiobot(){
    clear
    echo -e "${CYAN}${BOLD}**********************************${RESET}"
    echo -e "${CYAN}${BOLD}*                                *${RESET}"
    echo -e "${CYAN}${BOLD}*         ${GREEN}Manage Audiobot${CYAN}        *${RESET}"
    echo -e "${CYAN}${BOLD}*                                *${RESET}"
    echo -e "${CYAN}${BOLD}**********************************${RESET}"
    echo ""
    echo -e "${YELLOW}${BOLD}>> Audiobot Manage Menu${RESET}"
    echo ""
    echo -e "${BLUE}${BOLD}1)${RESET} ${WHITE}Start Audiobot${RESET}"
    echo -e "${BLUE}${BOLD}2)${RESET} ${WHITE}Stop Audiobot${RESET}"
    echo -e "${BLUE}${BOLD}3)${RESET} ${WHITE}Restart Audiobot${RESET}"
    echo -e "${BLUE}${BOLD}4)${RESET} ${WHITE}Delete Audiobot${RESET}"
    echo -e "${BLUE}${BOLD}5)${RESET} ${WHITE}Go Back to Main Menu${RESET}"
    echo -e "${BLUE}${BOLD}0)${RESET} ${WHITE}Exit${RESET}"
    echo ""
    echo -e "${MAGENTA}${BOLD}Please enter your choice: ${RESET}"
    read -p "> " manage_audiobot_choice

    case $manage_audiobot_choice in
    1)
        clear
        if screen -list | grep -q "audiobot"; then
        echo -e "${GREEN}Audiobot is already running.${RESET}"
    else
        echo -e "${YELLOW}Starting TS3AudioBot...${RESET}"
        # Audiobot'u screen ile arka planda başlat
        cd /opt/audiobot
        screen -dmS audiobot /opt/audiobot/TS3AudioBot
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}TS3AudioBot has started successfully!${RESET}"
        else
            echo -e "${RED}Failed to start TS3AudioBot.${RESET}"
        fi
    fi
;;
    2)
        clear
        if screen -list | grep -q "audiobot"; then
        echo -e "${YELLOW}Stopping TS3AudioBot...${RESET}"
        screen -S audiobot -X quit
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}TS3AudioBot has stopped successfully!${RESET}"
        else
            echo -e "${RED}Failed to stop TS3AudioBot.${RESET}"
        fi
    else
        echo -e "${GREEN}TS3AudioBot is not running.${RESET}"
    fi
;;
    3)
        clear
        if screen -list | grep -q "audiobot"; then
        echo -e "${YELLOW}Restarting TS3AudioBot...${RESET}"
        cd /opt/audiobot
        screen -S audiobot -X quit
        sleep 2
        screen -dmS audiobot /opt/audiobot/TS3AudioBot
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}TS3AudioBot has restarted successfully!${RESET}"
        else
            echo -e "${RED}Failed to restart TS3AudioBot.${RESET}"
        fi
    else
        echo -e "${GREEN}TS3AudioBot is not running.${RESET}"
    fi
;;
    4)
        clear
        echo -e "${RED}WARNING: This will delete the Audiobot server and all associated data!${RESET}"
        echo -e "${YELLOW}Do you want to continue? (y/n)"
        read -p "> " delete_audiobot

        if [[ "$delete_audiobot" == "y" || "$delete_audiobot" == "Y" ]]; then
        if screen -list | grep -q "audiobot"; then
        echo -e "${YELLOW}Stopping TS3AudioBot...${RESET}"
        screen -S audiobot -X quit
        fi
        echo -e "${YELLOW}Deleting TS3AudioBot...${RESET}"
        rm -rf /opt/audiobot
        echo -e "${GREEN}TS3AudioBot has been deleted successfully.${RESET}"
        else
        echo -e "${YELLOW}Skipping TS3AudioBot deletion.${RESET}"
        fi
;;
    5)
        main_menu
        ;;
    0)
        exit_script
        ;;
    *)
        clear
        echo -e "${RED}${BOLD}Invalid choice!${RESET} Please enter a valid option [1-4]."
        manage_audiobot
        ;;
esac
        
}

# Main menu
main_menu (){

clear
echo -e "${CYAN}${BOLD}*********************************************${RESET}"
echo -e "${CYAN}${BOLD}*                                           *${RESET}"
echo -e "${CYAN}${BOLD}*     ${GREEN}Welcome to the SelfStack Installer${CYAN}    *${RESET}"
echo -e "${CYAN}${BOLD}*                                           *${RESET}"
echo -e "${CYAN}${BOLD}*********************************************${RESET}"
echo ""
echo -e "${YELLOW}${BOLD}>> Main Menu${RESET}"
echo ""
echo -e "${BLUE}${BOLD}1)${RESET} ${WHITE}Voice Servers${RESET}"
echo -e "${BLUE}${BOLD}2)${RESET} ${WHITE}Setup Web Hosting ${YELLOW}(SOON)${RESET}"
echo -e "${BLUE}${BOLD}3)${RESET} ${WHITE}Setup Database Server ${YELLOW}(SOON)${RESET}"
echo -e "${BLUE}${BOLD}4)${RESET} ${WHITE}Mail Server ${YELLOW}(SOON)${RESET}"
echo -e "${BLUE}${BOLD}0)${RESET} ${WHITE}Exit${RESET}"
echo ""
echo -e "${MAGENTA}${BOLD}Please enter your choice: ${RESET}"
read -p "> " choice

# Switch case for the main menu
case $choice in
    1)
        voice_server_menu
        ;;
    0)
        exit_script
        ;;
    *)
        clear
        echo -e "${RED}${BOLD}Invalid choice!${RESET} Please enter a valid option [1-4]."
        ;;
esac
}

check_os
# Call the update check function
check_for_updates "$@"

main_menu