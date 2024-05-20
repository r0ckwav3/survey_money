# Survey Money
(Incomplete documentation, will finish later)
APIs of the application: what they do, how they are called, what they return, and any special and security notes
CreateSurvey(string calldata question, string[] calldata answers, uint256 expiration_time, uint256 response_cap, uint256 pooled_reward)
Creates a survey and adds the survey to the survey list

How to set up the environment and initialize the application

What kinds of components there are, and what they do
Account
When a user registers for an account, the application creates an Account data structure that contains their address, account name, and a list of IDs of all currently active surveys they have created.
Survey
Each survey is managed by its own survey data structure, which contains the address of the survey owner, the survey ID, its question and answer options, the maximum time and responses, and the pooled reward the survey owner has set. Each survey also keeps track of which blockchain addresses have responded, and how many votes each answer option has gotten.

What kinds of roles users can play, and what they can do
- Anyone with a blockchain address can vote in surveys, but without being a registered user, they can not create any. Survey participants will also receive a reward of ETH for participating in a survey. The amount they receive is determined by the survey owner.
- Registered users can create surveys as well as vote in them (should registered users be allowed to vote in their own surveys?)
- Users can also determine how much ETH they intend to reward participants of their survey.
(Not sure what else to add that would meet this criteria. This seems like enough? The other sections are longer)
