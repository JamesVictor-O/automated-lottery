// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "../src/AutomatedLottery.sol";
// import "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import "@chainlink/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";

contract AutomatedLotteryTest is Test {
    AutomatedLottery public lottery;
    VRFCoordinatorV2Mock public vrfCoordinatorMock;
    
    uint256 public entranceFee = 0.01 ether;
    uint256 public interval = 300; // 5 minutes
    uint64 public subscriptionId;
    bytes32 public keyHash = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint32 public callbackGasLimit = 500000;
    
    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() public {
        // Deploy VRF Coordinator Mock
        vrfCoordinatorMock = new VRFCoordinatorV2Mock(
            0.1 ether, // base fee
            1e9 // gas price link
        );
        
        // Create and fund a subscription
        subscriptionId = vrfCoordinatorMock.createSubscription();
        vrfCoordinatorMock.fundSubscription(subscriptionId, 5 ether);
        
        // Deploy lottery contract
        lottery = new AutomatedLottery(
            entranceFee,
            interval,
            address(vrfCoordinatorMock),
            subscriptionId,
            keyHash,
            callbackGasLimit
        );
        
        // Add consumer
        vrfCoordinatorMock.addConsumer(subscriptionId, address(lottery));
        
        // Give player some ETH
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }
    
    function testLotteryInitialState() public {
       assertTrue(lottery.getLotteryState() == AutomatedLottery.LotteryState.OPEN);
    
       assertEq(lottery.getEntranceFee(), entranceFee);
    }
    
    function testEnterLottery() public {
        // Enter lottery as PLAYER
        vm.prank(PLAYER);
        lottery.enterLottery{value: entranceFee}();
        
        assertEq(lottery.getNumberOfPlayers(), 1);
        assertEq(lottery.getPlayer(0), PLAYER);
    }
    
    function testLotterySelectsWinnerAfterTimeHasPassed() public {
        // Enter lottery
        vm.prank(PLAYER);
        lottery.enterLottery{value: entranceFee}();
        
        // Advance time by more than interval
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        
        // Perform upkeep to request random number
        bytes memory performData = "";
        (bool upkeepNeeded, ) = lottery.checkUpkeep("");
        assertEq(upkeepNeeded, true);
        
        vm.recordLogs();
        lottery.performUpkeep(performData);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[0].topics[1]; // Extract requestId from event
        
        // Fulfill random words to select winner
        vm.recordLogs();
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 123;
        vrfCoordinatorMock.fulfillRandomWords(uint256(requestId), address(lottery));
        
        // Check if winner was picked
        assertEq(lottery.getRecentWinner(), PLAYER);
        assertEq(lottery.getNumberOfPlayers(), 0);
        assertTrue(lottery.getLotteryState() == AutomatedLottery.LotteryState.OPEN); // OPEN state
    }
}