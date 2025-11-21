// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {DDCAEtherex} from "../src/DDCAEtherex.sol";

contract DeployDDCAEtherex is Script {
    DDCAEtherex public ddca;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // TODO: Replace with actual addresses
        address swapAddress = address(0);
        address delegationManager = address(0);
        
        ddca = new DDCAEtherex(swapAddress, delegationManager);

        vm.stopBroadcast();
    }
}
