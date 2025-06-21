#!/bin/bash

# Install OpenZeppelin contracts
echo "Installing OpenZeppelin contracts..."
forge install OpenZeppelin/openzeppelin-contracts --no-commit

# Install forge-std if not already present
echo "Installing forge-std..."
forge install foundry-rs/forge-std --no-commit

echo "Dependencies installed successfully!"
echo "You can now run: forge build"