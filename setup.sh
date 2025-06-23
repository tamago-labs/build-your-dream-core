#!/bin/bash

echo "🚀 Setting up RWA Platform..."


# Install dependencies
echo "📦 Installing OpenZeppelin contracts..."
forge install OpenZeppelin/openzeppelin-contracts --no-commit

echo "📦 Installing forge-std..."
forge install foundry-rs/forge-std --no-commit

# Build contracts
echo "🔨 Building contracts..."
forge build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo ""
    echo "🧪 Run tests with:"
    echo "forge test --fork-url https://api.avax.network/ext/bc/C/rpc -vvv"
    echo ""
    echo "🚀 Deploy to testnet with:"
    echo "forge script script/DeployRWA.s.sol --rpc-url https://api.avax-test.network/ext/bc/C/rpc --private-key \$PRIVATE_KEY --broadcast"
else
    echo "❌ Build failed! Check errors above."
    exit 1
fi