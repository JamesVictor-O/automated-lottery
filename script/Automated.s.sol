// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "forge-std/Script.sol";
import "../src/AutomatedLottery.sol";

contract DeployAutomatedLottery is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Contract constructor parameters
        uint256 entranceFee = 0.01 ether;
        uint256 interval = 300; // 5 minutes in seconds
        
        // Sepolia testnet values
        address vrfCoordinatorV2 = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;
        uint64 subscriptionId = uint64(vm.envUint("CHAINLINK_SUB_ID")); // From .env file
        bytes32 keyHash = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
        uint32 callbackGasLimit = 500000;

        vm.startBroadcast(deployerPrivateKey);
        
        AutomatedLottery lottery = new AutomatedLottery(
            entranceFee,
            interval,
            vrfCoordinatorV2,
            subscriptionId,
            keyHash,
            callbackGasLimit
        );
        
        vm.stopBroadcast();

        console.log("Automated Lottery deployed at:", address(lottery));
    }
}