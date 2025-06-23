#!/bin/bash

echo "🏗️  RWA Framework Build Check"
echo "================================"

# Check if we're in the right directory
if [ ! -f "foundry.toml" ]; then
    echo "❌ Not in project root directory"
    exit 1
fi

echo "📦 Installing dependencies..."
forge install --no-commit

echo "🔧 Building contracts..."
forge build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    echo ""
    echo "📊 Contract Summary:"
    echo "==================="
    find src -name "*.sol" -not -path "*/interfaces/*" | wc -l | xargs echo "Core Contracts:"
    find src/interfaces -name "*.sol" | wc -l | xargs echo "Interfaces:"
    find test -name "*.sol" | wc -l | xargs echo "Tests:"
    find script -name "*.sol" | wc -l | xargs echo "Scripts:"
    
    echo ""
    echo "🧪 Running tests..."
    forge test -vv
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "🎉 All systems ready!"
        echo "====================="
        echo "✅ Contracts compiled successfully"
        echo "✅ Tests passing"
        echo "✅ Framework ready for deployment"
        echo ""
        echo "Next steps:"
        echo "1. Copy .env.example to .env and configure"
        echo "2. Run deployment script with your private key"
        echo "3. Create your first RWA project!"
    else
        echo "❌ Tests failed"
        exit 1
    fi
else
    echo "❌ Build failed"
    exit 1
fi