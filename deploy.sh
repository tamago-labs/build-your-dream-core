#!/bin/bash

# RWA Modular Framework Deployment Guide - Avalanche Fuji Testnet
echo "RWA Modular Framework Deployment - Avalanche Fuji Testnet"
echo "=========================================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

# Check if .env exists
if [ ! -f ".env" ]; then
    error ".env file not found!"
    echo "Copy .env.example to .env and configure:"
    echo "   cp .env.example .env"
    echo "   # Edit .env with your PRIVATE_KEY and SNOWTRACE_API_KEY"
    exit 1
fi

# Source environment variables
source .env

# Check required variables
if [ -z "$PRIVATE_KEY" ]; then
    error "PRIVATE_KEY not set in .env"
fi

if [ -z "$FUJI_RPC_URL" ]; then
    export FUJI_RPC_URL="https://api.avax-test.network/ext/bc/C/rpc"
    warning "FUJI_RPC_URL not set, using default: $FUJI_RPC_URL"
fi

# Set Avalanche Fuji testnet configuration
RPC_URL=$FUJI_RPC_URL
NETWORK="fuji"
CHAIN_ID="43113"

info "Deploying Modular RWA Framework to Avalanche Fuji Testnet"
echo "RPC URL: $RPC_URL"
echo "Chain ID: $CHAIN_ID"
echo "Explorer: https://testnet.snowtrace.io/"

# Check if deployer has AVAX
DEPLOYER_ADDRESS=$(cast wallet address --private-key $PRIVATE_KEY)
BALANCE=$(cast balance $DEPLOYER_ADDRESS --rpc-url $RPC_URL)
BALANCE_AVAX=$(cast to-unit $BALANCE ether)

echo "Deployer: $DEPLOYER_ADDRESS"
echo "Balance: $BALANCE_AVAX AVAX"

# Check minimum balance (need at least 1.5 AVAX for modular deployment)
MIN_BALANCE="1500000000000000000" # 1.5 AVAX in wei
if [ "$(echo "$BALANCE < $MIN_BALANCE" | bc -l)" = 1 ]; then
    error "Insufficient AVAX balance!"
    echo "Current: $BALANCE_AVAX AVAX"
    echo "Required: At least 1.5 AVAX (modular deployment needs more gas)"
    echo "Get testnet AVAX from: https://faucet.avax.network/"
    exit 1
fi

success "Sufficient AVAX balance for modular deployment"

# Step 1: Deploy Modular Framework
echo ""
info "Step 1: Deploying Modular RWA Framework..."
echo "============================================="

# Check if verification is possible
VERIFY_FLAG=""
if [ ! -z "$SNOWTRACE_API_KEY" ]; then
    VERIFY_FLAG="--verify --verifier-url https://api.routescan.io/v2/network/testnet/evm/43113/etherscan --etherscan-api-key $SNOWTRACE_API_KEY"
    info "Contract verification enabled"
else
    warning "SNOWTRACE_API_KEY not set - contracts will not be verified"
    echo "   Get API key from: https://snowtrace.io/apis"
fi

info "Deploying specialized factories and coordinator..."

forge script script/DeployModularFramework.s.sol \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --gas-limit 15000000 \
    $VERIFY_FLAG \
    -vvv

if [ $? -ne 0 ]; then
    error "Modular framework deployment failed!"
fi

success "Modular framework deployed successfully on Avalanche Fuji!"

# Extract addresses from deployment
if [ -f "deployment.txt" ]; then
    COORDINATOR_ADDRESS=$(grep "Coordinator:" deployment.txt | cut -d' ' -f2)
    DASHBOARD_ADDRESS=$(grep "Dashboard:" deployment.txt | cut -d' ' -f2)
    TOKEN_FACTORY=$(grep "Token Factory:" deployment.txt | cut -d' ' -f3)
    TRADING_FACTORY=$(grep "Trading Factory:" deployment.txt | cut -d' ' -f3)
    VAULT_FACTORY=$(grep "Vault Factory:" deployment.txt | cut -d' ' -f3)
    
    echo ""
    success "Modular Framework Deployment Addresses:"
    echo "   Coordinator: $COORDINATOR_ADDRESS"
    echo "   Dashboard: $DASHBOARD_ADDRESS"
    echo "   Token Factory: $TOKEN_FACTORY"
    echo "   Trading Factory: $TRADING_FACTORY"
    echo "   Vault Factory: $VAULT_FACTORY"
    echo "   View on Snowtrace: https://testnet.snowtrace.io/address/$COORDINATOR_ADDRESS"
    
    # Update .env file with new addresses
    if grep -q "COORDINATOR_ADDRESS=" .env; then
        sed -i "s/COORDINATOR_ADDRESS=.*/COORDINATOR_ADDRESS=$COORDINATOR_ADDRESS/" .env
    else
        echo "COORDINATOR_ADDRESS=$COORDINATOR_ADDRESS" >> .env
    fi
    
    # Backward compatibility - set FACTORY_ADDRESS to coordinator
    if grep -q "FACTORY_ADDRESS=" .env; then
        sed -i "s/FACTORY_ADDRESS=.*/FACTORY_ADDRESS=$COORDINATOR_ADDRESS/" .env
    else
        echo "FACTORY_ADDRESS=$COORDINATOR_ADDRESS" >> .env
    fi
    
    if grep -q "DASHBOARD_ADDRESS=" .env; then
        sed -i "s/DASHBOARD_ADDRESS=.*/DASHBOARD_ADDRESS=$DASHBOARD_ADDRESS/" .env
    else
        echo "DASHBOARD_ADDRESS=$DASHBOARD_ADDRESS" >> .env
    fi
    
    # Add factory addresses
    if [ ! -z "$TOKEN_FACTORY" ]; then
        if grep -q "TOKEN_FACTORY_ADDRESS=" .env; then
            sed -i "s/TOKEN_FACTORY_ADDRESS=.*/TOKEN_FACTORY_ADDRESS=$TOKEN_FACTORY/" .env
        else
            echo "TOKEN_FACTORY_ADDRESS=$TOKEN_FACTORY" >> .env
        fi
    fi
    
    if [ ! -z "$TRADING_FACTORY" ]; then
        if grep -q "TRADING_FACTORY_ADDRESS=" .env; then
            sed -i "s/TRADING_FACTORY_ADDRESS=.*/TRADING_FACTORY_ADDRESS=$TRADING_FACTORY/" .env
        else
            echo "TRADING_FACTORY_ADDRESS=$TRADING_FACTORY" >> .env
        fi
    fi
    
    if [ ! -z "$VAULT_FACTORY" ]; then
        if grep -q "VAULT_FACTORY_ADDRESS=" .env; then
            sed -i "s/VAULT_FACTORY_ADDRESS=.*/VAULT_FACTORY_ADDRESS=$VAULT_FACTORY/" .env
        else
            echo "VAULT_FACTORY_ADDRESS=$VAULT_FACTORY" >> .env
        fi
    fi
    
    success "Updated .env with modular framework addresses"
