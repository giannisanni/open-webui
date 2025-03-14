#!/bin/bash

# Define color and formatting codes
BOLD='\033[1m'
GREEN='\033[1;32m'
WHITE='\033[1;37m'
RED='\033[0;31m'
NC='\033[0m' # No Color
# Unicode character for tick mark
TICK='\u2713'

# Detect GPU driver
get_gpu_driver() {
    # Check if lspci is available
    if command -v lspci >/dev/null 2>&1; then
        # Detect NVIDIA GPUs using lspci or nvidia-smi
        if lspci | grep -i nvidia >/dev/null || nvidia-smi >/dev/null 2>&1; then
            echo "nvidia"
            return
        fi

        # Detect AMD GPUs (including GCN architecture check for amdgpu vs radeon)
        if lspci | grep -i amd >/dev/null; then
            # List of known GCN and later architecture cards
            # This is a simplified list, and in a real-world scenario, you'd want a more comprehensive one
            local gcn_and_later=("Radeon HD 7000" "Radeon HD 8000" "Radeon R5" "Radeon R7" "Radeon R9" "Radeon RX")

            # Get GPU information
            local gpu_info=$(lspci | grep -i 'vga.*amd')

            for model in "${gcn_and_later[@]}"; do
                if echo "$gpu_info" | grep -iq "$model"; then
                    echo "amdgpu"
                    return
                fi
            done

            # Default to radeon if no GCN or later architecture is detected
            echo "radeon"
            return
        fi

        # Detect Intel GPUs
        if lspci | grep -i intel >/dev/null; then
            echo "i915"
            return
        fi
    else
        # macOS-specific detection
        if [ "$(uname)" == "Darwin" ]; then
            # Check for NVIDIA GPU
            if system_profiler SPDisplaysDataType 2>/dev/null | grep -i nvidia >/dev/null; then
                echo "nvidia"
                return
            fi
            
            # Check for AMD GPU
            if system_profiler SPDisplaysDataType 2>/dev/null | grep -i amd >/dev/null; then
                echo "amdgpu"
                return
            fi
            
            # Default to CPU for macOS (most likely Intel or Apple Silicon)
            echo "cpu"
            return
        fi
        
        # Try nvidia-smi directly as a fallback
        if command -v nvidia-smi >/dev/null 2>&1; then
            echo "nvidia"
            return
        fi
    fi

    # If no known GPU is detected
    echo "cpu"
    return 0
}

# Set GPU driver and count
export OLLAMA_GPU_DRIVER=$(get_gpu_driver)
# Only set GPU count if we have a GPU
if [ "$OLLAMA_GPU_DRIVER" != "cpu" ]; then
    export OLLAMA_GPU_COUNT=1
else
    # Remove GPU configuration if no GPU is detected
    if [ "$(uname)" == "Darwin" ]; then
        # macOS version of sed requires space after -i
        sed -i '' '/deploy:/d; /resources:/d; /reservations:/d; /devices:/d; /driver:/d; /count:/d; /capabilities:/d; /- gpu/d' docker-compose.local-ollama.yaml 2>/dev/null || true
    else
        # Linux version of sed
        sed -i '/deploy:/d; /resources:/d; /reservations:/d; /devices:/d; /driver:/d; /count:/d; /capabilities:/d; /- gpu/d' docker-compose.local-ollama.yaml 2>/dev/null || true
    fi
fi

# Check if Ollama is running
if ! curl -s http://100.92.237.90:11434/api/version > /dev/null; then
    echo -e "${RED}${BOLD}Error: Ollama is not running on 100.92.237.90:11434${NC}"
    echo -e "Please make sure Ollama is running before starting Open WebUI"
    exit 1
fi

echo -e "${WHITE}${BOLD}Current Setup:${NC}"
echo -e "   ${GREEN}${BOLD}GPU Driver:${NC} ${OLLAMA_GPU_DRIVER}"
echo -e "   ${GREEN}${BOLD}GPU Count:${NC} ${OLLAMA_GPU_COUNT}"
echo -e "   ${GREEN}${BOLD}Ollama URL:${NC} $(grep OLLAMA_BASE_URL .env | cut -d= -f2)"
echo -e "   ${GREEN}${BOLD}WebUI Port:${NC} $(grep OPEN_WEBUI_PORT .env | cut -d= -f2 || echo 3000)"
echo

# Run docker-compose with our custom configuration
echo -e "${WHITE}${BOLD}Starting Open WebUI with local Ollama...${NC}"
# Set NODE_OPTIONS to increase memory limit for Node.js during build
export NODE_OPTIONS="--max-old-space-size=8192"
docker compose -f docker-compose.local-ollama.yaml up -d --build

echo
if [ $? -eq 0 ]; then
    echo -e "${GREEN}${BOLD}Open WebUI started successfully.${NC}"
    echo -e "You can access it at http://localhost:$(grep OPEN_WEBUI_PORT .env | cut -d= -f2 || echo 3000)"
else
    echo -e "${RED}${BOLD}There was an error starting Open WebUI.${NC}"
fi
