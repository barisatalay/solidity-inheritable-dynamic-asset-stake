// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/*
 * @title BARIS ATALAY
 * @dev Set & change owner
 * 
 * @IMPORTANT Reward tokens to be distributed to the stakers must be deposited into the contract.
 * 
 */
 contract DynamicAssetStake is Context, Ownable{
    event Stake(address indexed from, uint256 amount);
    event UnStake(address indexed from, uint256 amount);
    event YieldWithdraw(address indexed to);
    
    struct PendingRewardResponse{               //
        bytes32 name;                       // Byte equivalent of the name of the pool token
        uint256 amount;                     // TODO...
        uint id;                            // Id of Reward
    }
    
    struct RewardDef{
        address tokenAddress;               // Contract Address of Reward token
        uint256 rewardPerSecond;            // Accepted reward per second 
        bytes32 name;                       // Byte equivalent of the name of the pool token
        uint8 feeRate;                      // Fee Rate for Reward Harvest
        uint id;                            // Id of Reward
    }

    struct PoolDef{
        address tokenAddress;               // Contract Address of Pool token
        uint rewardCount;                   // Amount of the reward to be won from the pool
        uint id;                            // Id of pool
        bool active;                        // Pool active status
    }

    struct PoolDefExt{
        uint256 expiryTime;                 // The pool remains active until the set time
        uint256 createTime;                 // Pool creation time
        bytes32 name;                       // Byte equivalent of the name of the pool token
    }

    struct PoolVariable{                    // Only owner can edit
        uint256 balanceFee;                 // Withdraw Fee for contract Owner;
        uint256 lastRewardTimeStamp;        // Last date reward was calculated
        uint8 feeRate;                      // Fee Rate for UnStake
    }

    struct PoolRewardVariable{
        uint256 accTokenPerShare;           // Token share to be distributed to users
        uint256 balance;                    // Pool Contract Token Balance
    }
    
    // Info of each user
    struct UserDef{ 
        address id;                         // Wallet Address of staker
        uint256 stakingBalance;             // Amount of current staking balance
        uint256 startTime;                  // Staking start time
    }

    struct UserRewardInfo{
        uint256 rewardBalance;
        uint rewardID;
    }

    uint private stakeIDCounter;
    //Pool ID => PoolDef 
    mapping(uint => PoolDef) public poolList;
    //Pool ID => Underused Pool information 
    mapping(uint => PoolDefExt) public poolListExtras;
    //Pool ID => Pool Variable info
    mapping(uint => PoolVariable) public poolVariable;
    //Pool ID => (RewardIndex => RewardDef) 
    mapping(uint => mapping(uint => RewardDef)) public poolRewardList;
    //Pool ID => (RewardIndex => PoolRewardVariable)
    mapping(uint => mapping(uint => PoolRewardVariable)) public poolRewardVariableInfo;
    //Pool ID => (RewardIndex => Amount of distributed reward to staker) 
    mapping(uint => mapping(uint => uint)) public poolPaidOut;
    //Pool ID => Amount of Stake from User
    mapping(uint => uint) public poolTotalStake;


    //Pool ID => (User ID => User Info)
    mapping(uint => mapping(address => UserDef)) poolUserInfo;
    //Pool ID => (User ID => (Reward Id => Reward Info))
    mapping (uint => mapping(address => mapping(uint => UserRewardInfo))) poolUserRewardInfo;

    
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    constructor(){
        stakeIDCounter = 0;
    }

    /// @notice             TODO...
    /// @param  _stakeID    Id of the stake pool
    function UpdatePoolRewardShare(uint _stakeID) internal virtual {
        uint256 lastTimeStamp = block.timestamp;
        PoolVariable storage selectedPoolVariable = poolVariable[_stakeID];

        if (lastTimeStamp <= selectedPoolVariable.lastRewardTimeStamp) {
            lastTimeStamp = selectedPoolVariable.lastRewardTimeStamp;
        }
        if (poolTotalStake[_stakeID] == 0) {
            selectedPoolVariable.lastRewardTimeStamp = block.timestamp;
            return;
        }
        uint256 timeDiff = lastTimeStamp.sub(selectedPoolVariable.lastRewardTimeStamp);

        //..:: Calculating the reward shares of the pool ::..
        uint rewardCount = poolList[_stakeID].rewardCount;
        for (uint i=0; i<rewardCount; i++) {
            uint256 currentReward = timeDiff.mul(poolRewardList[_stakeID][i].rewardPerSecond);
            poolRewardVariableInfo[_stakeID][i].accTokenPerShare = poolRewardVariableInfo[_stakeID][i].accTokenPerShare.add(currentReward.mul(1e36).div(poolTotalStake[_stakeID]));
        }
        //..:: Calculating the reward shares of the pool ::..
        
        selectedPoolVariable.lastRewardTimeStamp = block.timestamp;
    }

    /// @notice             TODO...
    /// @param  _stakeID    Id of the stake pool
    /// @return             TODO...
    function showPendingReward(uint _stakeID) public virtual view returns(PendingRewardResponse[] memory) { 
        UserDef memory user =  poolUserInfo[_stakeID][_msgSender()];
        uint256 lastTimeStamp = block.timestamp;
        uint rewardCount = poolList[_stakeID].rewardCount;
        PendingRewardResponse[] memory result = new PendingRewardResponse[](rewardCount);

        for (uint RewardIndex=0; RewardIndex<rewardCount; RewardIndex++) {
            uint _accTokenPerShare = poolRewardVariableInfo[_stakeID][RewardIndex].accTokenPerShare;

            if (lastTimeStamp > poolVariable[_stakeID].lastRewardTimeStamp && poolTotalStake[_stakeID] != 0) {
                uint256 timeDiff = lastTimeStamp.sub(poolVariable[_stakeID].lastRewardTimeStamp);
                uint256 currentReward = timeDiff.mul(poolRewardList[_stakeID][RewardIndex].rewardPerSecond);
                _accTokenPerShare = _accTokenPerShare.add(currentReward.mul(1e36).div(poolTotalStake[_stakeID]));
            }
            result[RewardIndex] = PendingRewardResponse({
                id:     RewardIndex,
                name:   poolRewardList[_stakeID][RewardIndex].name,
                amount: user.stakingBalance
                            .mul(_accTokenPerShare)
                            .div(1e36)
                            .sub(poolUserRewardInfo[_stakeID][_msgSender()][RewardIndex].rewardBalance) 
            });
        }

        return result;
    }

    /// @notice             Withdraw assets by pool id
    /// @param  _stakeID    Id of the stake pool
    /// @param  _amount     Amount of withdraw asset
    function unStake(uint _stakeID, uint256 _amount) public {
        require(_msgSender() != address(0), "Stake: Staker address not specified!");
        //IERC20 selectedToken = getStakeContract(_stakeID);
        UserDef storage user =  poolUserInfo[_stakeID][_msgSender()];

        require(user.stakingBalance > 0, "Stake: does not have staking balance");
        // Amount leak control
        if (_amount > user.stakingBalance) _amount = user.stakingBalance;

        // "_amount" removed to Total staked value by Pool ID
        if (_amount > 0)
            poolTotalStake[_stakeID] = poolTotalStake[_stakeID].sub(_amount); 
        
        UpdatePoolRewardShare(_stakeID);

        sendPendingReward(_stakeID, user, true);
        
        uint256 unStakeFee;                
        if (poolVariable[_stakeID].feeRate  > 0)
            unStakeFee = _amount
                            .mul(poolVariable[_stakeID].feeRate)
                            .div(100);

        // Calculated unStake amount after commission deducted
        uint256 finalUnStakeAmount = _amount.sub(unStakeFee);
                
        // ..:: Updated last user info ::..
        user.startTime = block.timestamp;
        user.stakingBalance = user.stakingBalance.sub(finalUnStakeAmount);
        // ..:: Updated last user info ::..

        if (finalUnStakeAmount > 0)
            getStakeContract(_stakeID).safeTransfer(_msgSender(), finalUnStakeAmount);
        emit UnStake(_msgSender(), _amount);
    }

    function sendPendingReward(uint _stakeID, UserDef memory _user, bool _subtractFee) private {
        // ..:: Pending reward will be calculate and add to transferAmount, before transfer unStake amount ::..
        uint rewardCount = poolList[_stakeID].rewardCount;
        for (uint RewardIndex=0; RewardIndex<rewardCount; RewardIndex++) {

            uint256 userRewardedBalance = poolUserRewardInfo[_stakeID][_msgSender()][RewardIndex].rewardBalance;
            
            uint pendingAmount = _user.stakingBalance
                                            .mul(poolRewardVariableInfo[_stakeID][RewardIndex].accTokenPerShare)
                                            .div(1e36)
                                            .sub(userRewardedBalance);

            if (pendingAmount > 0) {
                uint256 finalRewardAmount;
                
                if (_subtractFee){
                    uint256 pendingRewardFee; 
                    if (poolRewardList[_stakeID][RewardIndex].feeRate > 0)
                        pendingRewardFee = pendingAmount
                                            .mul(poolRewardList[_stakeID][RewardIndex].feeRate)
                                            .div(100);
                
                    // Commission fees received are recorded for reporting
                    poolVariable[_stakeID].balanceFee = poolVariable[_stakeID].balanceFee.add(pendingRewardFee);

                    // Calculated reward after commission deducted
                    finalRewardAmount = pendingAmount.sub(pendingRewardFee);
                }
                //Reward distribution
                getRewardTokenContract(_stakeID, RewardIndex).safeTransfer(_msgSender(), finalRewardAmount);
                
                // Updating balance pending to be distributed from contract to users
                poolRewardVariableInfo[_stakeID][RewardIndex].balance = poolRewardVariableInfo[_stakeID][RewardIndex].balance.sub(pendingAmount);

                // The amount distributed to users is reported
                poolPaidOut[_stakeID][RewardIndex] = poolPaidOut[_stakeID][RewardIndex].add(pendingAmount);    
            }
        }
    }

    /// @notice             Deposits assets by pool id
    /// @param  _stakeID    Id of the stake pool
    /// @param  _amount     Amount of deposit asset
    function stake(uint _stakeID, uint256 _amount) public{
        IERC20 selectedToken = getStakeContract(_stakeID);
        require(selectedToken.allowance(_msgSender(), address(this)) > 0, "Stake: No balance allocated for Allowance!");
        require(_amount > 0 && selectedToken.balanceOf(_msgSender()) >= _amount, "Stake: You cannot stake zero tokens");

        UserDef storage user =  poolUserInfo[_stakeID][_msgSender()];

        // Amount leak control
        if (_amount > selectedToken.balanceOf(_msgSender()))
            _amount = selectedToken.balanceOf(_msgSender());

        // Amount transfer to address(this)
        selectedToken.safeTransferFrom(_msgSender(), address(this), _amount);
        
        UpdatePoolRewardShare(_stakeID);
        if (user.stakingBalance > 0)
            sendPendingReward(_stakeID, user, false);
    
        // "_amount" added to Total staked value by Pool ID
        poolTotalStake[_stakeID] = poolTotalStake[_stakeID].add(_amount); 
        // "_amount" added to USER Total staked value by Pool ID
        user.stakingBalance = user.stakingBalance.add(_amount);
        
        // ..:: Calculating the rewards user pool deserve ::..
        uint rewardCount = poolList[_stakeID].rewardCount;
        for (uint i=0; i<rewardCount; i++) {
            poolUserRewardInfo[_stakeID][_msgSender()][i].rewardBalance = user.stakingBalance.mul(poolRewardVariableInfo[_stakeID][i].accTokenPerShare).div(1e36);
        }
        // ..:: Calculating the rewards user pool deserve ::..
        
        emit Stake(_msgSender(), _amount);
    } 

    /// @notice             Returns staked token balance by pool id
    /// @param  _stakeID    Id of the stake pool
    /// @param  _account    Address of the staker
    /// @return             Count of staked balance 
    function balanceOf(uint _stakeID, address _account) public view returns (uint256) {
        return poolUserInfo[_stakeID][_account].stakingBalance;
    }

    /// @notice             Returns Stake Poll Contract casted IERC20 interface by pool id
    /// @param  _stakeID    Id of the stake pool
    function getStakeContract(uint _stakeID) internal view returns(IERC20){
        require(poolListExtras[_stakeID].name!="", "Stake: Selected contract is not valid");
        require(poolList[_stakeID].active,"Stake: Selected contract is not active");
        return IERC20(poolList[_stakeID].tokenAddress);
    }

    /// @notice             Returns rewarded token address
    /// @param  _stakeID    Id of the stake pool
    /// @param  _rewardID   Id of the reward
    /// @return             token contract 
    function getRewardTokenContract(uint _stakeID, uint _rewardID) internal view returns(IERC20){
        return IERC20(poolRewardList[_stakeID][_rewardID].tokenAddress);
    }

    /// @notice             Checks the address has a stake
    /// @param  _stakeID    Id of the stake pool
    /// @param _user        Address of the staker
    /// @return             Value of stake status
    function isStaking(uint _stakeID, address _user) view public returns(bool){
        return poolUserInfo[_stakeID][_user].stakingBalance > 0;
    }

    /// @notice Returns stake asset list of active
    function getPoolList() public view returns(PoolDef[] memory, PoolDefExt[] memory){
        uint length = stakeIDCounter;

        PoolDef[] memory result = new PoolDef[](length);
        PoolDefExt[] memory resultExt = new PoolDefExt[](length);
        for (uint i=0; i<length; i++) { 
            result[i]                       = poolList[i];
            resultExt[i]                    = poolListExtras[i];
        }
        return (result, resultExt);
    }

    function getPoolRewardList(uint _stakeID) public view returns(RewardDef[] memory){
        uint length = poolList[_stakeID].rewardCount;
        RewardDef[] memory result = new RewardDef[](length);

        for (uint i=0; i<length; i++) { 
            result[i] = poolRewardList[_stakeID][i];
        }

        return result;
    }

    function getPoolReward(uint _stakeID, uint _rewardID) public view returns(RewardDef memory, PoolRewardVariable memory){
        return (poolRewardList[_stakeID][_rewardID],  poolRewardVariableInfo[_stakeID][_rewardID]);
    }

    /// @notice             Returns stake pool
    /// @param  _stakeID    Id of the stake pool
    /// @return             TODO...
    function getStakePoolByID(uint _stakeID) public view returns(PoolDef memory){
        require(poolListExtras[_stakeID].name!="", "Stake: Stake Asset is not valid");
        return poolList[_stakeID];
    }

    /// @notice                 Adds new stake def to the pool
    /// @param  _poolAddress    Address of the token pool
    /// @param  _poolName       Name of the token pool
    /// @param  _rewards        Rewards for the stakers
    function addNewStakePool(address _poolAddress, bytes32 _poolName, RewardDef[] memory _rewards) onlyOwner public returns(uint){
        require(_poolAddress != address(0), "Stake: New Staking Pool address not valid");
        require(_poolName != "", "Stake: New Staking Pool name not valid");
        uint length = _rewards.length;

        for (uint i=0; i<length; i++) {
            _rewards[i].id = i;
            poolRewardList[stakeIDCounter][i] = _rewards[i];
        }

        poolList[stakeIDCounter] = PoolDef(_poolAddress, length, stakeIDCounter, false);
        poolListExtras[stakeIDCounter] = PoolDefExt(block.timestamp, 0, _poolName);
        stakeIDCounter = stakeIDCounter.add(1);

        return stakeIDCounter.sub(1);
    }

    /// @notice Disables stake pool for user 
    /// @param  _stakeID  Id of the stake pool    
    function disableStakePool(uint _stakeID) public onlyOwner{
        require(poolListExtras[_stakeID].name!="", "Stake: Contract is not valid");
        require(poolList[_stakeID].active,"Stake: Contract is already disabled");
        poolList[_stakeID].active = false;
    }

    /// @notice Enables stake pool for user 
    /// @param  _stakeID  Id of the stake pool
    function enableStakePool(uint _stakeID) public onlyOwner{
        require(poolListExtras[_stakeID].name!="", "Stake: Contract is not valid");
        require(poolList[_stakeID].active==false,"Stake: Contract is already enabled");
        poolList[_stakeID].active = true;
    }

    function getPoolCount() public view returns(uint){
        return stakeIDCounter;
    }

    function depositToRewardByPoolID(uint _stakeID, uint _rewardID, uint256 _amount) public onlyOwner returns(bool){
        IERC20 selectedToken = getRewardTokenContract(_stakeID, _rewardID);
        require(selectedToken.allowance(owner(), address(this)) > 0, "Stake: No balance allocated for Allowance!");
        require(_amount > 0, "Stake: You cannot stake zero tokens");
        require(address(this) != address(0), "Stake: Storage address did not set");

        // Amount leak control
        if (_amount > selectedToken.balanceOf(_msgSender()))
            _amount = selectedToken.balanceOf(_msgSender());

        // Amount transfer to address(this)
        selectedToken.safeTransferFrom(_msgSender(), address(this), _amount);
        
        poolRewardVariableInfo[_stakeID][_rewardID].balance = poolRewardVariableInfo[_stakeID][_rewardID].balance.add(_amount); 
        return true;
    }

    function withdrawRewardByPoolID(uint _stakeID, uint _rewardID, uint256 _amount) public onlyOwner returns(bool){
        poolRewardVariableInfo[_stakeID][_rewardID].balance = poolRewardVariableInfo[_stakeID][_rewardID].balance.sub(_amount);

        IERC20 selectedToken = getRewardTokenContract(_stakeID, _rewardID);
        selectedToken.safeTransfer(_msgSender(), _amount);
        return true;
    }
 }