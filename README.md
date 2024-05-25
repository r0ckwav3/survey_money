# Survey Money
(Incomplete documentation, will finish later)

## APIs of the application
createSurvey(string question, string[] answers, uint256 expiration_time, uint256 response_cap, uint256 pooled_reward)

Creates a survey and adds the survey to the survey list. Returns true if the survey creation was successful and false otherwise.

register(String username)

Registers the caller if they are not already a registered user. If the username or address is already registered, return false. Returns true if the user was successfully registered.

surveyRespond(int surveyId, int answer)

People who wish to partipate in a survey do so using surveyRespond(). They input the surveyId of the survey they wish to respond to, as well as one of the numerical options they can respond with. The survey records the answer and increments the corresponding value in the survey's list of response counts. Each user can only respond to a survey once.

If someone successfully responds to a survey, return true. Else, if the user has already responded to the survey, the survey is not active, or the user did not input a valid response, return false.

getOwnSurveys()

As long as a registered user is logged in, they can call this function. getOwnSurveys() returns a list of survey IDs for each survey they own.

getActiveSurveys()

Gets a list of all survey IDs for currently active surveys.

getAnswerOptions(int surveyId)

Returns a string of all the answer options for the survey corresponding to the surveyId.

closeSurvey(int surveyId)

Closes survey, which is only allowed if the survey belongs to the caller and is not already closed, returns true if successfully closed. Return false if the survey does not successfully close.

getSurveyQuestion(uint256 surveyId)

Returns the question of the survey that corresponds to the surveyId.

### Security notes

## How to set up the environment and initialize the application
In order to run this application, the user must have Foundry installed, which can be done by following the steps [here](https://book.getfoundry.sh/getting-started/installation).
The user can run the tests written for the application in a Linux environment by going to the directory that contains this program, then running 
```
$forge test
```
In order to use the application itself, (finish later).

## What kinds of components there are, and what they do
### Account
When a user registers for an account, the application creates an Account data structure that contains their address, account name, and a list of IDs of all currently active surveys they have created.
### Survey
Each survey is managed by its own survey data structure, which contains the address of the survey owner, the survey ID, its question and answer options, the maximum time and responses, and the pooled reward the survey owner has set. Each survey also keeps track of which blockchain addresses have responded, and how many votes each answer option has gotten.

## What kinds of roles users can play, and what they can do
Anyone with a blockchain address can vote in surveys, but without being a registered user, they can not create any. Survey participants will also receive a reward of ETH for participating in a survey. The amount they receive is determined by the survey owner. Registered users can create surveys as well as vote in them **(should registered users be allowed to vote in their own surveys?)**. Users can also determine how much ETH they intend to reward participants of their survey.
(Not sure what else to add that would meet this criteria. This seems like enough? The other sections are longer)
