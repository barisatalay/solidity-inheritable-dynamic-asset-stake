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
    event Unstake(address indexed from, uint256 amount);
    event YieldWithdraw(address indexed to);
    
    address private storageAddress = address(this);
    
    struct RewardDef{
        address tokenAddress;               // Contract Address of Reward token
        uint256 rewardPerSecond;            // TODO
        uint256 accTokenPerShare;           // TODO
        bytes32 name;                       // Byte equivalent of the name of the pool token
        uint id;                            // Id of Reward
    }

    struct RewardInfo{
        uint256 rewardBalance;
        uint rewardID;
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
        uint256 balance;                    // Pool Contract Token Balance
        uint256 balanceFee;                 // Withdraw Fee for contract Owner;
        uint256 lastRewardTimeStamp;        // TODO
        uint8 feeRate;                      // Fee Rate for UnStake
    }
    
    // Info of each user
    struct UserDef{ 
        address id;                         // Wallet Address of staker
        uint256 stakingBalance;             // Amount of current staking balance
        uint256 startTime;                  // Staking start time
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
    //Pool ID => (RewardIndex => Amount of distributed reward to staker) 
    mapping(uint => mapping(uint => uint)) public poolPaidOut;
    //Pool ID => Amount of Stake from User
    mapping(uint => uint) public poolTotalStake;


    //Pool ID => (User ID => User Info)
    mapping(uint => mapping(address => UserDef)) poolUserInfo;
    //Pool ID => (User ID => (Reward Id => Reward Info))
    mapping (uint => mapping(address => mapping(uint => RewardInfo))) poolRewardInfo;

    
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    constructor(){
        stakeIDCounter = 0;
    }

    function RewardUpdate(uint _stakeID) internal virtual {
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
            RewardDef storage rewardDef = poolRewardList[_stakeID][i];
            uint256 currentReward = timeDiff.mul(rewardDef.rewardPerSecond);
            rewardDef.accTokenPerShare = rewardDef.accTokenPerShare.add(currentReward.mul(1e36).div(poolTotalStake[_stakeID]));
        }
        //..:: Calculating the reward shares of the pool ::..
        
        selectedPoolVariable.lastRewardTimeStamp = block.timestamp;
    }

    function showPendingReward() external virtual returns(uint){}

    /// @notice             Withdraw assets by pool id
    /// @param  _stakeID    Id of the stake pool
    /// @param  _amount     Amount of withdraw asset
    function unStake(uint _stakeID, uint256 _amount) public {
        require(_msgSender() != address(0), "Stake: Staker address not specified!");
        IERC20 selectedToken = getStakeContract(_stakeID);
        UserDef storage user =  poolUserInfo[_stakeID][_msgSender()];

        require(user.stakingBalance > 0, "Stake: does not have staking balance");

        if (_amount > user.stakingBalance)
            _amount = user.stakingBalance;

        user.startTime = block.timestamp;
        
        //TODO Reward Calculation
        

        user.stakingBalance = user.stakingBalance.sub(_amount);

        if (_amount > 0)
            selectedToken.safeTransferFrom(storageAddress, _msgSender(), _amount);
        emit Unstake(_msgSender(), _amount);
    }

    /// @notice             Deposits assets by pool id
    /// @param  _stakeID    Id of the stake pool
    /// @param  _amount     Amount of deposit asset
    function stake(uint _stakeID, uint256 _amount) public{
        IERC20 selectedToken = getStakeContract(_stakeID);
        require(_amount > 0 && selectedToken.balanceOf(_msgSender()) >= _amount, "Stake: You cannot stake zero tokens");
        require(storageAddress != address(0), "Stake: Storage address did not set");

        UserDef storage user =  poolUserInfo[_stakeID][_msgSender()];

        if (_amount > selectedToken.balanceOf(_msgSender()))
            _amount = selectedToken.balanceOf(_msgSender());

        // Amount transfer to storageAddress
        selectedToken.safeTransferFrom(_msgSender(), storageAddress, _amount);
        
        RewardUpdate(_stakeID);
        // ..:: Pending reward will be calculate and send to staker, before new stake amount ::..
        if (user.stakingBalance > 0){
            uint rewardCount = poolList[_stakeID].rewardCount;
            for (uint i=0; i<rewardCount; i++) {
                uint256 userRewardedBalance = poolRewardInfo[_stakeID][_msgSender()][i].rewardBalance;

                uint pendingAmount = user.stakingBalance.mul(accRocoPerShare).div(1e36).sub(userRewardedInfo.userRewardedBalance);    
                

                PoolVariable storage poolVariableInfo = poolVariable[_stakeID];
                poolVariableInfo.balance = poolVariableInfo.sub(pendingAmount);

                getRewardTokenAddress(_stakeID, i).safeTransfer(_msgSender(), pendingAmount);
                poolPaidOut[_stakeID][i] = poolPaidOut[_stakeID][i].add(pendingAmount); 
            }
        }
        // ..:: Pending reward will be calculate and send to staker, before new stake amount ::..
        

        // Total staked value updated with "_amount" by Pool ID
        poolTotalStake[_stakeID] = poolTotalStake[_stakeID].add(_amount); 
        // User's staked value updated with "_amount" by Pool ID
        user.stakingBalance = user.stakingBalance.add(_amount);
        
        // ..:: Calculating the rewards users deserve ::..
        uint rewardCount = poolList[_stakeID].rewardCount;
        for (uint i=0; i<rewardCount; i++) {
            poolRewardInfo[_stakeID][_msgSender()][i].rewardBalance = user.stakingBalance.mul(poolRewardList[_stakeID][i].accTokenPerShare).div(1e36);
        }
        // ..:: Calculating the rewards users deserve ::..
        
        emit Stake(_msgSender(), _amount);
    } 

    function

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
    /// @return             Address of token contract 
    function getRewardTokenAddress(uint _stakeID, uint _rewardID) internal view returns(address){
        return poolRewardList[_stakeID][i].tokenAddress;
    }

    /// @notice             Checks the address has a stake
    /// @param  _stakeID    Id of the stake pool
    /// @param _user        Address of the staker
    /// @return             Value of stake status
    function isStaking(uint _stakeID, address _user) view public returns(bool){
        return poolUserInfo[_stakeID][_user].stakingBalance > 0;
    }

    /// @notice Returns stake asset list of active
    function getActiveStakeAssetList() public view returns(PoolDef[] memory){
        uint length = stakeIDCounter;

        PoolDef[] memory result = new PoolDef[](length);
        for (uint i=0; i<length; i++) {
            if (poolList[i].active==true) 
                result[i] = poolList[i];
        }
        return result;
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
        stakeIDCounter += 1;

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
 }