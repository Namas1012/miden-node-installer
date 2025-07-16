#!/bin/bash
# Miden Node Operator - Root Installation Script (FIXED VERSION)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Variables
MIDEN_HOME="/root/miden"
MIDEN_DATA_DIR="$MIDEN_HOME/data"
MIDEN_ACCOUNTS_DIR="$MIDEN_HOME/accounts"
MIDEN_CONFIG_DIR="$MIDEN_HOME/config"
MIDEN_LOGS_DIR="$MIDEN_HOME/logs"
RUST_VERSION="1.82"

log "Starting Miden Node Operator installation..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
   exit 1
fi

# Check OS compatibility
if ! grep -E "(Ubuntu|Debian)" /etc/os-release > /dev/null; then
    warn "This script is designed for Ubuntu/Debian. Continuing anyway..."
fi

# Check disk space (at least 100GB)
AVAILABLE_SPACE=$(df / | tail -1 | awk '{print $4}')
if [ $AVAILABLE_SPACE -lt 104857600 ]; then  # 100GB in KB
    error "Insufficient disk space. At least 100GB required."
    exit 1
fi

# Update system
log "Updating system packages..."
apt update && apt upgrade -y

# Install dependencies
log "Installing system dependencies..."
apt install -y \
    curl \
    wget \
    git \
    build-essential \
    llvm \
    clang \
    bindgen \
    pkg-config \
    libssl-dev \
    libsqlite3-dev \
    protobuf-compiler \
    libprotobuf-dev \
    software-properties-common \
    unzip \
    jq \
    htop \
    tree \
    systemd \
    net-tools \
    ufw

# Create miden directories
log "Creating Miden directories..."
mkdir -p "$MIDEN_DATA_DIR"
mkdir -p "$MIDEN_ACCOUNTS_DIR"
mkdir -p "$MIDEN_CONFIG_DIR"
mkdir -p "$MIDEN_LOGS_DIR"

# Install Rust
log "Installing Rust $RUST_VERSION..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain $RUST_VERSION
source ~/.cargo/env

# Verify Rust installation
RUST_INSTALLED_VERSION=$(~/.cargo/bin/rustc --version | cut -d' ' -f2)
log "Rust installed: $RUST_INSTALLED_VERSION"

# Install miden-node with testing features (FIXED)
log "Installing miden-node with testing features..."
~/.cargo/bin/cargo install miden-node --locked --features testing

# Verify installation
log "Verifying miden-node installation..."
if ~/.cargo/bin/miden-node --version &>/dev/null; then
    VERSION=$(~/.cargo/bin/miden-node --version)
    log "Miden node installed successfully: $VERSION"
else
    error "Failed to install miden-node"
    exit 1
fi

# Initialize node configuration (FIXED)
log "Initializing Miden node configuration..."
cd "$MIDEN_HOME"
~/.cargo/bin/miden-node init \
    --config-path "$MIDEN_CONFIG_DIR/miden-node.toml" \
    --genesis-path "$MIDEN_CONFIG_DIR/genesis.toml"

if [ $? -ne 0 ]; then
    error "Failed to initialize node configuration"
    exit 1
fi

# Generate genesis block (FIXED - NEW STEP)
log "Generating genesis block..."
~/.cargo/bin/miden-node genesis \
    --genesis-path "$MIDEN_CONFIG_DIR/genesis.toml" \
    --output-path "$MIDEN_DATA_DIR/genesis.dat"

if [ $? -ne 0 ]; then
    error "Failed to generate genesis block"
    exit 1
fi

# Bootstrap the node (FIXED)
log "Bootstrapping Miden node..."
~/.cargo/bin/miden-node bootstrap \
    --config-path "$MIDEN_CONFIG_DIR/miden-node.toml"

if [ $? -eq 0 ]; then
    log "Bootstrap completed successfully!"
else
    error "Bootstrap failed"
    exit 1
fi

