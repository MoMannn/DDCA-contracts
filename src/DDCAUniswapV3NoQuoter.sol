// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IDelegationManager } from '@metamask/delegation-framework/interfaces/IDelegationManager.sol';
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ModeLib } from "@erc7579/lib/ModeLib.sol";
import { ExecutionLib } from "@erc7579/lib/ExecutionLib.sol";
import { Delegation, ModeCode, Execution } from "@metamask/delegation-framework/utils/Types.sol";

// Import Uniswap V3 interfaces
import { ISwapRouter02, IPermit2 } from "./interfaces/IUniswapV3.sol";

/// @title DDCAUniswapV3NoQuoter - Decentralized Dollar Cost Averaging for Uniswap V3 (without quoter)
/// @author @MoMannn
/// @notice This contract enables automated DCA strategies on Uniswap V3 using MetaMask's Delegation Framework
contract DDCAUniswapV3NoQuoter is Ownable2Step {
    using SafeERC20 for IERC20;
    
    ISwapRouter02 public immutable swapRouter;
    IDelegationManager public immutable delegationManager;
    
    mapping(address => bool) public allowedToTokens;
    mapping(address => bool) public allowedFromTokens;
    
    uint256 public minimumFee; // Minimum fee in token units (e.g., 100000 for 0.1 token with 6 decimals)
    uint256 public feePercentageBps; // Fee percentage in basis points (e.g., 10 for 0.1%)
    
    // Slippage tolerance in basis points (default 50 = 0.5%)
    uint256 public slippageBps;

    error TokenFromNotAllowed();
    error TokenToNotAllowed();
    error InvalidDelegationsLength();
    error SwapFailed();
    error InsufficientOutputAmount();

    event SwapExecuted(
        address indexed user,
        address indexed tokenFrom,
        address indexed tokenTo,
        uint256 amountIn,
        uint256 amountOut,
        uint256 feeAmount
    );

    constructor(
        address _swapRouter,
        address _delegationManager
    ) Ownable(_msgSender()) {
        swapRouter = ISwapRouter02(_swapRouter);
        delegationManager = IDelegationManager(_delegationManager);
        minimumFee = 1000000; // Default: 1 token with 6 decimals
        feePercentageBps = 10; // Default: 0.1% (10 basis points)
        slippageBps = 50; // Default: 0.5% slippage tolerance
    }

    ////////////////////// Private Functions //////////////////////

    /// @notice Ensures sufficient token allowance for SwapRouter
    /// @param _token Token to manage allowance for
    /// @param _amount Amount needed for the operation
    function _ensureAllowance(IERC20 _token, uint256 _amount) private {
        uint256 currentAllowance = _token.allowance(address(this), address(swapRouter));
        if (currentAllowance < _amount) {
            _token.forceApprove(address(swapRouter), type(uint256).max);
        }
    }

    /// @notice Calculates and deducts fee from the input amount
    /// @param _fromToken Token being swapped from
    /// @param _amount Total amount before fee
    /// @return amountAfterFee Amount after fee deduction
    /// @return feeAmount Fee amount deducted
    function _calculateFee(
        address _fromToken,
        uint256 _amount
    ) private returns (uint256 amountAfterFee, uint256 feeAmount) {
        // Calculate percentage-based fee
        uint256 percentageFee = (_amount * feePercentageBps) / 10000;
        
        // Take the maximum of percentage fee and minimum fee
        feeAmount = percentageFee > minimumFee ? percentageFee : minimumFee;
        
        // Ensure fee doesn't exceed the amount
        if (feeAmount >= _amount) {
            feeAmount = _amount / 2; // Cap at 50% as safety measure
        }
        
        amountAfterFee = _amount - feeAmount;
        
        // Transfer fee to owner
        if (feeAmount > 0) {
            IERC20(_fromToken).safeTransfer(owner(), feeAmount);
        }
    }

    /// @notice Executes the swap on Uniswap V3
    /// @param _tokenIn Input token address
    /// @param _tokenOut Output token address
    /// @param _fee Pool fee tier
    /// @param _amount Amount to swap
    /// @param _minAmountOut Minimum acceptable output amount
    /// @param _recipient Address to receive the output tokens
    /// @return amountOut Actual output amount received
    function _swap(
        address _tokenIn,
        address _tokenOut,
        uint24 _fee,
        uint256 _amount,
        uint256 _minAmountOut,
        address _recipient
    ) private returns (uint256 amountOut) {
        // Ensure router has approval
        _ensureAllowance(IERC20(_tokenIn), _amount);
        
        // SwapRouter02 doesn't have deadline in the struct
        ISwapRouter02.ExactInputSingleParams memory params = ISwapRouter02.ExactInputSingleParams({
            tokenIn: _tokenIn,
            tokenOut: _tokenOut,
            fee: _fee,
            recipient: _recipient,
            amountIn: _amount,
            amountOutMinimum: _minAmountOut,
            sqrtPriceLimitX96: 0
        });
        
        amountOut = swapRouter.exactInputSingle(params);
        
        if (amountOut < _minAmountOut) {
            revert InsufficientOutputAmount();
        }
    }

    ////////////////////// Public Functions //////////////////////

    /// @notice Executes a swap using MetaMask delegation
    /// @param _delegations Array of delegations granting permission to transfer tokens
    /// @param _tokenIn Input token address
    /// @param _tokenOut Output token address
    /// @param _fee Pool fee tier (500, 3000, or 10000)
    /// @param _amount Amount of input token to swap
    function swapByDelegation(
        Delegation[] calldata _delegations,
        address _tokenIn,
        address _tokenOut,
        uint24 _fee,
        uint256 _amount
    ) public onlyOwner {
        if (_delegations.length != 1) revert InvalidDelegationsLength();
        if (!allowedFromTokens[_tokenIn]) revert TokenFromNotAllowed();
        if (!allowedToTokens[_tokenOut]) revert TokenToNotAllowed();

        address user = _delegations[0].delegator;

        // Prepare delegation redemption
        bytes[] memory permissionContexts = new bytes[](1);
        permissionContexts[0] = abi.encode(_delegations);

        ModeCode[] memory modes = new ModeCode[](1);
        modes[0] = ModeLib.encodeSimpleSingle();

        bytes[] memory executionCallDatas = new bytes[](1);
        bytes memory encodedTransfer = abi.encodeCall(IERC20.transfer, (address(this), _amount));
        executionCallDatas[0] = ExecutionLib.encodeSingle(_tokenIn, 0, encodedTransfer);

        // Redeem delegation to transfer tokens from user to this contract
        delegationManager.redeemDelegations(permissionContexts, modes, executionCallDatas);

        // Calculate fee
        (uint256 amountAfterFee, uint256 feeAmount) = _calculateFee(_tokenIn, _amount);

        // Execute swap without quoter - use 0 as minimum output (or could use a small percentage)
        // In production, you might want to pass minOut as a parameter or calculate it differently
        uint256 minOut = 0;

        // Execute swap
        uint256 amountOut = _swap(_tokenIn, _tokenOut, _fee, amountAfterFee, minOut, user);

        emit SwapExecuted(user, _tokenIn, _tokenOut, _amount, amountOut, feeAmount);
    }

    ////////////////////// Admin Functions //////////////////////

    /// @notice Sets the allowance status for a "from" token
    /// @param _token Token address to configure
    /// @param _allowed Whether the token is allowed
    function setAllowedFromToken(address _token, bool _allowed) external onlyOwner {
        allowedFromTokens[_token] = _allowed;
    }

    /// @notice Sets the allowance status for a "to" token
    /// @param _token Token address to configure
    /// @param _allowed Whether the token is allowed
    function setAllowedToToken(address _token, bool _allowed) external onlyOwner {
        allowedToTokens[_token] = _allowed;
    }

    /// @notice Updates the minimum fee
    /// @param _minimumFee New minimum fee in token units
    function setMinimumFee(uint256 _minimumFee) external onlyOwner {
        minimumFee = _minimumFee;
    }

    /// @notice Updates the fee percentage
    /// @param _feePercentageBps New fee percentage in basis points
    function setFeePercentageBps(uint256 _feePercentageBps) external onlyOwner {
        require(_feePercentageBps <= 1000, "Fee too high"); // Max 10%
        feePercentageBps = _feePercentageBps;
    }

    /// @notice Updates the slippage tolerance
    /// @param _slippageBps New slippage tolerance in basis points
    function setSlippageBps(uint256 _slippageBps) external onlyOwner {
        require(_slippageBps <= 1000, "Slippage too high"); // Max 10%
        slippageBps = _slippageBps;
    }

    /// @notice Emergency function to recover stuck tokens
    /// @param _token Token to recover
    /// @param _amount Amount to recover
    function recoverToken(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(owner(), _amount);
    }
}

