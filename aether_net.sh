chmod +x ~/Projects/AetherQuanta/Aether-Quanta-Project-/aether_net.sh#!/data/data/com.termux/files/usr/bin/bash

# aether_net.sh - Secure network and deploy AetherNet for /GoldenGravity with optional Tor
# Commander Marco, 2025-07-03

# Constants
LOG_FILE="$HOME/Projects/AetherQuanta/Aether-Quanta-Project-/network_log.txt"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
XAI_HOST="8.8.8.8" # Google DNS for reliable ping
AETHER_NET_DIR="$HOME/Projects/AetherQuanta/Aether-Quanta-Project-"
ANALYZER_SCRIPT="$AETHER_NET_DIR/pi_phi_delta_analyzer.py"
IMAGE_PATH="$AETHER_NET_DIR/knife2.jpg"
DEPLOY_SCRIPT="$AETHER_NET_DIR/scripts/deploy.js"
CONTRACT_PATH="$AETHER_NET_DIR/contracts/AetherNet.sol"
USE_TOR="true" # Set to "true" for Tor routing (requires tor and torsocks)

# Ensure directories exist
mkdir -p "$AETHER_NET_DIR"
mkdir -p "$AETHER_NET_DIR/scripts"
mkdir -p "$AETHER_NET_DIR/contracts"
mkdir -p "$HOME/AetherCrypto/annotated_results"

# Function to log messages
log_message() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
}

# Check if Termux:API is installed
if ! command -v termux-wifi-enable >/dev/null 2>&1; then
    log_message "Error: Termux:API not installed. Run 'pkg install termux-api'."
    termux-toast -g bottom "Error: Install Termux:API with 'pkg install termux-api'"
    exit 1
fi

# Check if Hardhat and dependencies are installed
if ! command -v npx >/dev/null 2>&1 || ! npx hardhat --version >/dev/null 2>&1; then
    log_message "Error: Hardhat not installed or misconfigured. Run 'npm install -g hardhat' and 'npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox @nomicfoundation/solidity-analyzer' in $AETHER_NET_DIR."
    termux-toast -g bottom "Error: Hardhat not found"
    exit 1
fi

# Check environment variables
if [ -z "$INFURA_URL" ] || [ -z "$PRIVATE_KEY" ]; then
    log_message "Error: INFURA_URL or PRIVATE_KEY not set. Export them in ~/.bashrc."
    termux-toast -g bottom "Error: Missing INFURA_URL or PRIVATE_KEY"
    exit 1
fi

# Check Tor setup if enabled
if [ "$USE_TOR" = "true" ]; then
    if ! command -v tor >/dev/null 2>&1 || ! command -v torsocks >/dev/null 2>&1; then
        log_message "Error: Tor or torsocks not installed. Run 'pkg install tor torsocks'."
        termux-toast -g bottom "Error: Install tor and torsocks"
        exit 1
    fi
    if ! pgrep tor >/dev/null; then
        log_message "Starting Tor service..."
        tor &
        sleep 10
        if ! pgrep tor >/dev/null; then
            log_message "Error: Failed to start Tor service."
            termux-toast -g bottom "Error: Tor failed to start"
            exit 1
        fi
    fi
    log_message "Tor enabled for anonymous routing."
fi

# Check Wi-Fi status
log_message "Checking Wi-Fi status..."
if termux-wifi-connectioninfo | grep -q '"supplicant_state": "COMPLETED"'; then
    log_message "Wi-Fi is enabled and connected (SSID: $(termux-wifi-connectioninfo | grep '"ssid":' | awk -F'"' '{print $4}'), RSSI: $(termux-wifi-connectioninfo | grep '"rssi":' | awk '{print $2}' | tr -d ','))."
    termux-toast -g bottom "Wi-Fi enabled and connected"
else
    log_message "Wi-Fi not connected. Attempting to enable and connect..."
    termux-wifi-enable true
    sleep 10
    if termux-wifi-connectioninfo | grep -q '"supplicant_state": "COMPLETED"'; then
        log_message "Wi-Fi enabled and connected successfully (SSID: $(termux-wifi-connectioninfo | grep '"ssid":' | awk -F'"' '{print $4}'), RSSI: $(termux-wifi-connectioninfo | grep '"rssi":' | awk '{print $2}' | tr -d ','))."
        termux-toast -g bottom "Wi-Fi enabled"
    else
        log_message "Error: Failed to enable Wi-Fi or connect after retry."
        termux-toast -g bottom "Error: Could not enable Wi-Fi or connect"
        exit 1
    fi
fi

# Check network connectivity with retry
log_message "Pinging $XAI_HOST to verify connectivity..."
for attempt in {1..3}; do
    if [ "$USE_TOR" = "true" ]; then
        if torsocks ping -c 4 "$XAI_HOST" >/dev/null 2>&1; then
            log_message "Network is up. Internet connectivity confirmed via Tor (ping $XAI_HOST successful)."
            termux-toast -g bottom "Network secure via Tor"
            break
        fi
    else
        if ping -c 4 "$XAI_HOST" >/dev/null 2>&1; then
            log_message "Network is up. Internet connectivity confirmed (ping $XAI_HOST successful)."
            termux-toast -g bottom "Network secure: Internet reachable"
            break
        fi
    fi
    log_message "Ping attempt $attempt failed for $XAI_HOST."
    if [ "$attempt" -eq 3 ]; then
        log_message "Error: Network is down or Internet unreachable after 3 attempts."
        termux-toast -g bottom "Error: Network down or Internet unreachable"
        exit 1
    fi
    sleep 2