# Install grpcurl
log "Installing grpcurl..."
curl -L https://github.com/fullstorydev/grpcurl/releases/download/v1.8.9/grpcurl_1.8.9_linux_x86_64.tar.gz \
    -o /tmp/grpcurl.tar.gz
cd /tmp && tar -xzf grpcurl.tar.gz
chmod +x grpcurl
mv grpcurl /usr/local/bin/
rm -f /tmp/grpcurl.tar.gz

# Create management scripts
log "Creating management scripts..."

# Start script (FIXED)
cat > /root/start_miden.sh << 'SCRIPT'
#!/bin/bash
source ~/.cargo/env
cd /root/miden

# Check if already running
if [ -f miden-node.pid ]; then
    PID=$(cat miden-node.pid)
    if kill -0 $PID 2>/dev/null; then
        echo "❌ Miden Node already running with PID: $PID"
        exit 1
    else
        rm miden-node.pid
    fi
fi

echo "Starting Miden Node..."
nohup ~/.cargo/bin/miden-node start \
    --config "$PWD/config/miden-node.toml" \
    > logs/miden-node.log 2>&1 &

echo $! > miden-node.pid
sleep 2

# Verify it started
if kill -0 $(cat miden-node.pid) 2>/dev/null; then
    echo "✅ Miden Node started with PID: $(cat miden-node.pid)"
    echo "📁 Log file: $PWD/logs/miden-node.log"
    echo "🌐 RPC endpoint: http://0.0.0.0:26657"
else
    echo "❌ Failed to start Miden Node"
    rm miden-node.pid
    exit 1
fi
SCRIPT

# Stop script
cat > /root/stop_miden.sh << 'SCRIPT'
#!/bin/bash
cd /root/miden

if [ -f miden-node.pid ]; then
    PID=$(cat miden-node.pid)
    if kill -0 $PID 2>/dev/null; then
        echo "Stopping Miden Node (PID: $PID)..."
        kill $PID
        sleep 5
        if kill -0 $PID 2>/dev/null; then
            echo "Force killing..."
            kill -9 $PID
        fi
        rm miden-node.pid
        echo "✅ Miden Node stopped"
    else
        echo "❌ Process not running"
        rm miden-node.pid
    fi
else
    echo "❌ PID file not found"
fi
SCRIPT

# Status script (enhanced)
cat > /root/status_miden.sh << 'SCRIPT'
#!/bin/bash
cd /root/miden

echo "=== MIDEN NODE STATUS ==="

if [ -f miden-node.pid ]; then
    PID=$(cat miden-node.pid)
    if kill -0 $PID 2>/dev/null; then
        echo "✅ Status: RUNNING (PID: $PID)"
        echo "📊 Memory: $(ps -o rss --no-headers -p $PID | tr -d ' ') KB"
        echo "⏰ Uptime: $(ps -o etime --no-headers -p $PID | tr -d ' ')"
        
        # Latest block from logs
        if [ -f logs/miden-node.log ]; then
            LATEST_BLOCK=$(grep -o "block.*[0-9]" logs/miden-node.log | tail -1 2>/dev/null || echo "No block info")
            echo "🏗️ Latest: $LATEST_BLOCK"
        fi
        
        # Network ports
        echo "🌐 Listening ports:"
        ss -tlnp | grep $PID 2>/dev/null | while read line; do
            PORT=$(echo "$line" | awk '{print $4}' | cut -d':' -f2)
            echo "   Port $PORT: LISTENING"
        done
    else
        echo "❌ Status: NOT RUNNING"
        rm miden-node.pid
    fi
else
    echo "❌ Status: NOT RUNNING"
fi

# RPC test
echo ""
echo "🔍 RPC Test:"
if timeout 3 curl -s http://localhost:26657 > /dev/null 2>&1; then
    echo "✅ RPC accessible"
else
    echo "❌ RPC not accessible"
fi

