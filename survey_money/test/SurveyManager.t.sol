// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/Vm.sol";
import {SurveyManager} from "../src/SurveyManager.sol";
import "../src/SurveyManager.sol";


contract SurveyTest is Test {
    SurveyManager public smgr;
    address public admin = address(0x01);
    address public user = address(0x02);
    address public guest = address(0x03);

    // TODO: just set up a lot of this stuff outside of pranks so they don't need to be repeated so much

    function setUp() public {
        vm.startPrank(admin);
        smgr = new SurveyManager();
        vm.stopPrank();
    }

    /*
    This tests the register function. The user first registers an account under a username, before attempting to register 
    another account under the same username. The username must be unique, meaning it can not already be taken.
    Therefore, the first registration attempt is expected to return true, while the second attempt is expected to return false.
    */ 
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

    /*
    This tests survey creation. The function first adds 5 ether to the user's account. The user then registers themselves. 
    They then create a two surveys: one that follows the survey creation rules and one that tries to have an empty set of answer choices.
    The expected result is that the first attempt at creation will return true while the second attempt at creation will return false.
    */
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
        string[] memory empty = new string[](0);
        bool create_2 = smgr.createSurvey("A", empty, 5, 20, 1 ether); // trying to make a survey with no answers
        assertEq(create_2, false);
        vm.stopPrank();
    }

    /*
    This tests the specific case in survey creation where the user attempts to add an amount of money to the pool reward that is 
    greater than the amount they currently have in their balance. The expected result is this attempt will return false.
    */
    function testCreateTooExpensive() public {
        vm.startPrank(user);
        smgr.addBalance(5 ether);
        string[] memory answers = new string[](4);
        answers[0] = "B";
        answers[1] = "C";
        answers[2] = "D";
        answers[3] = "E";
        smgr.register("User_one");
        bool create_1 = smgr.createSurvey("A", answers, 5, 20, 10 ether);
        assertEq(create_1, false);
        vm.stopPrank();
    }

    /*
    This test checks if an unregistered user is able to create a survey. Since a user must be registered, the expected result 
    is that the survey can not be created and the function call returns false.
    */
    function testCreateUnregistered() public {
        vm.startPrank(guest);
        smgr.addBalance(5 ether);
        string[] memory answers = new string[](1);
        answers[0] = "B";
        bool create_1 = smgr.createSurvey("A", answers, 5, 20, 3 ether);
        assertEq(create_1, false);
        vm.stopPrank();
    }

    /*
    This test checks if an unregistered user is able to get a list of their own surveys.
    The expected result is that it raises a revert "Must be registered to get surveys", as an unregistered user can not create their 
    own surveys.
    */
    function testGetOwnSurveys_failed() public {
        vm.startPrank(guest);
        vm.expectRevert("Must be registered to get surveys");
        smgr.getOwnSurveys();
        vm.stopPrank();
    }

    /*
    This test examines the functionality of the getActiveSurveys() function, which is used to view all active survey IDs.
    It first tests if calling the function before any surveys are active will return an empty list. It then adds two surveys, before 
    calling the function again. It is expected that the next list will be of length two and contain the IDs of the two new surveys.
    */
    function testGetActiveSurveys() public {
        vm.startPrank(user);
        uint256[] memory active = smgr.getActiveSurveys();
        assertEq(active.length, 0);
        
        smgr.addBalance(5 ether);
        string[] memory answers = new string[](4);
        answers[0] = "B";
        answers[1] = "C";
        answers[2] = "D";
        answers[3] = "E";
        smgr.register("User_one");
        smgr.createSurvey("A", answers, 5, 20, 2 ether);
        smgr.createSurvey("B", answers, 5, 15, 3 ether);
        uint256[] memory new_active = smgr.getActiveSurveys();
        //TODO: IMPORTANT || I can not, for the life of me, figure out how to get a survey in a test case without raising errors. 
        // If someone is able to figure this out, please share your solution. Thanks in advance.
        SurveyManager.Survey memory survey1 = smgr.surveyById(0);
        SurveyManager.Survey memory survey2 = smgr.surveyById[1];
        assertEq(new_active.length, 2);
        assertEq(new_active[0], survey1.id);
        assertEq(new_active[1], survey2.id);
        vm.stopPrank();
    }

    //TODO: test for survey participation and closing the survey

}
