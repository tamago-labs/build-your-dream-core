#!/bin/bash

# RWA Framework Deployment Guide
echo "🏗️  RWA Framework Deployment Guide"
echo "===================================="

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "❌ .env file not found!"
    echo "📋 Copy .env.example to .env and configure:"
    echo "   cp .env.example .env"
    echo "   # Edit .env with your PRIVATE_KEY and RPC URLs"
    exit 1
fi

# Source environment variables
source .env

# Check required variables
if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ PRIVATE_KEY not set in .env"
    exit 1
fi

if [ -z "$SEPOLIA_RPC_URL" ] && [ -z "$MAINNET_RPC_URL" ]; then
    echo "❌ No RPC URL set in .env"
    echo "📋 Set either SEPOLIA_RPC_URL or MAINNET_RPC_URL"
    exit 1
fi

# Network selection
echo "🌐 Select network:"
echo "1) Sepolia Testnet"
echo "2) Ethereum Mainnet"
echo "3) Custom RPC"
read -p "Enter choice (1-3): " network_choice

case $network_choice in
    1)
        RPC_URL=$SEPOLIA_RPC_URL
        NETWORK="sepolia"
        ;;
    2)
        RPC_URL=$MAINNET_RPC_URL
        NETWORK="mainnet"
        echo "⚠️  WARNING: Deploying to MAINNET! This will cost real ETH."
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            echo "❌ Deployment cancelled"
            exit 1
        fi
        ;;
    3)
        read -p "Enter custom RPC URL: " RPC_URL
        NETWORK="custom"
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

if [ -z "$RPC_URL" ]; then
    echo "❌ RPC URL not configured for selected network"
    exit 1
fi

echo "🚀 Deploying to: $NETWORK"
echo "📡 RPC URL: $RPC_URL"

# Step 1: Deploy Framework
echo ""
echo "📦 Step 1: Deploying RWA Framework..."
echo "======================================"

forge script script/DeployFramework.s.sol \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    -vvv

if [ $? -ne 0 ]; then
    echo "❌ Framework deployment failed!"
    exit 1
fi

echo "✅ Framework deployed successfully!"

# Extract addresses from deployment
if [ -f "deployment.txt" ]; then
    FACTORY_ADDRESS=$(grep "Factory:" deployment.txt | cut -d' ' -f2)
    DASHBOARD_ADDRESS=$(grep "Dashboard:" deployment.txt | cut -d' ' -f2)
    
    echo "📝 Deployment addresses:"
    echo "   Factory: $FACTORY_ADDRESS"
    echo "   Dashboard: $DASHBOARD_ADDRESS"
    
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
    
    echo "✅ Updated .env with deployment addresses"
fi

# Step 2: Create Sample Project (Optional)
echo ""
read -p "🏠 Create a sample project? (y/n): " create_project

if [ "$create_project" = "y" ] || [ "$create_project" = "Y" ]; then
    echo ""
    echo "🏗️  Step 2: Creating Sample Project..."
    echo "======================================"
    
    forge script script/CreateProject.s.sol \
        --rpc-url $RPC_URL \
        --private-key $PRIVATE_KEY \
        --broadcast \
        -vvv
    
    if [ $? -eq 0 ]; then
        echo "✅ Sample project created successfully!"
        
        if [ -f "project.txt" ]; then
            PROJECT_ID=$(grep "Project ID:" project.txt | cut -d' ' -f3)
            echo "📝 Project ID: $PROJECT_ID"
            
            # Update .env with project ID
            if grep -q "PROJECT_ID=" .env; then
                sed -i "s/PROJECT_ID=.*/PROJECT_ID=$PROJECT_ID/" .env
            else
                echo "PROJECT_ID=$PROJECT_ID" >> .env
            fi
            
            echo "✅ Updated .env with project ID"
        fi
    else
        echo "❌ Sample project creation failed!"
    fi
fi

# Final summary
echo ""
echo "🎉 Deployment Complete!"
echo "======================="
echo "✅ RWA Framework deployed to $NETWORK"
echo "✅ Addresses saved to .env"
echo "📄 Deployment details in deployment.txt"

if [ -f "project.txt" ]; then
    echo "📄 Project details in project.txt"
fi

echo ""
echo "🔧 Available Scripts:"
echo "===================="
echo "• ViewProjects.s.sol   - View all projects and stats"
echo "• CreateProject.s.sol  - Create new RWA projects"
echo "• ManageProject.s.sol  - Manage existing projects"

echo ""
echo "📚 Usage Examples:"
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
echo "🌟 Your RWA Framework is ready for production!"
