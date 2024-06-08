// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/Vm.sol";
import "../lib/forge-std/src/console.sol";
import {SurveyManager} from "../src/SurveyManager.sol";
import "../src/SurveyManager.sol";

contract SurveyManagerTest is SurveyManager{
    function _getSurvey(uint256 surveyId) public view returns (Survey memory) {
        return getSurvey(surveyId);
    }
}

contract SurveyTest is Test {

    SurveyManagerTest public smgr;
    address public admin = address(0x01);
    address public user = address(0x02);
    address public guest1 = address(0x03);
    address public guest2 = address(0x04);
    address public guest3 = address(0x05);
    address public guest4 = address(0x05);

    function setUp() public {
        vm.startPrank(admin);
        smgr = new SurveyManagerTest();
        deal(admin, 0 ether);
        deal(user, 100 ether);
        deal(guest1, 0 ether);
        deal(guest2, 0 ether);
        deal(guest3, 0 ether);
        deal(guest4, 0 ether);
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
        smgr.register("User_one");
        smgr.addBalance{value: 10 ether}();
        assertEq(address(user).balance, 90 ether, "Failed to deposit ether");
        string[] memory answers = new string[](4);
        answers[0] = "B";
        answers[1] = "C";
        answers[2] = "D";
        answers[3] = "E";
        bool create_1 = smgr.createSurvey("A", answers, 20, 3 ether);
        assertEq(create_1, true);
        string[] memory empty = new string[](0);
        vm.expectRevert("Must include at least one answer option");
        smgr.createSurvey("A", empty, 20, 1 ether); // trying to make a survey with no answers
        vm.stopPrank();
    }

    /*
    This test checks if an unregistered user can deposit ETH to create a survey. Since a user must be registered, the expected result 
    is that it raises a revert "You must be registered to deposit", and the ETH is returned.
    */
    function testCreateUnregistered() public {
        vm.startPrank(guest1);
        deal(guest1, 5 ether);
        vm.expectRevert("You must be registered to deposit");
        smgr.addBalance{value:5 ether}();
        assertEq(address(guest1).balance, 5 ether, "Failed to get ether back");
        vm.stopPrank();
    }

    /*
    This test checks if an unregistered user is able to get a list of their own surveys.
    The expected result is that it raises a revert "Must be registered to get surveys", as an unregistered user can not create their 
    own surveys.
    */
    function testGetOwnSurveys_failed() public {
        vm.startPrank(guest1);
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
        smgr.register("User_one");
        uint256[] memory active = smgr.getActiveSurveys();
        assertEq(active.length, 0);
        smgr.addBalance{value: 5 ether}();
        assertEq(address(user).balance, 95 ether, "Failed to deposit ether");
        string[] memory answers = new string[](4);
        answers[0] = "B";
        answers[1] = "C";
        answers[2] = "D";
        answers[3] = "E";
        smgr.createSurvey("A", answers, 20, 2 ether);
        smgr.createSurvey("B", answers, 15, 1 ether);
        uint256[] memory new_active = smgr.getActiveSurveys();
        SurveyManager.Survey memory survey1 = smgr._getSurvey(0);
        SurveyManager.Survey memory survey2 = smgr._getSurvey(1);
        assertEq(new_active.length, 2);
        assertEq(new_active[0], survey1.id);
        assertEq(new_active[1], survey2.id);
        vm.stopPrank();
    }

    /*
    This function tests that the ether is refunded when the survey closes with no responses.
    */
    function testNoRespond() public{
        vm.startPrank(user);
        smgr.register("User_one");
        smgr.addBalance{value: 5 ether}();
        assertEq(address(user).balance, 95 ether, "Failed to deposit ether");
        string[] memory answers = new string[](4);
        answers[0] = "B";
        answers[1] = "C";
        answers[2] = "D";
        answers[3] = "E";
        smgr.createSurvey("A", answers, 20, 2 ether);
        bool close = smgr.closeSurvey(0);
        assertEq(close, true);
        smgr.withdraw();
        assertEq(address(user).balance, 100 ether - 5000 wei);
        vm.stopPrank();
    }

    /*
    This function tests the ability for other addresses to respond to a survey. It checks that the survey answer counts 
    update correctly, that the addresses that respond to the survey are added to the list of addresses that have responded.
    */
    function testRespond() public {
        vm.startPrank(user);
        smgr.register("User_one");
        smgr.addBalance{value: 5 ether}();
        assertEq(address(user).balance, 95 ether, "Failed to deposit ether");
        string[] memory answers = new string[](4);
        answers[0] = "B";
        answers[1] = "C";
        answers[2] = "D";
        answers[3] = "E";
        smgr.createSurvey("A", answers, 20, 2 ether);
        vm.stopPrank();
        vm.startPrank(guest1);
        smgr.surveyRespond(0, 1);
        vm.stopPrank();
        vm.startPrank(guest2);
        smgr.surveyRespond(0, 3);
        vm.stopPrank();
        vm.startPrank(guest3);
        smgr.surveyRespond(0, 3);
        SurveyManager.Survey memory survey = smgr._getSurvey(0);
        assertEq(survey.hasUserResponded[0], guest1);
        assertEq(survey.hasUserResponded[1], guest2);
        assertEq(survey.hasUserResponded[2], guest3);
        assertEq(survey.answerCounts[0], 0);
        assertEq(survey.answerCounts[1], 1);
        assertEq(survey.answerCounts[2], 0);
        assertEq(survey.answerCounts[3], 2);
        vm.stopPrank();
    }

    /*
    This function tests that someone can retrieve the survey question and answer options as long as they have the survey ID.
    The expected behavior is that getSurveyQuestion(0) returns "A", while getAnswerOptions(0) returns the list of answers passed 
    in as an argument to the createSurvey() function.
    */
    function testGetQA() public {
        vm.startPrank(user);
        smgr.register("User_one");
        smgr.addBalance{value: 5 ether}();
        assertEq(address(user).balance, 95 ether, "Failed to deposit ether");
        string[] memory answers = new string[](4);
        answers[0] = "B";
        answers[1] = "C";
        answers[2] = "D";
        answers[3] = "E";
        smgr.createSurvey("A", answers, 20, 2 ether);
        assertEq(smgr.getSurveyQuestion(0), "A");
        assertEq(smgr.getAnswerOptions(0), answers);
        vm.stopPrank();
    }

    /*
    This function tests if a survey automatically closes once it reaches the response limit. 
    The expected behavior is that once the second participant votes, the survey automatically closes itself, and 
    ether is properly distributed.
    */
    function testCloseSurveyAuto() public {
        vm.startPrank(user);
        smgr.register("User_one");
        smgr.addBalance{value: 5 ether}();
        assertEq(address(user).balance, 95 ether, "Failed to deposit ether");
        string[] memory answers = new string[](4);
        answers[0] = "B";
        answers[1] = "C";
        answers[2] = "D";
        answers[3] = "E";
        smgr.createSurvey("A", answers, 2, 2 ether);
        vm.stopPrank();
        vm.startPrank(guest1);
        smgr.surveyRespond(0, 1);
        vm.stopPrank();
        vm.startPrank(guest2);
        smgr.surveyRespond(0, 3);
        SurveyManager.Survey memory survey = smgr._getSurvey(0);
        assertEq(survey.active, false);
        vm.stopPrank();
        vm.startPrank(guest1);
        smgr.withdraw();
        vm.stopPrank();
        vm.startPrank(guest2);
        smgr.withdraw();
        vm.stopPrank();
        vm.startPrank(admin);
        smgr.withdraw();
        vm.stopPrank();
        assertEq(address(admin).balance, 5000 wei, "Failed to withdraw ether");
        assertEq(address(guest1).balance, 1 ether - 2500 wei, "Failed to withdraw ether");
        assertEq(address(guest2).balance, 1 ether - 2500 wei, "Failed to withdraw ether");
    }

    /*
    This function tests both a manual closeSurvey() call by the survey owner. The expected behavior is that
    the survey will close and the ether is properly distributed
    */
    function testCloseSurveyManual() public {
        vm.startPrank(user);
        smgr.register("User_one");
        smgr.addBalance{value: 5 ether}();
        assertEq(address(user).balance, 95 ether, "Failed to deposit ether");
        string[] memory answers = new string[](4);
        answers[0] = "B";
        answers[1] = "C";
        answers[2] = "D";
        answers[3] = "E";
        smgr.createSurvey("A", answers, 3, 2 ether);
        vm.stopPrank();
        vm.startPrank(guest1);
        smgr.surveyRespond(0, 1);
        vm.stopPrank();
        vm.startPrank(guest2);
        smgr.surveyRespond(0, 3);
        vm.stopPrank();
        vm.startPrank(user);
        bool close = smgr.closeSurvey(0);
        assertEq(close, true);
        vm.stopPrank();
        vm.startPrank(guest1);
        smgr.withdraw();
        vm.stopPrank();
        vm.startPrank(guest2);
        smgr.withdraw();
        vm.stopPrank();
        vm.startPrank(admin);
        smgr.withdraw();
        vm.stopPrank();
        assertEq(address(admin).balance, 5000 wei, "Failed to withdraw ether");
        assertEq(address(guest1).balance, 1 ether - 2500 wei, "Failed to withdraw ether");
        assertEq(address(guest2).balance, 1 ether - 2500 wei, "Failed to withdraw ether");
    }


    /*
    This function tests the getter functions in our application, specifically, the ether reward for the users
    and the answer counts for the survey creator. 
    */
    function testGetSurveyInfo() public{
        vm.startPrank(user);
        smgr.register("User_one");
        smgr.addBalance{value: 5 ether}();
        assertEq(address(user).balance, 95 ether, "Failed to deposit ether");
        string[] memory answers = new string[](4);
        answers[0] = "B";
        answers[1] = "C";
        answers[2] = "D";
        answers[3] = "E";
        smgr.createSurvey("A", answers, 2, 2 ether);
        vm.stopPrank();
        vm.startPrank(guest1);
        smgr.surveyRespond(0, 1);
        uint256 minReward = smgr.getMinPayout(0);
        assertEq(minReward, 1 ether - 2500 wei);
        vm.stopPrank();
        vm.startPrank(guest2);
        smgr.surveyRespond(0, 3);
        vm.stopPrank();
        vm.startPrank(user);
        uint256[] memory results = smgr.getSurveyResults(0);
        assertEq(results[0], 0);
        assertEq(results[1], 1);
        assertEq(results[2], 0);
        assertEq(results[3], 1);
        vm.stopPrank();
        
    }




}
