// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {AutomatedLottery } from "../src/AutomatedLottery.sol";

contract CounterScript is Script {
    AutomatedLottery public automatedlottery;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        automatedlottery = new AutomatedLottery();

        vm.stopBroadcast();
    }
}
