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

contract Attacker {
    SurveyManagerTest surveyManager;
    uint256 reentrancyCount;

    constructor(SurveyManagerTest _surveyManager) {
        surveyManager = _surveyManager;
        reentrancyCount = 0;
    }

    function attack() public payable {
        surveyManager.withdraw();
    }

    function fallback() external payable {
        reentrancyCount++;
        if(reentrancyCount < 10){
            surveyManager.withdraw();
        }
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
    Attacker public attacker;

    // TODO: just set up a lot of this stuff outside of pranks so they don't need to be repeated so much

    function setUp() public {
        vm.startPrank(admin);
        smgr = new SurveyManagerTest();
        deal(admin, 0 ether);
        deal(user, 100 ether);
        deal(guest1, 0 ether);
        deal(guest2, 0 ether);
        deal(guest3, 0 ether);
        deal(guest4, 0 ether);
        attacker = new Attacker(smgr);
        deal(address(attacker), 100 ether);
        vm.stopPrank();
    }


    /*
    This function aims to test that withdraw, the only way to recieve ether from the application
    is resistant from a reentry attack. Here the attacker will try an reentry attack using the withdraw
    function in order to withdraw more ether than they put in.
    */
    function testReentry() public{
        vm.startPrank(address(attacker));
        smgr.register("Attacker");
        smgr.addBalance{value: 5 ether}();
        vm.expectRevert("Failed to send balance");
        attacker.attack();
        assertEq(address(attacker).balance, 95 ether);
        vm.stopPrank();
    }

    /*
    This tests a user attempting to register twice after creating a survey. If the second register was successful,
    the user would lose the survey in their active survey list causing inconsistencies in the system. However, the expected
    result is that the second register will fail and the survey will still be in the user's active surveys.
    */
    function testRegisterTwice() public{
        vm.startPrank(user);
        smgr.register("User_one");
        smgr.addBalance{value: 5 ether}();
        string[] memory answers = new string[](4);
        answers[0] = "B";
        answers[1] = "C";
        answers[2] = "D";
        answers[3] = "E";
        smgr.createSurvey("A", answers, 5, 2 ether);
        bool success = smgr.register("User_two");
        assertEq(success, false);
        uint256[] memory active = smgr.getActiveSurveys();
        assertEq(active.length, 1);
        assertEq(active[0], 0);
        vm.stopPrank();
    }


    /*
    This tests that a user cannot respond to a closed survey and that the response will not impact the results recieved
    by the user. If the user could respond to a closed survey, it would be unfair to the responder whose response would have
    been read, but they wouldn't recieve any reward.
    */
    function testRespondClosedSurvey() public{
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
        vm.startPrank(user);
        bool close = smgr.closeSurvey(0);
        assertEq(close, true);
        vm.stopPrank();
        vm.startPrank(guest2);
        vm.expectRevert("Cannot respond to inactive survey");
        smgr.surveyRespond(0, 3);
        vm.stopPrank();
        vm.startPrank(user);
        uint256[] memory results = smgr.getSurveyResults(0);
        assertEq(results[0], 0);
        assertEq(results[1], 1);
        assertEq(results[2], 0);
        assertEq(results[3], 0);
        vm.stopPrank();
    }

    /*
    This tests the specific case in survey creation where the user attempts to add an amount of money to the pool reward that is 
    greater than the amount they currently have in their balance, potentially causing more ether to be given out than what was put
    in. The expected result is this attempt will return false.
    */
    function testCreateTooExpensive() public {
        vm.startPrank(user);
        smgr.register("User_one");
        smgr.addBalance{value: 5 ether}();
        string[] memory answers = new string[](4);
        answers[0] = "B";
        answers[1] = "C";
        answers[2] = "D";
        answers[3] = "E";
        vm.expectRevert("Not enough ETH passed to cover survey reward and host cut");
        smgr.createSurvey("A", answers, 20, 10 ether);
        vm.stopPrank();
    }

    /*
    This function tests a user attempting to close a survey twice in an attempt have ether distributed twice. 
    The expected behavior is attempts to manually close it the second time will fail, and ether is only distributed once.
    */
    function testCloseSurveyTwice() public {
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
        smgr.closeSurvey(0);
        vm.expectRevert("Cannot close an inactive survey");
        smgr.closeSurvey(0);
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
    This function tests an invalid attempts to close the survey by a user that is not the owner, potentially 
    taking the whole pool for themselves if they are the only respondant. The expected behavior is that anyone 
    not the survey owner attempting to close the survey will be unable to, the survey owner can manually close 
    the survey while it is still active, and that anyone, including the owner, attempting to close the survey 
    once it is already inactive will cause a revert.
    */
    function testCloseSurveyNonUser() public {
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
        vm.expectRevert("Survey closure not authorized");
        smgr.closeSurvey(0);
        vm.stopPrank();
        vm.startPrank(user);
        bool close = smgr.closeSurvey(0);
        assertEq(close, true);
        vm.expectRevert("Cannot close an inactive survey");
        smgr.closeSurvey(0);
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
    This function tests that respondants can't respond with invalid answers or respond twice. It is expected that 
    disallowed behavior will return the correct reverts and that the survey object will update the way it 
    is intended to.
    */
    function testRespondTwice() public {
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
        smgr.surveyRespond(0, 3);
        vm.expectRevert("Cannot respond to survey twice");
        smgr.surveyRespond(0, 2);
        vm.stopPrank();
        vm.startPrank(guest2);
        vm.expectRevert("Please select a valid answer");
        smgr.surveyRespond(0, 4);
        smgr.surveyRespond(0, 3);
        SurveyManager.Survey memory survey = smgr._getSurvey(0);
        assertEq(survey.hasUserResponded[0], guest1);
        assertEq(survey.hasUserResponded[1], guest2);
        assertEq(survey.answerCounts[0], 0);
        assertEq(survey.answerCounts[1], 0);
        assertEq(survey.answerCounts[2], 0);
        assertEq(survey.answerCounts[3], 2);
        vm.stopPrank();
    }

    /*
    This function tests that an owner cannot respond to their own survey in order to get some ether back.
    It is expected that this response will be reverted and the owner's response will not be counted
    */
    function testRespondOwner() public {
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
        vm.expectRevert("Owner can not respond to their own survey");
        smgr.surveyRespond(0,1);
        SurveyManager.Survey memory survey = smgr._getSurvey(0);
        assertEq(survey.answerCounts[1], 0);
        vm.stopPrank();
    }

    /*
    This function tests to make sure that after a survey closes, a user that is not the survey's owner cannot
    view the results. This is done because we want to ensure that the results of the survey is private to the 
    creator of the survey. 
    */
    function testSurveyResponseNonOwner() public{
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
        vm.expectRevert("You are not the owner of the survey");
        smgr.getSurveyResults(0);
        vm.stopPrank();
    }

    /*
    This function tests a user attempting to access questions and answers after a survey has already closed
    as well as accessing questions and answers for invalid surveyId numbers, with the former being there to 
    ensure more privacy to surveys in the sense that respondants can only look at the questions and answers for
    as long as the survey is active. 
    */
    function testGetInvalidSurveyId() public{
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
        vm.stopPrank();
        vm.startPrank(guest1);
        vm.expectRevert("surveyId is not valid");
        smgr.getSurveyQuestion(0);
        vm.expectRevert("surveyId is not valid");
        smgr.getAnswerOptions(0);
        vm.expectRevert("surveyId is not valid");
        smgr.getSurveyQuestion(1);
        vm.expectRevert("surveyId is not valid");
        smgr.getAnswerOptions(1);

        vm.stopPrank();
    }

}
