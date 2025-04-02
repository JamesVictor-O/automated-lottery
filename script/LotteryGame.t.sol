// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LotteryGame} from "../src/LottryGame.sol";

contract CounterScript is Script {
   LotteryGame public lotteryGame;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
       address vrfCoordinatorV2 = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;
       uint64 subscriptionId =2438644750964954;
       bytes32 keyHash=0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
       uint32 callbackGasLimit = 250000;
       uint256 _poolCreationInterval = 300; 

       lotteryGame = new LotteryGame(vrfCoordinatorV2,subscriptionId,keyHash,callbackGasLimit,_poolCreationInterval);

        vm.stopBroadcast();
    }
}