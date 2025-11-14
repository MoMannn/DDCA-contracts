# DDCA - Decentralized Dollar Cost Averaging

A smart contract system for automated, decentralized dollar cost averaging built using the [Delegation Framework](https://github.com/MetaMask/delegation-framework).

## Overview

DDCA enables users to perform automated, periodic token swaps in a trustless and decentralized manner. The system leverages delegations to allow controlled access to user funds while maintaining security and user sovereignty. Through a flexible whitelist system, the contract supports multiple token pairs and can execute swaps through ve(3,3) / x(3,3) based DEX protocols.

## How It Works

### Architecture

The DDCA contract integrates with the Delegation Framework to enable secure, automated token swaps:

1. **Delegation Setup**: Users create a delegation using the Delegation Framework, granting the DDCA contract permission to transfer whitelisted tokens on their behalf.

2. **Fund Transfer**: The DDCA contract executes the delegation to claim the authorized tokens from the user's wallet.

3. **Fee Collection**: The contract calculates and collects a service fee from the transferred amount.

4. **Token Swap**: The remaining tokens are swapped through Etherex (ve(3,3) / x(3,3) based DEX) using configurable routes that can include multiple hops.

5. **Distribution**: The purchased tokens (or native ETH for ERC20-to-ETH swaps) are sent to the user's wallet.

### Fee Structure

The contract charges a fee based on the higher of:
- **0.1% of the input amount** (default, configurable), or
- **0.1 token flat fee** (default, configurable)

Both the percentage fee and minimum fee can be adjusted by the contract owner.

### Slippage Protection

The contract includes configurable slippage protection (default 0.5%) to ensure swaps execute within acceptable price ranges. This protects users from excessive price impact and frontrunning.

## Supported Assets

The contract uses a whitelist system for both source and destination tokens:
- **From Tokens**: Any ERC20 tokens whitelisted by the contract owner
- **To Tokens**: Any ERC20 tokens or native ETH (via WETH unwrapping) whitelisted by the contract owner
- **Multi-hop Routes**: Supports complex routing through multiple liquidity pools

## Technology Stack

- **Smart Contract Framework**: Foundry
- **Delegation System**: [MetaMask Delegation Framework](https://github.com/MetaMask/delegation-framework)
- **DEX Integration**: Etherex Router (ve(3,3) / x(3,3) based DEX)

## Development Status

⚠️ **Work in Progress**: This project is currently under active development. The contracts, documentation, and features are subject to change.

## Key Features

### 1. Delegation-Based Authorization
- Uses MetaMask Delegation Framework for secure, granular access control
- Users maintain full custody of their funds
- Delegations can be revoked at any time

### 2. Flexible Token Support
- Whitelist system for source and destination tokens
- Support for ERC20-to-ERC20 swaps
- Support for ERC20-to-ETH swaps (via WETH unwrapping)
- Multi-hop routing through multiple liquidity pools

### 3. Pool Type Management
- Support for both stable and volatile pools in ve(3,3) / x(3,3) DEXes
- Configurable pool preference per token pair
- Stable pools for correlated assets (e.g., USDC/USDT)
- Volatile pools for uncorrelated assets (e.g., ETH/USDC)

### 4. Owner Controls
- Whitelist/blacklist source and destination tokens
- Configure minimum fee and percentage fee
- Set slippage tolerance
- Manage pool type preferences for token pairs
- Two-step ownership transfer for security

## Contract Functions

### User Functions

#### `swapByDelegation(Delegation[] memory _delegations, Route[] memory _routes, uint256 _amount, bool _isNativeToToken)`
Executes a token swap using delegated permissions.
- `_delegations`: Array containing exactly one delegation from the user
- `_routes`: Array of routes defining the swap path (can be multi-hop)
- `_amount`: Amount of source token to swap
- `_isNativeToToken`: Set to `true` to unwrap WETH to native ETH at the end

#### `getQuote(Route[] memory _routes, uint256 _amount)`
Get a quote for a swap without executing it.
- Returns expected output amount and minimum amount after slippage

### Admin Functions

- `setAllowedFromToken(address _token, bool _allowed)`: Whitelist source tokens
- `setAllowedToToken(address _token, bool _allowed)`: Whitelist destination tokens
- `setPoolStablePreference(address _tokenFrom, address _tokenTo, bool _stable)`: Configure pool type for a token pair
- `setMinimumFee(uint256 _minimumFee)`: Set minimum fee in token units
- `setFeePercentageBps(uint256 _feePercentageBps)`: Set percentage fee in basis points
- `setSlippageBps(uint256 _slippageBps)`: Set slippage tolerance in basis points

## Development

### Prerequisites

- [Foundry](https://book.getfoundry.sh/)

### Build

```shell
forge build
```

### Test

```shell
forge test
```

### Format

```shell
forge fmt
```

### Deploy

```shell
forge script script/DeployDDCA.s.sol:DeployDDCA --rpc-url <your_rpc_url> --private-key <your_private_key>
```

Note: Update the `swapAddress` (Etherex Router address) and `delegationManager` address in the deploy script before deploying.

## Contributing

This project is in early development. More information about contributing will be provided as the project matures.

## License

UNLICENSED - This project is currently unlicensed.

## Security

⚠️ **Not Audited**: These contracts have not been audited. Use at your own risk.
