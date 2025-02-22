#!/bin/bash

# Create deployments directory if it doesn't exist
mkdir -p deployments

# Deploy mocks and save the addresses
# forge script script/01_DeployMocks.s.sol --rpc-url base_sepolia --broadcast

# Copy files to uniswap directory


# Execute deploy.sh script
cd ../deploy-uniswap-v3
./deploy.sh


# Copy deployment files back
if [ "$(ls -A deployments/)" ]; then
    rsync -av --progress deployments/ ../easy-farmly-contracts/deployments/
    sleep 1
else
    echo "Error: No files found in deploy-uniswap-v3/deployments directory"
    exit 1
fi

# Return to original directory
cd ../easy-farmly-contracts

# forge script script/04_CreatePool.s.sol --rpc-url local --broadcast -vvvvv

# Run tests
forge test -vvv --rpc-url local