else
    warning "deployment.txt not found - addresses not saved to .env"
fi

# Step 2: Create Sample Project (Optional)
echo ""
read -p "Create a sample RWA project using modular framework? (y/n): " create_project

if [ "$create_project" = "y" ] || [ "$create_project" = "Y" ]; then
    echo ""
    info "Step 2: Creating Sample Project with Modular Framework..."
    echo "========================================================"
    
    forge script script/CreateProjectModular.s.sol \
        --rpc-url $RPC_URL \
        --private-key $PRIVATE_KEY \
        --gas-limit 15000000 \
        --broadcast \
        -vvv
    
    if [ $? -eq 0 ]; then
        success "Sample project created successfully with modular framework!"
        
        if [ -f "project.txt" ]; then
            PROJECT_ID=$(grep "Project ID:" project.txt | cut -d' ' -f3)
            echo "Project ID: $PROJECT_ID"
            
            # Update .env with project ID
            if grep -q "PROJECT_ID=" .env; then
                sed -i "s/PROJECT_ID=.*/PROJECT_ID=$PROJECT_ID/" .env
            else
                echo "PROJECT_ID=$PROJECT_ID" >> .env
            fi
            
            success "Updated .env with project ID"
            
            # Show project contracts on explorer
            if [ ! -z "$COORDINATOR_ADDRESS" ]; then
                echo ""
                info "Project contracts deployed:"
                # Extract addresses from project.txt
                TOKEN_ADDR=$(grep "Token:" project.txt | cut -d' ' -f2)
                PRIMARY_SALES_ADDR=$(grep "Primary Sales:" project.txt | cut -d' ' -f3)
                RFQ_ADDR=$(grep "RFQ:" project.txt | cut -d' ' -f2)
                VAULT_ADDR=$(grep "Vault:" project.txt | cut -d' ' -f2)
                
                echo "   Token: https://testnet.snowtrace.io/address/$TOKEN_ADDR"
                echo "   Primary Sales: https://testnet.snowtrace.io/address/$PRIMARY_SALES_ADDR"
                echo "   RFQ: https://testnet.snowtrace.io/address/$RFQ_ADDR"
                echo "   Vault: https://testnet.snowtrace.io/address/$VAULT_ADDR"
            fi
        fi
    else
        warning "Sample project creation failed - you can create one later"
    fi
fi

# Final summary
echo ""
echo "=========================================="
success "Modular RWA Framework Deployment Complete!"
echo "=========================================="
success "Modular Framework deployed to Avalanche Fuji Testnet"
success "All addresses saved to .env file"
echo "Deployment details in deployment.txt"
echo "Chain ID: 43113"
echo "Explorer: https://testnet.snowtrace.io/"

if [ -f "project.txt" ]; then
    echo "Project details in project.txt"
fi

echo ""
info "Modular Architecture Benefits:"
echo "=============================="
echo "✅ No contract size limitations"
echo "✅ Clean separation of concerns"
echo "✅ Easy component upgrades"
echo "✅ Better maintainability"
echo "✅ Focused factory contracts"

echo ""
info "Available Scripts (Updated for Modular):"
echo "========================================"
echo "• CreateProjectModular.s.sol  - Create new RWA projects"
echo "• ViewProjects.s.sol          - View all projects and stats"
echo "• ManageProject.s.sol         - Manage existing projects"

echo ""
info "Usage Examples:"
echo "==============="
echo "# Create new project (modular)"
echo "forge script script/CreateProjectModular.s.sol --rpc-url \$FUJI_RPC_URL --private-key \$PRIVATE_KEY --broadcast"
echo ""
echo "# View all projects"
echo "forge script script/ViewProjects.s.sol --rpc-url \$FUJI_RPC_URL"


echo ""
info "Testnet Resources:"
echo "=================="
echo "• Get testnet AVAX: https://faucet.avax.network/"
echo "• Explorer: https://testnet.snowtrace.io/"
echo "• Documentation: MODULAR_README.md"

echo ""
success "Your Modular RWA Framework is ready on Avalanche! 🎉"
echo "No more contract size issues - enjoy unlimited scalability!"
