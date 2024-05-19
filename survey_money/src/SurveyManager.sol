// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract SurveyManager {
    struct Survey {
        address owner;
        uint256 id;
        bool active;
        string question;
        string[] answers;
        mapping(address => bool) hasUserResponded;
        uint256 maxTime; //unix time in seconds
        uint256 maxResponses;
        uint256 rewardEth;
    }

    struct Account {
        address userAddress;
        string name;
        uint256[] activeSurveys;
    }

    uint256 public constant HOST_CUT = 1; //flat rate in eth

    mapping(address=>bool) isRegistered;
    mapping(string=>bool) isNameTaken;
    mapping(address=>Account) registeredUsers;
    mapping(uint256=>Survey) surveyByID;
    Survey[] public activeSurveys;
    uint256 public nextSurveyId;

    constructor() {
        nextSurveyId = 0;
        
    }

    // Registers sender if not already registered
    // If the username or address is already registered, return false
    function register(string username) public returns (bool) {
        if (isRegistered[msg.sender] || isNameTaken[username]) {
            return false;
        }
        
        isRegistered[msg.sender] = true;
        isNameTaken[username] = true;
        registeredUsers[msg.sender] = Account({
            userAddress: msg.sender,
            name: username,
            activeSurveys: []
        });

        return true;
    }

    // Make sure the user is registered
    // Make sure that the user has inputted enough tokens to cover the reward & other fees
    // Make a survey object and add it into the survey list.
    function createSurvey(string question, string[] answers, uint expiration_time, uint response_cap, uint pooled_reward) public returns (bool) {
        if (!isRegistered[msg.sender]) { // Make sure the user is registered
            return false;
        }
        uint256 remainingETH = pooled_reward - host_cut;
    }
    
    // Returns true if successfully responded to
    // Records answer and adds it to the responded mapping in the survey
    function surveyRespond(int surveyId, int answer)  public returns (bool) {
        if(surveyById[surveyId].hasUserResponded[msg.sender]){
            return false;
        }
        surveyById[surveyId].answers[answer]++;
        surveyById[surveyI]
        return true;
    }
    

    // User has to be logged in, returns a string for each survey they own
    function getOwnSurveys() public returns (uint256[]) {
        if(isRegistered[msg.sender]){
            return registeredUsers[msg.sender].activeSurveys;
        }else{
            return [];
        }
    }
    // Gets all surveys for a currently active
    function getActiveSurveys() public returns (uint256[]) {}
    // Gets all options for the given survey
    function getAnswerOptions(uint256 surveyId)  public returns (string[]) {
        if(!surveyById[surveyId].active){
            return [];
        }else{
            return surveyById[surveyId].answers;
        }
    }
    // Gets the survey question
    function getSurveyQuestion(uint256 surveyId) public returns (string){
        if(!surveyById[surveyId].active){
            return "";
        }else{
            return surveyById[surveyId].question;
        }
    }
    // Closes survey, only if survey belongs to the caller and is not already closed, returns if successfully closed
    function closeSurvey(uint256 surveyId) public returns (bool) {}
}


// contract Counter {
//     uint256 public number;

//     function setNumber(uint256 newNumber) public {
//         number = newNumber;
//     }

//     function increment() public {
//         number++;
//     }
// }
