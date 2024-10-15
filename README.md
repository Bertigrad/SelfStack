# TeamSpeak & Sinusbot & Audiobot Setup Script

This script is designed to easily set up and manage TeamSpeak 3, SinusBot, and TS3AudioBot on a Linux server. It automates the installation, configuration, and management of these services, making it easier to deploy and maintain voice communication services.

## Disclaimer

By using this script, you acknowledge and agree that **any potential data loss, system damage, or issues that arise from its use are solely your responsibility**. We, as the creators and maintainers of this script, **do not take any responsibility** for any problems that may occur, including but not limited to system malfunctions, data corruption, or any other unforeseen issues.

Please make sure you fully understand the changes that this script will make to your system and ensure you have **sufficient backups** before proceeding. **Use this script at your own risk**.


## Features
- **TeamSpeak 3** installation and configuration
- **SinusBot** installation, configuration, and service management
- **TS3AudioBot** installation, initial setup, and configuration
- Service management (start, stop, restart)
- Automatic update check for the script itself
- Easily configurable and user-friendly interface

## Requirements
- A Linux server (tested on Ubuntu/Debian)
- Sudo/root access
- Basic knowledge of Linux terminal

## Installation

### Download the Script

You can download the setup script directly using this command:

```bash
curl -O https://raw.githubusercontent.com/Bertigrad/SelfStack/refs/heads/main/SelfStack.sh
```
# Run the Script
**1. Ensure the script has execution permissions:**
```bash
chmod +x SelfStack.sh
```
**2. Start the setup process:**
```bash
./SelfStack.sh
```