# Show recent logs
echo ""
echo "📋 Recent logs:"
if [ -f logs/miden-node.log ]; then
    tail -5 logs/miden-node.log 2>/dev/null || echo "No logs available"
else
    echo "Log file not found"
fi
SCRIPT

# Restart script
cat > /root/restart_miden.sh << 'SCRIPT'
#!/bin/bash
echo "Restarting Miden Node..."
/root/stop_miden.sh
sleep 3
/root/start_miden.sh
SCRIPT

# Client script (improved error handling)
cat > /root/miden_client.sh << 'SCRIPT'
#!/bin/bash
RPC_URL="localhost:26657"
SERVICE="rpc.Api"

show_help() {
    echo "🚀 Miden Node Client"
    echo "Usage: $0 <command> [args]"
    echo ""
    echo "Commands:"
    echo "  latest                 - Get latest block"
    echo "  block <num>           - Get block by number"
    echo "  status                - Get node status"
    echo "  methods               - List all methods"
    echo "  services              - List gRPC services"
    echo "  help                  - Show this help"
}

# Check if grpcurl is available
if ! command -v grpcurl &> /dev/null; then
    echo "❌ grpcurl not found. Please install it first."
    exit 1
fi

# Check if RPC is accessible
if ! timeout 3 curl -s http://$RPC_URL > /dev/null 2>&1; then
    echo "❌ RPC not accessible at $RPC_URL"
    exit 1
fi

case "$1" in
    "latest")
        grpcurl -plaintext -d '{}' $RPC_URL $SERVICE/GetBlockHeaderByNumber 2>/dev/null || echo "❌ Failed to get latest block"
        ;;
    "block")
        if [ -z "$2" ]; then
            echo "Usage: $0 block <number>"
            exit 1
        fi
        grpcurl -plaintext -d "{\"block_num\": $2}" $RPC_URL $SERVICE/GetBlockHeaderByNumber 2>/dev/null || echo "❌ Failed to get block $2"
        ;;
    "status")
        grpcurl -plaintext -d '{}' $RPC_URL $SERVICE/Status 2>/dev/null || echo "❌ Failed to get status"
        ;;
    "methods")
        grpcurl -plaintext $RPC_URL list $SERVICE 2>/dev/null || echo "❌ Failed to list methods"
        ;;
    "services")
        grpcurl -plaintext $RPC_URL list 2>/dev/null || echo "❌ Failed to list services"
        ;;
    "help"|""|*)
        show_help
        ;;
esac
SCRIPT

# Main management script
cat > /root/miden.sh << 'SCRIPT'
#!/bin/bash
# Miden Node Management Script

show_help() {
    echo "🚀 Miden Node Manager"
    echo "Usage: $0 <command>"
    echo ""
    echo "Node Management:"
    echo "  start         - Start the node"
    echo "  stop          - Stop the node"
    echo "  restart       - Restart the node"
    echo "  status        - Check status"
    echo "  logs          - View logs"
    echo ""
    echo "API Client:"
    echo "  latest        - Get latest block"
    echo "  block <num>   - Get block by number"
    echo "  rpc-status    - Get RPC status"
    echo "  methods       - List API methods"
    echo ""
    echo "Utilities:"
    echo "  faucet        - Show faucet key"
    echo "  backup        - Backup node data"
    echo "  reset         - Reset and reinitialize"
    echo "  version       - Show node version"
}

