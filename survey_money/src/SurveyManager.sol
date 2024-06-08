// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

contract SurveyManager {
    struct Survey {
        address owner;
        uint256 id;
        bool active;
        string question;
        string[] answers;
        uint256[] answerCounts;
        address[] hasUserResponded;
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
    address admin;

    constructor() {
        admin = msg.sender;
        nextSurveyId = 0;

    }

    function addBalance() public payable returns (bool) {
        require(msg.value >= 1 ether, "You must deposit at least 1 ether");
        require(isRegistered[msg.sender], "You must be registered to deposit");
        balances[msg.sender] += msg.value;
        return true;
    }

    function withdraw() public{
        uint256 amount = balances[msg.sender];
        balances[msg.sender] = 0;

        (bool sent,) = msg.sender.call{value: amount}("");
        require(sent, "Failed to send balance");
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
    function createSurvey(string calldata question, string[] calldata answers, uint256 response_cap, uint256 pooled_reward) public returns (bool) {
        require(isRegistered[msg.sender], "Must be registered to create surveys");
        require(balances[msg.sender] >= pooled_reward , "Not enough ETH passed to cover survey reward and host cut");
        uint256 remainingETH = balances[msg.sender] - (pooled_reward);
        require(uint256(remainingETH / response_cap) > 0, "Must have enough ETH to distribute among max respondants");
        require(answers.length > 0, "Must include at least one answer option");

        balances[msg.sender] -= pooled_reward;

        Survey memory newSurvey = Survey({
            owner: address(msg.sender),
            id: nextSurveyId,
            active: true,
            question: question,
            answers: answers,
            answerCounts: new uint256[](answers.length),
            hasUserResponded: new address[](0),
            maxResponses: response_cap,
            reward: pooled_reward
        });
        Account storage acc = registeredUsers[msg.sender];

        surveyById[nextSurveyId] = newSurvey;
        activeSurveys.push(newSurvey);
        acc.activeSurveys.push(newSurvey.id);
        nextSurveyId++;
        return true;
    }

    // Used for testing to make sure surveys are being properly edited
    function getSurvey(uint256 surveyId) internal view returns (Survey memory) {
        return surveyById[surveyId];
    }

    // Returns true if successfully responded to
    // Records answer and adds it to the responded mapping in the survey
    function surveyRespond(uint surveyId, uint answer) external returns (bool) {
        require(surveyById[surveyId].hasUserResponded.length < surveyById[surveyId].maxResponses, "Response cap reached"); // If closeSurvey() works properly, this should never be called
        require(surveyById[surveyId].owner != msg.sender, "Owner can not respond to their own survey");

        for (uint i = 0; i < surveyById[surveyId].hasUserResponded.length; i++) {
            require(surveyById[surveyId].hasUserResponded[i] != msg.sender, "Cannot respond to survey twice");
        }

        require(surveyById[surveyId].active, "Cannot respond to inactive survey");
        require(answer < surveyById[surveyId].answers.length, "Please select a valid answer");

        surveyById[surveyId].answerCounts[answer]++;
        surveyById[surveyId].hasUserResponded.push(msg.sender);

        if ((surveyById[surveyId].hasUserResponded.length == surveyById[surveyId].maxResponses)) {
            closeSurvey(surveyId);
        }

        return true;
    }


    // User has to be logged in, returns a string for each survey they own
    function getOwnSurveys() external view returns (uint256[] memory) {
        require(isRegistered[msg.sender], "Must be registered to get surveys");

        return registeredUsers[msg.sender].activeSurveys;
    }
    // Gets all surveys for a currently active
    function getActiveSurveys() external view returns (uint256[] memory) {
        uint256[] memory activeSurveyIds = new uint256[](activeSurveys.length);
        for(uint i = 0 ; i < activeSurveyIds.length; i++){
            activeSurveyIds[i] = activeSurveys[i].id;
        }
        return activeSurveyIds;
    }

    // Gets all options for the given survey
    function getAnswerOptions(uint256 surveyId) external view returns (string[] memory) {
        require(surveyById[surveyId].active, "surveyId is not valid");
        return surveyById[surveyId].answers;
    }
    // Gets the survey question
    function getSurveyQuestion(uint256 surveyId) external view returns (string memory){
        require(surveyById[surveyId].active, "surveyId is not valid");
        return surveyById[surveyId].question;
    }

    function getSurveyResults(uint256 surveyId) external view returns (uint256[] memory){
        require(msg.sender == surveyById[surveyId].owner, "You are not the owner of the survey");
        require(!surveyById[surveyId].active, "You cannot view the results of an active survey");
        return surveyById[surveyId].answerCounts;
    }

    function getMinPayout(uint256 surveyId) external view returns (uint256){
        require(surveyById[surveyId].active, "surveyId is not valid");
        return (surveyById[surveyId].reward - HOST_CUT)/ (surveyById[surveyId].maxResponses);
    }


    // Closes survey, only if survey belongs to the caller and is not already closed, returns if successfully closed
    // IMPORTANT NOTE: So turns out Solidity doesn't allow automatic running of functions when a certain timestamp is reached, so automatically closing a survey would require
    // off-chain programming in a different language or using cron-like service, which imo isn't worth the effort for this project. Fortunately, the track requirements say
    // "A survey owner can close the survey OR wait for it to close after the expiry block timestamp OR when it reaches the maximum accepted data points."
    // This means we can probably just ditch the expiration timestamp without points being deducted.
    function closeSurvey(uint256 surveyId) public returns (bool) {
        Survey storage survey = surveyById[surveyId];
        Account storage owner = registeredUsers[msg.sender];
        require((msg.sender == survey.owner) || (survey.maxResponses == survey.hasUserResponded.length), "Survey closure not authorized");
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

        survey.active = false;
        //Remove Survey from active surveys
        Survey memory temp;
        temp = activeSurveys[activeSurveyPos];
        activeSurveys[activeSurveyPos] = activeSurveys[activeSurveys.length - 1];
        activeSurveys[activeSurveys.length - 1] = temp;
        activeSurveys.pop();

        // Also remove the survey from the account's list of active survey IDs
        bool ifClosed_ = false;
        uint256 activeSurveyPos_;
        for(uint256 i = 0 ; i < owner.activeSurveys.length; i++){
            if(owner.activeSurveys[i] == surveyId){
                ifClosed_ = true;
                activeSurveyPos_ = i;
                break;
            }
        }

        if (ifClosed_) {
            uint256 acctemp;
            acctemp = owner.activeSurveys[activeSurveyPos_];
            owner.activeSurveys[activeSurveyPos_] = owner.activeSurveys[owner.activeSurveys.length - 1];
            owner.activeSurveys[owner.activeSurveys.length - 1] = acctemp;
            owner.activeSurveys.pop();
        }
        //Distribute eth

        uint256 num_responses = survey.hasUserResponded.length;
        uint256 remainingEth = survey.reward - HOST_CUT;
        balances[admin] += HOST_CUT;

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
