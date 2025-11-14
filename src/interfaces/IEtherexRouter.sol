// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Route struct for ve(3,3) / x(3,3) DEX routing
struct Route {
    address from;
    address to;
    bool stable; // true for stable pools, false for volatile pools
}

// Interface for Etherex Router (ve(3,3) / x(3,3) based)
interface IEtherexRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    
    function swapExactETHForTokens(
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
    
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    
    function getAmountsOut(
        uint256 amountIn,
        Route[] calldata routes
    ) external view returns (uint256[] memory amounts);
    
    function WETH() external view returns (address);
}

