// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IDelegationManager } from '@metamask/delegation-framework/interfaces/IDelegationManager.sol';
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ModeLib } from "@erc7579/lib/ModeLib.sol";
import { ExecutionLib } from "@erc7579/lib/ExecutionLib.sol";
import { Delegation, ModeCode, Execution } from "@metamask/delegation-framework/utils/Types.sol";
import { IEtherexRouter, Route } from "./interfaces/IEtherexRouter.sol";

/// @title DDCA - Decentralized Dollar Cost Averaging
/// @author @MoMannn
contract DDCA is Ownable2Step {

    using SafeERC20 for IERC20;
    
    IEtherexRouter public immutable router;
    IDelegationManager public immutable delegationManager;
    mapping(address => bool) public allowedToTokens;
    mapping(address => bool) public allowedFromTokens;
    
    // Pool type preference: true for stable pools, false for volatile pools
    mapping(address => mapping(address => bool)) public poolStablePreference;
    
    uint256 public minimumFee; // Minimum fee in token units (e.g., 100000 for 0.1 token with 6 decimals)
    uint256 public feePercentageBps; // Fee percentage in basis points (e.g., 10 for 0.1%)
    
    // Slippage tolerance in basis points (default 50 = 0.5%)
    uint256 public slippageBps;

    error TokenFromNotAllowed();
    error TokenToNotAllowed();
    error InvalidDelegationsLength();
    error SwapFailed();
    error InsufficientOutputAmount();
    error InvalidRoutesLength();
    error InvalidRoutes();

    constructor(address _routerAddress, address _delegationManager) Ownable(_msgSender()) {
        router = IEtherexRouter(_routerAddress);
        delegationManager = IDelegationManager(_delegationManager);
        minimumFee = 100000; // Default: 0.1 token with 6 decimals
        feePercentageBps = 10; // Default: 0.1% (10 basis points)
        slippageBps = 50; // Default: 0.5% slippage tolerance
    }

        
    ////////////////////// Private Functions //////////////////////

    /// @notice Ensures sufficient token allowance for router operations
    /// @dev Checks current allowance and increases to max if needed
    /// @param _token Token to manage allowance for
    /// @param _amount Amount needed for the operation
    function _ensureAllowance(IERC20 _token, uint256 _amount) private {
        uint256 allowance_ = _token.allowance(address(this), address(router));
        if (allowance_ < _amount) {
            _token.safeIncreaseAllowance(address(router), type(uint256).max);
        }
    }

    /// @notice Calculates and takes fees from the amount
    /// @dev Calculates the percentage fee and takes the higher of the two fees
    /// @param _token Token to calculate fees for
    /// @param _amount Amount to calculate fees for
    /// @return The actual balance of the contract after fee transfer
    function _calculateAndTakeFees(address _token, uint256 _amount) private returns (uint256) {
        // Calculate percentage fee in basis points
        uint256 percentageFee_ = (_amount * feePercentageBps) / 10000;
        
        // Take the higher of the two fees
        uint256 fee_ = percentageFee_ > minimumFee ? percentageFee_ : minimumFee;
        
        // Transfer fee to owner
        IERC20(_token).safeTransfer(owner(), fee_);
        
        // Return the actual balance of the contract after fee transfer
        return IERC20(_token).balanceOf(address(this));
    }

    /// @notice Gets expected output amount from router for a given input
    /// @dev Queries the router to calculate expected output based on current pool state
    /// @param _amount Amount of source token
    /// @param _routes Pre-constructed routes array
    /// @return expectedOut Expected output amount before slippage
    function _getQuote(uint256 _amount, Route[] memory _routes) private view returns (uint256 expectedOut) {
        uint256[] memory amounts_ = router.getAmountsOut(_amount, _routes);
        
        // amounts_[0] is input, amounts_[1] is output for single hop
        expectedOut = amounts_[amounts_.length - 1];
    }
    

    /// @notice Executes a swap on Etherex (x(3,3) metaDEX)
    /// @dev Handles ERC20-to-ERC20 and ERC20-to-ETH swaps (ETH-to-ERC20 not supported)
    /// @param _routes Routes to swap
    /// @param _amount Amount of source token to swap
    /// @param _recipient Address to receive the swapped tokens
    function _swap(Route[] memory _routes, uint256 _amount, address _recipient, bool _isNativeToToken) private {
        
        // Get expected output amount from router
        uint256 expectedOut_ = _getQuote(_amount, _routes);
        
        // Calculate minimum amount out with slippage tolerance
        // slippageBps is in basis points (e.g., 50 = 0.5% = 99.5% of expected output)
        uint256 amountOutMin_ = (expectedOut_ * (10000 - slippageBps)) / 10000;
        
        // Deadline for the swap (10 minutes from now)
        uint256 deadline_ = block.timestamp + 600;

        address tokenFrom_ = _routes[0].from;
        address tokenTo_ = _routes[_routes.length - 1].to;
        
        // Handle different swap scenarios
        if (!_isNativeToToken) {
            // ERC20 to ERC20 swap
            router.swapExactTokensForTokens(
                _amount,
                amountOutMin_,
                _routes,
                _recipient,
                deadline_
            );
        } else {
            // ERC20 to ETH swap
            router.swapExactTokensForETH(
                _amount,
                amountOutMin_,
                _routes,
                _recipient,
                deadline_
            );
        }
        // } else if (_tokenFrom == NATIVE_TOKEN && _tokenTo != NATIVE_TOKEN) {
        //     // ETH to ERC20 swap - NOT SUPPORTED
        //     
        //     router.swapExactETHForTokens{value: _amount}(
        //         amountOutMin_,
        //         routes_,
        //         _recipient,
        //         deadline_
        //     );
            
        // } else {
        //     // ETH to token swaps not supported, or invalid token combination
        //     revert SwapFailed();
        // }
    }

    ////////////////////// Admin Functions //////////////////////
    
    /// @notice Sets whether a token is allowed as a destination token
    /// @param _token Token address
    /// @param _allowed Whether the token is allowed
    function setAllowedToToken(address _token, bool _allowed) public onlyOwner {
        allowedToTokens[_token] = _allowed;
    }
    
    /// @notice Sets whether a token is allowed as a source token
    /// @param _token Token address
    /// @param _allowed Whether the token is allowed
    function setAllowedFromToken(address _token, bool _allowed) public onlyOwner {
        allowedFromTokens[_token] = _allowed;
    }
    
    /// @notice Sets the pool type preference for a token pair
    /// @dev In x(3,3) DEXes, stable pools are for correlated assets (e.g., USDC/USDT)
    ///      and volatile pools are for uncorrelated assets (e.g., ETH/USDC)
    /// @param _tokenFrom Source token address
    /// @param _tokenTo Destination token address
    /// @param _stable True for stable pool, false for volatile pool
    function setPoolStablePreference(address _tokenFrom, address _tokenTo, bool _stable) public onlyOwner {
        poolStablePreference[_tokenFrom][_tokenTo] = _stable;
    }
    
    /// @notice Sets the minimum fee amount
    /// @param _minimumFee Minimum fee in token units
    function setMinimumFee(uint256 _minimumFee) public onlyOwner {
        minimumFee = _minimumFee;
    }
    
    /// @notice Sets the fee percentage in basis points
    /// @param _feePercentageBps Fee percentage (e.g., 10 = 0.1%)
    function setFeePercentageBps(uint256 _feePercentageBps) public onlyOwner {
        feePercentageBps = _feePercentageBps;
    }
    
    /// @notice Sets the slippage tolerance in basis points
    /// @param _slippageBps Slippage tolerance (e.g., 50 = 0.5%)
    function setSlippageBps(uint256 _slippageBps) public onlyOwner {
        slippageBps = _slippageBps;
    }

    ////////////////////// Public Functions //////////////////////
    
    /// @notice Gets a quote for swapping tokens
    /// @dev Returns expected output amount and minimum output amount after slippage
    /// @param _routes Routes to swap
    /// @param _amount Amount of source token
    /// @return expectedOut Expected output amount
    /// @return amountOutMin Minimum output amount after applying slippage tolerance
    function getQuote(Route[] memory _routes, uint256 _amount) 
        external 
        view 
        returns (uint256 expectedOut, uint256 amountOutMin) 
    {
        expectedOut = _getQuote(_amount, _routes);
        amountOutMin = (expectedOut * (10000 - slippageBps)) / 10000;
    }
    
    /// @notice Executes a token swap using delegated permissions
    /// @dev Uses MetaMask Delegation Framework to pull tokens from user's wallet
    /// @param _delegations Array of delegations (must contain exactly 1)
    /// @param _routes Routes to swap
    /// @param _amount Amount of source token to swap
    /// @param _isNativeToToken Whether we want to swap to native (automatically from WETH to ETH)
    function swapByDelegation(Delegation[] memory _delegations, Route[] memory _routes, uint256 _amount, bool _isNativeToToken) external {
        if (_routes.length == 0) revert InvalidRoutesLength();
        address tokenFrom_ = _routes[0].from;
        address tokenTo_ = _routes[_routes.length - 1].to;
        if (!allowedFromTokens[tokenFrom_]) revert TokenFromNotAllowed();
        if (!allowedToTokens[tokenTo_]) revert TokenToNotAllowed();
        if (_delegations.length != 1) revert InvalidDelegationsLength();
        if (_isNativeToToken && tokenTo_ != router.WETH()) revert InvalidRoutes();

        bytes[] memory permissionContexts_ = new bytes[](1);
        permissionContexts_[0] = abi.encode(_delegations);

        ModeCode[] memory encodedModes_ = new ModeCode[](1);
        encodedModes_[0] = ModeLib.encodeSimpleSingle();

        bytes[] memory executionCallDatas_ = new bytes[](1);

        bytes memory encodedTransfer_ = abi.encodeCall(IERC20.transfer, (address(this), _amount));
        executionCallDatas_[0] = ExecutionLib.encodeSingle(address(tokenFrom_), 0, encodedTransfer_);

        delegationManager.redeemDelegations(permissionContexts_, encodedModes_, executionCallDatas_);

        uint256 amountAfterFees_ = _calculateAndTakeFees(tokenFrom_, _amount);
        _ensureAllowance(IERC20(tokenFrom_), amountAfterFees_);
        _swap(_routes, amountAfterFees_, _delegations[0].delegator, _isNativeToToken);
    }
    
    /// @notice Allows contract to receive ETH from swaps
    receive() external payable {}

}
