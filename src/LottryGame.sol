// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@chainlink/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

contract LotteryGame is VRFConsumerBaseV2, AutomationCompatibleInterface {
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    event PoolCreated(uint256 poolId, uint256 fee, uint256 interval);
    event WinnerPicked(uint256 poolId, address winner);
    event RandomnessRequested(uint256 requestId, uint256 poolId);


    enum LotteryState {
        OPEN,
        CALCULATING
    }


    struct Pool {
        uint256 entranceFee;
        uint256 interval;
        uint256 lastTimestamp;
        address payable[] players;
        LotteryState stage;
        address recentWinner;
    }

    mapping(uint256 => Pool) public pools; // poolId => Pool data
    mapping(uint256 => uint256) public vrfRequestToPoolId;

    uint public nextPoolId;
    uint256[] public activePoolIds; // Tracks creation order
    mapping(uint256 => uint256) public poolCreationTime; // Wh

    // pool creation Automation
    uint256 public lastPoolCreation;
    uint256 public poolCreationInterval;

    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 keyHash,
        uint32 callbackGasLimit,
        uint256 _poolCreationInterval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_subscriptionId = subscriptionId;
        i_keyHash = keyHash;
        i_callbackGasLimit = callbackGasLimit;
        poolCreationInterval = _poolCreationInterval;
        lastPoolCreation = block.timestamp;
    }

    function _createNewPool() internal {
        // Generate random fee (0.1 to 0.5 ETH)
        uint256 fee = 0.1 ether + (0.1 ether * (block.timestamp % 5));
        // Fixed 5 minute interval for all pools
        uint256 interval = 5 minutes;

        uint256 poolId = nextPoolId++;
        pools[poolId] = Pool({
            entranceFee: fee,
            interval: interval,
            lastTimestamp: block.timestamp,
            players: new address payable[](0),
            stage: LotteryState.OPEN,
            recentWinner: address(0)
        });
        activePoolIds.push(poolId);

        emit PoolCreated(poolId, fee, interval);
    }

    function enterInTOLottery(uint _poolId) external payable {
        Pool storage pool = pools[_poolId];
        require(pool.stage == LotteryState.OPEN, "Lottery not open");
        require(msg.sender != address(0), "Invalid Address");
        require(msg.value == pool.entranceFee, "Wrong fee amount");
        pool.players.push(payable(msg.sender));
    }

    function checkUpkeep(
        bytes calldata
    ) external view override returns (bool upkeepNeeded, bytes memory) {
        bool timeToCreate = (block.timestamp - lastPoolCreation) >=
            poolCreationInterval;
        // Check if any pool needs drawing
        bool needsDrawing = false;
        for (uint i = 0; i < activePoolIds.length; i++) {
            Pool memory pool = pools[activePoolIds[i]];
            if (
                pool.stage == LotteryState.OPEN &&
                (block.timestamp - pool.lastTimestamp) >= pool.interval &&
                pool.players.length > 0
            ) {
                needsDrawing = true;
                break;
            }
        }

        upkeepNeeded = timeToCreate || needsDrawing;
    }

    function performUpkeep(bytes calldata) external override {
        // Create new pool if time
        if ((block.timestamp - lastPoolCreation) >= poolCreationInterval) {
            _createNewPool();
            lastPoolCreation = block.timestamp;
        }

        // Process oldest eligible pool
        for (uint i = 0; i < activePoolIds.length; i++) {
            uint256 poolId = activePoolIds[i];
            Pool storage pool = pools[poolId];

            if (
                pool.stage == LotteryState.OPEN &&
                (block.timestamp - pool.lastTimestamp) >= pool.interval &&
                pool.players.length > 0
            ) {
                pool.stage = LotteryState.CALCULATING;
                uint256 requestId = i_vrfCoordinator.requestRandomWords(
                    i_keyHash,
                    i_subscriptionId,
                    REQUEST_CONFIRMATIONS,
                    i_callbackGasLimit,
                    NUM_WORDS
                );
                vrfRequestToPoolId[requestId] = poolId;
                break; 
            }
        }
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        uint256 poolId = vrfRequestToPoolId[requestId];
        Pool storage pool = pools[poolId];

        require(
            pool.stage == LotteryState.CALCULATING,
            "Not in calculating state"
        );

        // Select winner
        uint256 winnerIndex = randomWords[0] % pool.players.length;
        address payable winner = pool.players[winnerIndex];
        pool.recentWinner = winner;

        // Pay winner
        (bool success, ) = winner.call{value: address(this).balance}("");
        require(success, "Transfer failed");

        // Reset pool
        pool.players = new address payable[](0);
        pool.lastTimestamp = block.timestamp;
        pool.stage = LotteryState.OPEN;

        emit WinnerPicked(poolId, winner);
    }

    function getPoolPlayers(
        uint256 poolId
    ) public view returns (address payable[] memory) {
        return pools[poolId].players;
    }

    function getActivePools() public view returns (uint256[] memory) {
        return activePoolIds;
    }
}
