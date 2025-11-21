// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {DDCAUniswapV3NoQuoter} from "../src/DDCAUniswapV3NoQuoter.sol";

/**
 * Run deployment script via:
 * forge script script/DeployDDCAUniswapV3noQuoter.s.sol:DeployDDCAUniswapV3NoQuoterScript --rpc-url <your_rpc_url> --private-key $PRIVATE_KEY
 */

contract DeployDDCAUniswapV3NoQuoterScript is Script {
    DDCAUniswapV3NoQuoter public ddca;

    function setUp() public {}

    function run() public {
        // Uniswap V3 addresses
        // Mainnet SwapRouter02: 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45
        // Sepolia SwapRouter02: 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E
        // https://docs.uniswap.org/contracts/v3/reference/deployments
        
        // Get addresses from environment variables
        address swapRouter = vm.envAddress("SWAP_ROUTER");
        address delegationManager = vm.envAddress("DELEGATION_MANAGER");

        vm.startBroadcast();

        ddca = new DDCAUniswapV3NoQuoter(
            swapRouter,
            delegationManager
        );

        console.log("DDCAUniswapV3NoQuoter deployed to:", address(ddca));
        console.log("Swap Router:", swapRouter);
        console.log("Delegation Manager:", delegationManager);

        vm.stopBroadcast();
    }
}

