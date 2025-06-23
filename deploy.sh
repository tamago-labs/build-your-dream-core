#!/bin/bash

# RWA Framework Deployment Guide - Avalanche Fuji Testnet
echo "RWA Framework Deployment - Avalanche Fuji Testnet"
echo "=================================================="

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "ERROR: .env file not found!"
    echo "Copy .env.example to .env and configure:"
    echo "   cp .env.example .env"
    echo "   # Edit .env with your PRIVATE_KEY and SNOWTRACE_API_KEY"
    exit 1
fi

# Source environment variables
source .env

# Check required variables
if [ -z "$PRIVATE_KEY" ]; then
    echo "ERROR: PRIVATE_KEY not set in .env"
    exit 1
fi

if [ -z "$FUJI_RPC_URL" ]; then
    echo "ERROR: FUJI_RPC_URL not set in .env"
    echo "Add: FUJI_RPC_URL=https://api.avax-test.network/ext/bc/C/rpc"
    exit 1
fi

# Set Avalanche Fuji testnet configuration
RPC_URL=$FUJI_RPC_URL
NETWORK="fuji"
CHAIN_ID="43113"

echo "Deploying to Avalanche Fuji Testnet"
echo "RPC URL: $RPC_URL"
echo "Chain ID: $CHAIN_ID"
echo "Explorer: https://testnet.snowtrace.io/"

# Check if deployer has AVAX
DEPLOYER_ADDRESS=$(cast wallet address --private-key $PRIVATE_KEY)
BALANCE=$(cast balance $DEPLOYER_ADDRESS --rpc-url $RPC_URL)
BALANCE_AVAX=$(cast to-unit $BALANCE ether)

echo "Deployer: $DEPLOYER_ADDRESS"
echo "Balance: $BALANCE_AVAX AVAX"

# Check minimum balance (need at least 1 AVAX for deployment + gas)
MIN_BALANCE="1000000000000000000" # 1 AVAX in wei
if [ "$(echo "$BALANCE < $MIN_BALANCE" | bc -l)" = 1 ]; then
    echo "ERROR: Insufficient AVAX balance!"
    echo "Current: $BALANCE_AVAX AVAX"
    echo "Required: At least 1 AVAX"
    echo "Get testnet AVAX from: https://faucet.avax.network/"
    exit 1
fi

echo "SUCCESS: Sufficient AVAX balance for deployment"

# Step 1: Deploy Framework
echo ""
echo "Step 1: Deploying RWA Framework to Avalanche Fuji..."
echo "========================================================"

# Check if verification is possible
VERIFY_FLAG=""
if [ ! -z "$SNOWTRACE_API_KEY" ]; then
    VERIFY_FLAG="--verify --verifier-url https://api.routescan.io/v2/network/testnet/evm/43113/etherscan --etherscan-api-key $SNOWTRACE_API_KEY"
    echo "Contract verification enabled"
else
    echo "WARNING: SNOWTRACE_API_KEY not set - contracts will not be verified"
    echo "   Get API key from: https://snowtrace.io/apis"
fi

forge script script/DeployFramework.s.sol \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    $VERIFY_FLAG \
    -vvv

if [ $? -ne 0 ]; then
    echo "ERROR: Framework deployment failed!"
    exit 1
fi

echo "SUCCESS: Framework deployed successfully on Avalanche Fuji!"

