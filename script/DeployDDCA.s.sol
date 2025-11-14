// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {DDCA} from "../src/DDCA.sol";

contract DeployDDCA is Script {
    DDCA public ddca;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // TODO: Replace with actual addresses
        address swapAddress = address(0);
        address delegationManager = address(0);
        
        ddca = new DDCA(swapAddress, delegationManager);

        vm.stopBroadcast();
    }
}
