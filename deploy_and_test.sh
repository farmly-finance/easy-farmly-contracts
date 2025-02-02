#!/bin/bash

# Deploy mocks
forge script script/01_DeployMocks.s.sol --rpc-url local --broadcast

# Deploy Uniswap V3 Factory
forge script script/02_DeployUniFactory.s.sol --rpc-url local --broadcast

# Deploy Nonfungible Position Manager
forge script script/03_DeployNonfungiblePositionManager.s.sol --rpc-url local --broadcast

# Run tests
forge test -vvv --rpc-url local 