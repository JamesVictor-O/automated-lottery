// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {AutomatedLottery } from "../src/AutomatedLottery.sol";

contract CounterTest is Test {
    AutomatedLottery  public automatedlottery;

    function setUp() public {
         automatedlottery = new AutomatedLottery();
    }

   
}