# Extract addresses from deployment
if [ -f "deployment.txt" ]; then
    FACTORY_ADDRESS=$(grep "Factory:" deployment.txt | cut -d' ' -f2)
    DASHBOARD_ADDRESS=$(grep "Dashboard:" deployment.txt | cut -d' ' -f2)
    
    echo "Deployment addresses:"
    echo "   Factory: $FACTORY_ADDRESS"
    echo "   Dashboard: $DASHBOARD_ADDRESS"
    echo "   View on Snowtrace: https://testnet.snowtrace.io/address/$FACTORY_ADDRESS"
    
    # Update .env file
    if grep -q "FACTORY_ADDRESS=" .env; then
        sed -i "s/FACTORY_ADDRESS=.*/FACTORY_ADDRESS=$FACTORY_ADDRESS/" .env
    else
        echo "FACTORY_ADDRESS=$FACTORY_ADDRESS" >> .env
    fi
    
    if grep -q "DASHBOARD_ADDRESS=" .env; then
        sed -i "s/DASHBOARD_ADDRESS=.*/DASHBOARD_ADDRESS=$DASHBOARD_ADDRESS/" .env
    else
        echo "DASHBOARD_ADDRESS=$DASHBOARD_ADDRESS" >> .env
    fi
    
    echo "SUCCESS: Updated .env with deployment addresses"
fi

# Step 2: Create Sample Project (Optional)
echo ""
read -p "Create a sample RWA project? (y/n): " create_project

if [ "$create_project" = "y" ] || [ "$create_project" = "Y" ]; then
    echo ""
    echo "Step 2: Creating Sample Project..."
    echo "======================================"
    
    forge script script/CreateProject.s.sol \
        --rpc-url $RPC_URL \
        --private-key $PRIVATE_KEY \
        --broadcast \
        -vvv
    
    if [ $? -eq 0 ]; then
        echo "SUCCESS: Sample project created successfully!"
        
        if [ -f "project.txt" ]; then
            PROJECT_ID=$(grep "Project ID:" project.txt | cut -d' ' -f3)
            echo "Project ID: $PROJECT_ID"
            
            # Update .env with project ID
            if grep -q "PROJECT_ID=" .env; then
                sed -i "s/PROJECT_ID=.*/PROJECT_ID=$PROJECT_ID/" .env
            else
                echo "PROJECT_ID=$PROJECT_ID" >> .env
            fi
            
            echo "SUCCESS: Updated .env with project ID"
            
            # Show project contracts on explorer
            if [ ! -z "$FACTORY_ADDRESS" ]; then
                PROJECT_CONTRACTS=$(forge script script/ViewProjects.s.sol --rpc-url $RPC_URL 2>/dev/null | grep "Token:\|Primary Sales:\|RFQ:\|Vault:" | head -4)
                echo "View project contracts on Snowtrace:"
                echo "$PROJECT_CONTRACTS" | while read line; do
                    ADDRESS=$(echo $line | cut -d' ' -f2)
                    echo "   https://testnet.snowtrace.io/address/$ADDRESS"
                done
            fi
        fi
    else
        echo "ERROR: Sample project creation failed!"
    fi
fi

# Final summary
echo ""
echo "Avalanche Deployment Complete!"
echo "=================================="
echo "SUCCESS: RWA Framework deployed to Avalanche Fuji Testnet"
echo "SUCCESS: Addresses saved to .env"
echo "Deployment details in deployment.txt"
echo "Chain ID: 43113"
echo "Explorer: https://testnet.snowtrace.io/"

if [ -f "project.txt" ]; then
    echo "Project details in project.txt"
fi

echo ""
echo "Available Scripts:"
echo "===================="
echo "• ViewProjects.s.sol   - View all projects and stats"
echo "• CreateProject.s.sol  - Create new RWA projects"
echo "• ManageProject.s.sol  - Manage existing projects"

echo ""
echo "Usage Examples:"
echo "=================="
echo "# View all projects"
echo "forge script script/ViewProjects.s.sol --rpc-url $RPC_URL"
echo ""
echo "# Create new project"
echo "forge script script/CreateProject.s.sol --rpc-url $RPC_URL --private-key \$PRIVATE_KEY --broadcast"
echo ""
echo "# Manage existing project"
echo "PROJECT_ID=1 forge script script/ManageProject.s.sol --rpc-url $RPC_URL --private-key \$PRIVATE_KEY --broadcast"

echo ""
echo "Testnet Faucet:"
echo "=================="
echo "Get testnet AVAX: https://faucet.avax.network/"

echo ""
echo "Your RWA Framework is ready on Avalanche!"