done

# Check for pi_phi_delta_analyzer.py
if [ ! -f "$ANALYZER_SCRIPT" ]; then
    log_message "Error: $ANALYZER_SCRIPT not found. Ensure it's in $AETHER_NET_DIR."
    termux-toast -g bottom "Error: pi_phi_delta_analyzer.py missing"
    exit 1
fi

# Run pi_phi_delta_analyzer.py to get phi_score
log_message "Analyzing $IMAGE_PATH for phi_score..."
if [ -f "$IMAGE_PATH" ]; then
    if python3 "$ANALYZER_SCRIPT" "$IMAGE_PATH" > "$AETHER_NET_DIR/phi_results_knife2.txt" 2>&1; then
        phi_score_raw=$(grep "phi_score" "$AETHER_NET_DIR/phi_results_knife2.txt" | head -n 1 | awk '{print $2}')
        if [ -z "$phi_score_raw" ]; then
            log_message "Warning: Failed to extract phi_score from $IMAGE_PATH analysis. Using default 1.0."
            termux-toast -g bottom "Warning: phi_score extraction failed, using default"
            phi_score_int=1000
        else
            phi_score_int=$(awk "BEGIN {printf \"%d\", ($phi_score_raw * 1000)}")
            log_message "Extracted phi_score: $phi_score_raw (integer for contract: $phi_score_int)"
        fi
    else
        log_message "Error: Failed to run $ANALYZER_SCRIPT on $IMAGE_PATH. Check $AETHER_NET_DIR/phi_results_knife2.txt."
        termux-toast -g bottom "Error: Analysis failed for knife2.jpg"
        cat "$AETHER_NET_DIR/phi_results_knife2.txt" >> "$LOG_FILE"
        exit 1
    fi
else
    log_message "Warning: $IMAGE_PATH not found. Using default phi_score 1.0."
    termux-toast -g bottom "Warning: knife2.jpg not found, using default phi_score"
    phi_score_int=1000
fi

# Check for deploy.js and AetherNet.sol
if [ ! -f "$DEPLOY_SCRIPT" ] || [ ! -f "$CONTRACT_PATH" ]; then
    log_message "Error: Required Hardhat files ($DEPLOY_SCRIPT or $CONTRACT_PATH) not found."
    termux-toast -g bottom "Error: Hardhat files missing"
    exit 1
fi

# Update deploy.js with phi_score
log_message "Updating Hardhat deploy script ($DEPLOY_SCRIPT) with phi_score ($phi_score_int)..."
if ! sed -i "s/const phiScore = [0-9]*/const phiScore = $phi_score_int/" "$DEPLOY_SCRIPT"; then
    log_message "Error: Failed to update $DEPLOY_SCRIPT with phi_score. Ensure 'const phiScore = 1000;' is in deploy.js."
    termux-toast -g bottom "Error: Failed to update deploy.js"
    exit 1
fi

# Deploy AetherNet contract
log_message "Deploying AetherNet smart contract to Sepolia network..."
cd "$AETHER_NET_DIR" || { log_message "Error: Failed to change to $AETHER_NET_DIR"; termux-toast -g bottom "Error: Directory change failed"; exit 1; }
if [ "$USE_TOR" = "true" ]; then
    if torsocks npx hardhat run scripts/deploy.js --network sepolia > "$AETHER_NET_DIR/deploy_output.txt" 2>&1; then
        contract_address=$(grep "AetherNet deployed to:" "$AETHER_NET_DIR/deploy_output.txt" | awk '{print $NF}')
        log_message "AetherNet deployment successful via Tor. Contract address: $contract_address"
        termux-toast -g bottom "AetherNet deployed at $contract_address via Tor"
    else
        log_message "Error: AetherNet deployment failed via Tor. Check $AETHER_NET_DIR/deploy_output.txt."
        termux-toast -g bottom "Error: AetherNet deployment failed via Tor"
        cat "$AETHER_NET_DIR/deploy_output.txt" >> "$LOG_FILE"
        exit 1
    fi
else
    if npx hardhat run scripts/deploy.js --network sepolia > "$AETHER_NET_DIR/deploy_output.txt" 2>&1; then
        contract_address=$(grep "AetherNet deployed to:" "$AETHER_NET_DIR/deploy_output.txt" | awk '{print $NF}')
        log_message "AetherNet deployment successful. Contract address: $contract_address"
        termux-toast -g bottom "AetherNet deployed at $contract_address"
    else
        log_message "Error: AetherNet deployment failed. Check $AETHER_NET_DIR/deploy_output.txt."
        termux-toast -g bottom "Error: AetherNet deployment failed"
        cat "$AETHER_NET_DIR/deploy_output.txt" >> "$LOG_FILE"
        exit 1
    fi
fi

# Log final success
log_message "AetherNet secured for /GoldenGravity. Contract address: $contract_address. Ready to phone Home!"
termux-toast -g bottom "AetherNet secured at $contract_address"

exit 0