case "$1" in
    "start")
        /root/start_miden.sh
        ;;
    "stop")
        /root/stop_miden.sh
        ;;
    "restart")
        /root/restart_miden.sh
        ;;
    "status")
        /root/status_miden.sh
        ;;
    "logs")
        if [ -f /root/miden/logs/miden-node.log ]; then
            tail -f /root/miden/logs/miden-node.log
        else
            echo "❌ Log file not found"
        fi
        ;;
    "latest")
        /root/miden_client.sh latest
        ;;
    "block")
        /root/miden_client.sh block "$2"
        ;;
    "rpc-status")
        /root/miden_client.sh status
        ;;
    "methods")
        /root/miden_client.sh methods
        ;;
    "faucet")
        echo "🚰 Faucet Key:"
        if [ -f /root/miden/accounts/faucet_miden.mac ]; then
            cat /root/miden/accounts/faucet_miden.mac
        else
            echo "❌ Faucet key not found"
        fi
        ;;
    "backup")
        BACKUP_FILE="/root/miden_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
        if tar -czf "$BACKUP_FILE" -C /root miden/ 2>/dev/null; then
            echo "✅ Backup created: $BACKUP_FILE"
        else
            echo "❌ Backup failed"
        fi
        ;;
    "reset")
        /root/stop_miden.sh
        cd /root/miden
        rm -rf data/* accounts/* logs/* config/*
        echo "🔄 Reinitializing..."
        ~/.cargo/bin/miden-node init --config-path config/miden-node.toml --genesis-path config/genesis.toml
        ~/.cargo/bin/miden-node genesis --genesis-path config/genesis.toml --output-path data/genesis.dat
        ~/.cargo/bin/miden-node bootstrap --config-path config/miden-node.toml
        echo "✅ Node reset and reinitialized"
        ;;
    "version")
        ~/.cargo/bin/miden-node --version
        ;;
    *)
        show_help
        ;;
esac
SCRIPT

# Make scripts executable
chmod +x /root/*.sh

# Configure firewall
log "Configuring firewall..."
ufw --force enable
ufw allow ssh
ufw allow 26657/tcp comment "Miden RPC"

# Create systemd service (FIXED)
log "Creating systemd service..."
cat > /etc/systemd/system/miden-node.service << 'SERVICE'
[Unit]
Description=Miden Node Operator
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/root/miden
Environment=PATH=/root/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=/root/.cargo/bin/miden-node start --config /root/miden/config/miden-node.toml
Restart=always
RestartSec=10
LimitNOFILE=65535

StandardOutput=journal
StandardError=journal
SyslogIdentifier=miden-node

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable miden-node

# Final setup
log "Final setup..."
echo 'export PATH="/root/.cargo/bin:$PATH"' >> ~/.bashrc
echo 'alias miden="/root/miden.sh"' >> ~/.bashrc

# Create log rotation
cat > /etc/logrotate.d/miden-node << 'LOGROTATE'
/root/miden/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 0644 root root
    postrotate
        if [ -f /root/miden/miden-node.pid ]; then
            kill -USR1 $(cat /root/miden/miden-node.pid) 2>/dev/null || true
        fi
    endscript
}
LOGROTATE

log "Installation completed successfully!"
echo ""
echo -e "${BLUE}=== MIDEN NODE INSTALLATION COMPLETE ===${NC}"
echo ""
echo -e "${GREEN}Quick Commands:${NC}"
echo "  miden start          - Start node"
echo "  miden status         - Check status"
echo "  miden latest         - Get latest block"
echo "  miden logs           - View logs"
echo ""
echo -e "${GREEN}Alternative:${NC}"
echo "  /root/miden.sh start"
echo "  /root/status_miden.sh"
echo "  /root/miden_client.sh latest"
echo ""
echo -e "${GREEN}Systemd Service:${NC}"
echo "  systemctl start miden-node"
echo "  systemctl status miden-node"
echo ""
echo -e "${GREEN}Files Location:${NC}"
echo "  Data: /root/miden/data/"
echo "  Accounts: /root/miden/accounts/"
echo "  Config: /root/miden/config/"
echo "  Logs: /root/miden/logs/"
echo ""
echo -e "${YELLOW}Important:${NC} Backup your faucet key!"
echo "  miden faucet"
echo ""
echo -e "${GREEN}To start using:${NC}"
echo "  source ~/.bashrc"
echo "  miden start"
echo ""
echo -e "${YELLOW}Note:${NC} Check the logs if the node fails to start:"
echo "  miden logs"
echo ""