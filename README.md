# DDCA - Decentralized Dollar Cost Averaging

A smart contract system for automated, decentralized dollar cost averaging built using the [Delegation Framework](https://github.com/MetaMask/delegation-framework).

## Overview

DDCA enables users to perform automated, periodic token swaps in a trustless and decentralized manner. The system leverages delegations to allow controlled access to user funds while maintaining security and user sovereignty. Through a flexible whitelist system, the contract supports multiple token pairs and can execute swaps through various DEX protocols including Uniswap V3 and ve(3,3) / x(3,3) based DEXes.

## How It Works

### Architecture

The DDCA contract integrates with the Delegation Framework to enable secure, automated token swaps:

1. **Delegation Setup**: Users create a delegation using the Delegation Framework, granting the DDCA contract permission to transfer whitelisted tokens on their behalf.

2. **Fund Transfer**: The DDCA contract executes the delegation to claim the authorized tokens from the user's wallet.

3. **Fee Collection**: The contract calculates and collects a service fee from the transferred amount.

4. **Token Swap**: The remaining tokens are swapped through the configured DEX:
   - **Uniswap V3**: Direct single-hop or multi-hop swaps with pool fee tiers (0.05%, 0.3%, 1%)
   - **Etherex**: ve(3,3) / x(3,3) based DEX with configurable routes that can include multiple hops

5. **Distribution**: The purchased tokens (or native ETH for ERC20-to-ETH swaps) are sent to the user's wallet.

### Fee Structure

All contracts charge a fee based on the higher of:
- **0.1% of the input amount** (default, configurable), or
- **Minimum flat fee** (default varies by implementation, configurable)

Default minimum fees:
- **DDCAEtherex**: 0.1 token (100000 units for 6 decimals)
- **DDCAUniswapV3**: 1 token (1000000 units for 6 decimals)
- **DDCAUniswapV3NoQuoter**: 1 token (1000000 units for 6 decimals)

Both the percentage fee and minimum fee can be adjusted by the contract owner, with a maximum limit of 10% for safety.

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
- **DEX Integrations**: 
  - Uniswap V3 (SwapRouter02, QuoterV2)
  - Etherex Router (ve(3,3) / x(3,3) based DEX)

## Contract Implementations

The project includes three contract implementations to support different DEX protocols:

### 1. DDCAEtherex
- Designed for Etherex (ve(3,3) / x(3,3) based DEX)
- Supports multi-hop routes with stable/volatile pool preferences
- Includes quote functionality via router
- Supports ERC20-to-ERC20 and ERC20-to-ETH swaps

### 2. DDCAUniswapV3
- Designed for Uniswap V3
- Uses QuoterV2 for accurate swap quotes
- Supports pool fee tiers: 0.05% (500), 0.3% (3000), 1% (10000)
- Includes built-in slippage protection via quotes

### 3. DDCAUniswapV3NoQuoter
- Designed for Uniswap V3 without quoter dependency
- Lighter implementation without quote functionality
- Suitable for deployments where QuoterV2 is not available
- User must provide minimum output amount directly

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
- **Etherex**: Support for both stable and volatile pools in ve(3,3) / x(3,3) DEXes
  - Configurable pool preference per token pair
  - Stable pools for correlated assets (e.g., USDC/USDT)
  - Volatile pools for uncorrelated assets (e.g., ETH/USDC)
- **Uniswap V3**: Support for multiple fee tiers (0.05%, 0.3%, 1%)

### 4. Owner Controls
- Whitelist/blacklist source and destination tokens
- Configure minimum fee and percentage fee
- Set slippage tolerance
- Manage pool type preferences for token pairs
- Two-step ownership transfer for security

## Contract Functions

### User Functions

#### DDCAEtherex

**`swapByDelegation(Delegation[] memory _delegations, Route[] memory _routes, uint256 _amount, bool _isNativeToToken)`**

Executes a token swap using delegated permissions.
- `_delegations`: Array containing exactly one delegation from the user
- `_routes`: Array of routes defining the swap path (can be multi-hop)
- `_amount`: Amount of source token to swap
- `_isNativeToToken`: Set to `true` to unwrap WETH to native ETH at the end

**`getQuote(Route[] memory _routes, uint256 _amount)`**

Get a quote for a swap without executing it.
- Returns expected output amount and minimum amount after slippage

#### DDCAUniswapV3

**`swapByDelegation(Delegation[] calldata _delegations, address _tokenIn, address _tokenOut, uint24 _fee, uint256 _amount)`**

Executes a token swap using delegated permissions.
- `_delegations`: Array containing exactly one delegation from the user
- `_tokenIn`: Input token address
- `_tokenOut`: Output token address
- `_fee`: Pool fee tier (500, 3000, or 10000)
- `_amount`: Amount of source token to swap

**`getQuote(address _tokenIn, address _tokenOut, uint24 _fee, uint256 _amountIn)`**

Get a quote for a swap without executing it.
- Returns expected output amount and minimum amount after slippage

#### DDCAUniswapV3NoQuoter

**`swapByDelegation(Delegation[] calldata _delegations, address _tokenIn, address _tokenOut, uint24 _fee, uint256 _amount)`**

Executes a token swap using delegated permissions (no quote functionality).
- `_delegations`: Array containing exactly one delegation from the user
- `_tokenIn`: Input token address
- `_tokenOut`: Output token address
- `_fee`: Pool fee tier (500, 3000, or 10000)
- `_amount`: Amount of source token to swap

### Admin Functions

#### Common Functions (All Implementations)

- `setAllowedFromToken(address _token, bool _allowed)`: Whitelist source tokens
- `setAllowedToToken(address _token, bool _allowed)`: Whitelist destination tokens
- `setMinimumFee(uint256 _minimumFee)`: Set minimum fee in token units
- `setFeePercentageBps(uint256 _feePercentageBps)`: Set percentage fee in basis points (max 10%)
- `setSlippageBps(uint256 _slippageBps)`: Set slippage tolerance in basis points (max 10%)

#### DDCAEtherex Specific

- `setPoolStablePreference(address _tokenFrom, address _tokenTo, bool _stable)`: Configure pool type for a token pair

#### Uniswap V3 Implementations Specific

- `recoverToken(address _token, uint256 _amount)`: Emergency function to recover stuck tokens

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

Choose the appropriate deployment script based on your desired DEX integration:

#### Deploy DDCAEtherex (for Etherex/ve(3,3) DEX)
```shell
forge script script/DeployDDCAEtherex.s.sol:DeployDDCAEtherex --rpc-url <your_rpc_url> --private-key <your_private_key>
```

#### Deploy DDCAUniswapV3 (with QuoterV2)
```shell
forge script script/DeployDDCAUniswapV3.s.sol:DeployDDCAUniswapV3 --rpc-url <your_rpc_url> --private-key <your_private_key>
```

#### Deploy DDCAUniswapV3NoQuoter (without QuoterV2)
```shell
forge script script/DeployDDCAUniswapV3noQuoter.s.sol:DeployDDCAUniswapV3noQuoter --rpc-url <your_rpc_url> --private-key <your_private_key>
```

**Important**: Update the relevant addresses (router, quoter, delegationManager) in the deployment script before deploying.

## Contributing

This project is in early development. More information about contributing will be provided as the project matures.

## License

UNLICENSED - This project is currently unlicensed.

## Security

⚠️ **Not Audited**: These contracts have not been audited. Use at your own risk.

⚠️ **Trust Requirements**: The `swapByDelegation` function is restricted to `onlyOwner` for security reasons. While the contract enforces token whitelists, the executor can still choose which whitelisted tokens to swap on behalf of the user. 

The MetaMask Delegation Framework supports enforced outcomes (restrictions on token outputs, callable functions, and parameters), but wallet interfaces do not yet properly display these permissions to users. Until this functionality is widely supported, users must trust the dApp operator to execute swaps according to their preferences. 