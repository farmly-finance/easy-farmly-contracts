# Easy Farmly Contracts

Farmly Finance is an innovative platform that simplifies liquidity management for DeFi users. With advanced strategies for concentrated liquidity, we enable users to provide liquidity effortlessly with just one click.

## Overview

The project consists of several key components:

- **FarmlyEasyFarm**: The main contract that handles user deposits and automated liquidity management
- **Strategies**: Smart liquidity management strategies (e.g., Bollinger Bands) that optimize liquidity ranges
- **Executors**: Contracts that handle liquidity position management
- **Readers**: Contracts for reading on-chain data and price feeds to inform strategy decisions

## Features

- One-click liquidity provision
- Advanced concentrated liquidity management strategies
- Smart range optimization using Bollinger Bands
- Integration with Uniswap V3 for efficient liquidity management
- Chainlink price feeds for reliable price data
- Chainlink Automation for strategy execution
- Modular architecture allowing new strategies and executors to be added
- Built-in safety features and pausability

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) (for development tools)

## Installation

1. Clone the repository:

```bash
git clone https://github.com/farmly-finance/easy-farmly-contracts.git
cd easy-farmly-contracts
```

2. Install dependencies:

```bash
forge install
```

3. Create a `.env` file with required environment variables:

```
SEPOLIA_RPC_URL=
BASE_SEPOLIA_RPC_URL=
PRIVATE_KEY=
ETHERSCAN_API_KEY=
```

## Testing

You can run tests in two ways:

### Using test.sh Script

The project includes a `test.sh` script that handles the complete test setup and execution:

```bash
./test.sh
```

This script will:

1. Create necessary deployment directories
2. Handle Uniswap V3 deployments
3. Run the full test suite using Forge

### Manual Testing

Alternatively, you can run tests directly using Forge:

```bash
forge test
```

Run specific tests:

```bash
forge test --match-contract FarmlyBollingerBandsStrategy
```

## Deployment

Deploy to local network:

```bash
forge script script/FarmlyEasyFarm.s.sol --rpc-url local
```

Deploy to testnet (Sepolia):

```bash
forge script script/FarmlyEasyFarm.s.sol --rpc-url sepolia
```

## Project Structure

```
src/
├── FarmlyEasyFarm.sol    # Main contract
├── strategies/           # Liquidity management strategies
├── executors/           # Dex execution implementations
├── interfaces/          # Contract interfaces
├── libraries/           # Utility libraries
└── readers/            # Data reading contracts
```

## Security

- All contracts use OpenZeppelin's security contracts
- Built-in pause functionality for emergency situations
- Comprehensive test coverage
- Multiple security checks and validations

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
