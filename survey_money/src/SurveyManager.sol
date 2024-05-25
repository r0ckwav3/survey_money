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
        address[] hasUserResponded;
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

    mapping(address=>bool) public isRegistered;
    mapping(string=>bool) public isNameTaken;
    mapping(address=>Account) public registeredUsers;
    mapping(uint256=>Survey) public surveyById;
    Survey[] public activeSurveys;
    uint256 public nextSurveyId;
    uint256 public max_surveys = 100; // temporary solution to the issue of newArray initialization when initializing an Account. Or maybe we can decide to just keep the survey max.
    mapping(address => uint256) private balances;

    constructor() {
        nextSurveyId = 0;
        
    }

    function addBalance(uint256 amount) public returns (bool) {
        balances[msg.sender] += amount;
        return true;
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
            activeSurveys: new uint256[](max_surveys)
        });

        return true;
    }

    // Make sure the user is registered
    // Make sure that the user has inputted enough tokens to cover the reward & other fees
    // Make a survey object and add it into the survey list.
    function createSurvey(string calldata question, string[] calldata answers, uint256 expiration_time, uint256 response_cap, uint256 pooled_reward) public payable returns (bool) {
        require(isRegistered[msg.sender], "Must be registered to create surveys");
        require(msg.value >= pooled_reward + HOST_CUT, "Not enough ETH passed to cover survey reward and host cut");
        uint256 remainingETH = msg.value - (pooled_reward + HOST_CUT);
        require(uint256(remainingETH / response_cap) > 0, "Must have enough ETH to distribute among max respondants");
        require(balances[msg.sender] > pooled_reward, "The reward can not exceed your current balance");
        require(answers.length > 0, "Must include at least one answer option");
        
        balances[msg.sender] -= pooled_reward;
        
        Survey memory newSurvey = Survey({
            owner: address(msg.sender),
            id: nextSurveyId,
            active: true,
            question: question,
            answers: answers,
            answerCounts: new uint256[](answers.length),
            expirationTime: block.timestamp + expiration_time,
            hasUserResponded: new address[](1),
            maxResponses: response_cap,
            reward: pooled_reward
        });
        newSurvey.hasUserResponded = new address[](newSurvey.maxResponses);
        Account storage acc = registeredUsers[msg.sender];

        surveyById[nextSurveyId] = newSurvey;
        activeSurveys.push(newSurvey);
        acc.activeSurveys.push(newSurvey.id);
        nextSurveyId++;

        return true;
    }
    
    // Returns true if successfully responded to
    // Records answer and adds it to the responded mapping in the survey
    function surveyRespond(uint surveyId, uint answer) external returns (bool) {
        for (uint i = 0; i < surveyById[surveyId].hasUserResponded.length; i++) {
            require(surveyById[surveyId].hasUserResponded[i] != msg.sender, "Cannot respond to survey twice");
        }

        require(surveyById[surveyId].active, "Cannot respond to inactive survey");
        require(answer <= surveyById[surveyId].answers.length, "Please select a valid answer");
        // TODO: Should we allow survey owners to respond to their own surveys?
        // require(msg.sender != surveyById[surveyId].owner, "Owner can't answer their own survey.");

        surveyById[surveyId].answerCounts[answer]++;
        surveyById[surveyId].hasUserResponded.push(msg.sender);
        return true;
    }
    

    // User has to be logged in, returns a string for each survey they own
    function getOwnSurveys() external returns (uint256[] memory) {
        require(isRegistered[msg.sender], "Must be registered to get surveys");
        return registeredUsers[msg.sender].activeSurveys;
    }
    // Gets all surveys for a currently active
    function getActiveSurveys() external returns (uint256[] memory) {
        uint256[] memory activeSurveyIds = new uint256[](activeSurveys.length);
        for(uint i = 0 ; i < activeSurveyIds.length; i++){        
            activeSurveyIds[i] = activeSurveys[i].id;
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
        require(msg.sender == survey.owner, "Only the survey owner can close the survey");
        require(survey.active, "Cannot close an inactive survey");
        
        bool ifClosed = false;
        uint256 activeSurveyPos;
        for(uint256 i = 0 ; i < activeSurveys.length; i++){ 
            if(activeSurveys[i].id == surveyId){
                ifClosed = true;
                activeSurveyPos = i;
                break;
            }
        }
        
        if (ifClosed == false) { // check if survey is closed
            return false;
        }

        //Remove Survey from active surveys
        Survey memory temp;
        temp = activeSurveys[activeSurveyPos];
        activeSurveys[activeSurveyPos] = activeSurveys[activeSurveys.length - 1];
        activeSurveys[activeSurveys.length - 1] = temp;
        activeSurveys.pop();

        // TODO: also remove the survey from the account's list of active survey IDs
        //Distribute eth

        uint256 num_responses; // TODO: define this
        uint256 remainingEth = survey.reward - HOST_CUT;
        if (num_responses == 0) {
            balances[survey.owner] += remainingEth;
        } else {
            uint256 perPersonEth = remainingEth / num_responses;
            for (uint i = 0; i < num_responses; i++) {
                address addr = survey.hasUserResponded[i];
                balances[addr] += perPersonEth;
            }
        }

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
