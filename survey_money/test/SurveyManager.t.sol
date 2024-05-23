// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/Vm.sol";
import {SurveyManager} from "../src/SurveyManager.sol";



contract SurveyTest is Test {
    SurveyManager public smgr;
    address public admin = address(0x01);
    address public user = address(0x02);
    address public guest = address(0x03);

    function setUp() public {
        vm.startPrank(admin);
        smgr = new SurveyManager();
        vm.stopPrank();
    }

    function testRegister() public {
        vm.startPrank(user);
        assertEq(smgr.isNameTaken("User_one"), false);

        bool reg_1 = smgr.register("User_one");
        bool reg_1_1 = smgr.register("User_one");

        assertEq(reg_1, true);
        assertEq(reg_1_1, false);
        assertEq(smgr.isRegistered(address(user)), true);
        assertEq(smgr.isNameTaken("User_one"), true);
        vm.stopPrank();
    }

    function testCreate() public {
        vm.startPrank(user);
        smgr.addBalance(5 ether);
        string[] memory answers = new string[](4);
        answers[0] = "B";
        answers[1] = "C";
        answers[2] = "D";
        answers[3] = "E";
        smgr.register("User_one");
        bool create_1 = smgr.createSurvey("A", answers, 5, 20, 3 ether);
        assertEq(create_1, true);
        vm.stopPrank();
    }


}
