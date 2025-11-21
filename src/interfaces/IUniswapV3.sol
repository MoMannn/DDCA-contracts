// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title ISwapRouter - Uniswap V3 Swap Router Interface (V1)
/// @notice Minimal interface for Uniswap V3 SwapRouter V1
interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

/// @title ISwapRouter02 - Uniswap V3 Swap Router Interface (V2)
/// @notice Interface for Uniswap V3 SwapRouter02 - NO DEADLINE in struct!
interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

/// @title IQuoter - Uniswap V3 Quoter Interface
/// @notice Minimal interface for Uniswap V3 Quoter
/// @title IQuoterV2 - Uniswap V3 QuoterV2 Interface
interface IQuoterV2 {
    struct QuoteExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Returns the amount out received for a given exact input swap without executing the swap
    /// @param params The parameters for the quote
    /// @return amountOut The amount of `tokenOut` that would be received
    /// @return sqrtPriceX96After The sqrt price of the pool after the swap
    /// @return initializedTicksCrossed The number of initialized ticks that were crossed
    /// @return gasEstimate The estimate of the gas used by the swap
    function quoteExactInputSingle(QuoteExactInputSingleParams memory params)
        external
        returns (
            uint256 amountOut,
            uint160 sqrtPriceX96After,
            uint32 initializedTicksCrossed,
            uint256 gasEstimate
        );
}

/// @title IUniversalRouter - Uniswap Universal Router Interface
/// @notice Interface for Uniswap Universal Router that handles V2, V3, and other protocols
interface IUniversalRouter {
    /// @notice Executes encoded commands along with provided inputs
    /// @param commands A set of concatenated commands, each 1 byte in length
    /// @param inputs An array of byte strings containing abi encoded inputs for each command
    /// @param deadline The deadline by which the transaction must be executed
    function execute(
        bytes calldata commands,
        bytes[] calldata inputs,
        uint256 deadline
    ) external payable;
}

/// @title IPermit2 - Permit2 Interface (same for V3 and V4)
interface IPermit2 {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
    function transferFrom(address from, address to, uint160 amount, address token) external;
}

