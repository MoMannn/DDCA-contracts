// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {DDCAUniswapV3} from "../src/DDCAUniswapV3.sol";

contract DeployDDCAUniswapV3Script is Script {
    DDCAUniswapV3 public ddca;

    function setUp() public {}

    function run() public {
        // Uniswap V3 addresses
        // Mainnet SwapRouter02: 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45
        // Mainnet QuoterV2:     0x61fFE014bA17989E743c5F6cB21bF9697530B21e
        // Sepolia SwapRouter02: 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E
        // https://docs.uniswap.org/contracts/v3/reference/deployments
        
        // Get addresses from environment variables
        address swapRouter = vm.envAddress("SWAP_ROUTER");
        address quoter = vm.envAddress("QUOTER");
        address delegationManager = vm.envAddress("DELEGATION_MANAGER");

        vm.startBroadcast();

        ddca = new DDCAUniswapV3(
            swapRouter,
            quoter,
            delegationManager
        );

        console.log("DDCAUniswapV3 deployed to:", address(ddca));
        console.log("Swap Router:", swapRouter);
        console.log("Quoter:", quoter);
        console.log("Delegation Manager:", delegationManager);

        vm.stopBroadcast();
    }
}

