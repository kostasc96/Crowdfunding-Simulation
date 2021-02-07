\// SPDX-License-Identifier: MIT


// SPDX-License-Identifier: Something Else

pragma solidity >= 0.5.0;


contract Crowdfunding{
    
    //Existing projects
    Project[] private projects;
    
    // if not select one from existing projects, kick start new project
    event NewProject(
        address payable platformOwner,
        address payable campaignAdmin,
        string projectTitle,
        uint minimumAmount,
        uint lengthOfTime
        );
        
        
    // function to start a new project 
    function iniateProject(bytes32 projectTitle, address payable platformOwn, address payable campaignAdm, uint minimumAmount, uint lengthOfTime, uint startDate) external {
        uint untilDate = block.timestamp + lengthOfTime * 1 days;
        Project newProject = new Project(projectTitle, minimumAmount, untilDate, 0, startDate);
        projects.push(newProject);
        emit NewProject(platformOwn,campaignAdm, bytes32ToString(projectTitle), minimumAmount, untilDate);
    }
    
    
    // get all projects 
    function getProjects() external view returns(Project[] memory){
        return projects;
    }
    
    
    function bytes32ToString(bytes32 _bytes32) public pure returns (string memory) {
        uint8 i = 0;
        while(i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }
}




contract Project {
    
    enum State{NowFundRaising, Successful, NotSuccessful}
    
    enum ProjectStatus {Active,Finished}
    
    address payable public campaignAdmin;
    address payable public platformOwner;
    uint public minimumAmount;   // how much money at least to be collected
    uint public currentAmount;
    uint public remainingDays;
    uint public startDate;
    string public projectTitle;
    mapping (address => uint) public contributions;
    
    State public state;
    ProjectStatus public projectStatus;
    
    
    constructor(bytes32 projectTit, uint minAmount, uint totDays, uint am, uint start) public {
        projectTitle = bytes32ToString(projectTit);
        minimumAmount = minAmount;
        remainingDays = totDays;
        currentAmount = am;
        state = State.NowFundRaising;
        projectStatus = ProjectStatus.Active;
        startDate = start;
    }
    
    
    function bytes32ToString(bytes32 _bytes32) public pure returns (string memory) {
        uint8 i = 0;
        while(i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }
    
    
    // process to track down contributions
    event FundingReceived(address contributor, uint amount, uint totalContributed);
    
    // if contributor wants to withdraw his contribution
    event Withdraw(address contributor, uint amount);
    
    
    modifier isCreator(){
        require(msg.sender == campaignAdmin);
        _;
    }
    
    modifier inState(State state1){
        require(state == state1);
        _;
    }
    
    modifier inProjectStatus(ProjectStatus status){
        require(projectStatus == status);
        _;
    }
    
    
    function contribute() external inState(State.NowFundRaising) payable {
        require(msg.sender != campaignAdmin);
        contributions[msg.sender] = contributions[msg.sender] + msg.value;
        currentAmount = currentAmount + msg.value;
        emit FundingReceived(msg.sender, msg.value, currentAmount);
    }
    
    
    // check if duration of campaign has passed, anyone may declare campaign closed
    function checkIfCampaignIsActive() public{
        if(block.timestamp > startDate + remainingDays * 1 days){
            projectStatus = ProjectStatus.Finished;    // if days have passed, anyone may declare the campaign closed
        }
    }
    
    
    // when campaign finishes, check if amount meets our expectations
    function checkCampaignIsSuccessful() public{
        require(projectStatus == ProjectStatus.Finished);
        if(currentAmount > minimumAmount){
            state = State.Successful;
        } else {
            state = State.NotSuccessful;
        }
    }
    
    
    // withdraw at any time while campaign is open
    function withdraw() public inProjectStatus(ProjectStatus.Active) returns (bool){
        require(contributions[msg.sender] > 0);
        
        uint amountToWithdraw = contributions[msg.sender];
        contributions[msg.sender] = 0;
        
        //check if amount to withdraw is equal to user's contributions
        if (!msg.sender.send(amountToWithdraw)) {
            contributions[msg.sender] = amountToWithdraw;
            return false;
        } else {
            currentAmount = currentAmount - amountToWithdraw;
        }
    
        return true;
    }
    
    
    // if enough funds collected, platorm owners gets 5% and campaign admin assigned 95%
    function collectMoneyIfSuccessful() public inProjectStatus(ProjectStatus.Finished) {
        checkCampaignIsSuccessful();
        require(state == State.Successful);
        uint totalMoney = currentAmount;
        currentAmount = 0;
        uint moneyToPlatformOwner = totalMoney* 5/100;
        uint moneyToCampaignAdmin = totalMoney* 95/100;
        platformOwner.transfer(moneyToPlatformOwner);
        campaignAdmin.transfer(moneyToCampaignAdmin);
    }
    
    
    // if campaign not successful, then contributors receive refund 
    function getRefundIfNotSuccessful() public inProjectStatus(ProjectStatus.Finished)  {
        checkCampaignIsSuccessful();
        require(state == State.NotSuccessful);
        require(contributions[msg.sender] > 0);
        uint amountToRefund = contributions[msg.sender];
        contributions[msg.sender] = 0;
        msg.sender.transfer(amountToRefund);
        currentAmount = currentAmount - amountToRefund;
    }
    
    
    function destroy() public {
        require(msg.sender == platformOwner);
        // Verify that campaign not active
        require(projectStatus == ProjectStatus.Finished);
        selfdestruct(platformOwner);
    }
    
}