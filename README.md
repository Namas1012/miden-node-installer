
# Miden Node Operator Installer

One-click installer for Miden Node Operator on Ubuntu/Debian systems.

## Quick Start

### Method 1: Download and Run
```bash
wget https://raw.githubusercontent.com/Namas1012/miden-node-installer/main/install_miden_node.sh
chmod +x install_miden_node.sh
./install_miden_node.sh

Method 2: Direct Install
curl -sSL https://raw.githubusercontent.com/Namas1012/miden-node-installer/main/install_miden_node.sh | bash


Requirements

Ubuntu 20.04+ or Debian 11+
4GB RAM (8GB recommended)
100GB SSD storage
Root access
Stable internet connection

Features

✅ One-click installation
✅ Automatic dependency installation
✅ Node bootstrap and configuration
✅ Management scripts creation
✅ Systemd service setup
✅ Firewall configuration
✅ gRPC client tools

Usage
After installation, use these commands:
# Node management
miden start          # Start node
miden stop           # Stop node
miden restart        # Restart node
miden status         # Check status
miden logs           # View logs

# API client
miden latest         # Get latest block
miden block 1        # Get specific block
miden rpc-status     # Get RPC status
miden methods        # List API methods

# Utilities
miden faucet         # Show faucet key
miden backup         # Backup node data
miden reset          # Reset and reinitialize

File Locations

Scripts: /root/*.sh
Data: /root/miden/data/
Accounts: /root/miden/accounts/
Logs: /root/miden/logs/
Faucet Key: /root/miden/accounts/faucet_miden.mac

Ports

RPC: 26657 (gRPC)
SSH: 22

Installation Process
The installer will:

Update system packages
Install dependencies (Rust, build tools, etc.)
Download and compile miden-node
Bootstrap the blockchain database
Create management scripts
Setup systemd service
Configure firewall
Install gRPC client tools

Post-Installation
After installation completes:
# Source the bashrc to use aliases
source ~/.bashrc

# Start the node
miden start

# Check status
miden status

# View logs
miden logs

Troubleshooting
Node won't start
bash# Check logs
miden logs

# Check process
ps aux | grep miden

# Reset and reinitialize
miden reset

RPC not accessible
bash# Check ports
ss -tlnp | grep 26657

# Test connection
curl -v http://localhost:26657

# Check grpcurl
grpcurl -plaintext localhost:26657 list
Sync issues
bash# Check sync logs
grep -E "(block_num|apply_block)" /root/miden/logs/miden-node.log | tail -10

# Check latest block
miden latest
Support
For issues and support, please open an issue on GitHub.
License
MIT License