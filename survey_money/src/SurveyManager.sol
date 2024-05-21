// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract SurveyManager {
    struct Survey {
        address owner;
        uint256 id;
        bool active;
        string question;
        string[] answers;
        uint256[] answerCounts;
        mapping(address => bool) hasUserResponded;
        uint256 expirationTime; //timestamp it should expire (unix in seconds)
        uint256 maxResponses;
        uint256 reward; //in wei
    }

    struct Account {
        address userAddress;
        string name;
        uint256[] activeSurveys;
    }

    uint256 public constant HOST_CUT = 5000; //flat rate in wei

    mapping(address=>bool) isRegistered;
    mapping(string=>bool) isNameTaken;
    mapping(address=>Account) registeredUsers;
    mapping(uint256=>Survey) surveyById;
    Survey[] public activeSurveys;
    uint256 public nextSurveyId;

    constructor() {
        nextSurveyId = 0;
        
    }

    // Registers sender if not already registered
    // If the username or address is already registered, return false
    function register(string calldata username) public returns (bool) {
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
    function createSurvey(string calldata question, string[] calldata answers, uint256 expiration_time, uint256 response_cap, uint256 pooled_reward) public returns (bool) {
        if (!isRegistered[msg.sender]) { // Make sure the user is registered
            return false;
        }
        uint256 remainingETH = pooled_reward - HOST_CUT; //todo: factor in gas costs?
        if (uint256(remainingETH / response_cap) <= 0) { // not enough ETH to divide among user particiants
            return false;
        }
        
        Survey memory newSurvey = Survey({
            owner: address(msg.sender),
            id: nextSurveyId,
            question: question,
            answers: answers,
            answerCounts: new uint256[](answers.length),
            expirationTime: block.Timestamp + expiration_time,
            maxResponses: response_cap,
            reward: pooled_reward
        });
        surveyById[nextSurveyId] = newSurvey;
        activeSurveys.push(newSurvey);
        nextSurveyId++;

        return true;
    }
    
    // Returns true if successfully responded to
    // Records answer and adds it to the responded mapping in the survey
    function surveyRespond(int surveyId, int answer) external returns (bool) {
        if(!surveyById[surveyId].active){
            return false;
        }
        if(surveyById[surveyId].hasUserResponded[msg.sender]){
            return false;
        }
        //TODO: also check that the answer number is one of the options for the survey

        surveyById[surveyId].answerCount[answer]++;
        surveyById[surveyId].hasUserResponded[msg.sender] = true;
        return true;
    }
    

    // User has to be logged in, returns a string for each survey they own
    function getOwnSurveys() external returns (uint256[] memory) {
        require(isRegistered[msg.sender], "Must be registered to get surveys");
        return registeredUsers[msg.sender].activeSurveys;
    }
    // Gets all surveys for a currently active
    function getActiveSurveys() external returns (uint256[] memory) {
        uint256[] memory activeSurveyIds;
        for(int i = 0 ; i < activeSurveyIds.length; i++){        
            activeSurveyIds.push(activeSurveys[i].id); 
        }
        return activeSurveyIds; 
    }

    // Gets all options for the given survey
    function getAnswerOptions(uint256 surveyId)  external returns (string[] memory) {
        require(surveyById[surveyId].active, "surveyId is not valid");
        return surveyById[surveyId].answers;
    }
    // Gets the survey question
    function getSurveyQuestion(uint256 surveyId) external returns (string memory){
        require(surveyById[surveyId].active, "surveyId is not valid");
        return surveyById[surveyId].question;
    }
    // Closes survey, only if survey belongs to the caller and is not already closed, returns if successfully closed
    function closeSurvey(uint256 surveyId) public payable returns (bool) {
        Survey memory survey = surveyById[surveyId];
        if (msg.sender != survey.owner) {
            return false;
        }
        
        uint activeSurveyPos = -1;
        for(uint256 i = 0 ; i < activeSurveys.length; i++){ 
            if(activeSurveys[i].id == surveyId){
                activeSurveyPos = i;
                break;
            }
        }
        
        if (activeSurveyPos < 0) { // check if survey is closed
            return false;
        }

        //Remove Survey from active surveys
        Survey memory temp;
        temp = activeSurveys[activeSurveyPos];
        activeSurveys[activeSurveyPos] = activeSurveys[activeSurveys.lenght - 1];
        activeSurveys[activeSurveys.length - 1] = temp;
        activeSurveys.pop();

        // TODO: also remove the survey from the account's list of active survey IDs
        //Distribute eth

        uint256 remainingEth = survey.response - HOST_CUT;
        uint256 perPersonEth = remainingEth / survey.
        

        return true;
    }
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
