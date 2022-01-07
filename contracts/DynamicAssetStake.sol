// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/*
 * @title BARIS ATALAY
 * @dev Set & change owner
 */
 contract FeedTheMonsterStake is Context, Ownable{
    event Stake(address indexed from, uint256 amount);
    event Unstake(address indexed from, uint256 amount);
    event YieldWithdraw(address indexed to, uint256 amount);
    
    address private storageAddress = address(this);
    

    struct RewardInfo{
        address tokenAddress;
        uint256 rate;
        uint id;
        bool isSupportMint;
    }

    struct AssetInfo {
        uint256 createTime;
        uint256 expiryTime;
        address tokenAddress;
        bytes32 name;
        uint rewardCount;
        uint id;
        bool active;
    }

    uint private stakeIDCounter;
    //Index => AssetInfo 
    mapping(uint => AssetInfo) public assetInfo;
    //AssetInfoIndex => (RewardIndex => RewardInfo) 
    mapping(uint => mapping(uint=>RewardInfo)) public rewardInfo;
    // userAddress => stakingBalance
    mapping(uint => mapping(address => uint256)) private stakingBalance;
    // userAddress => timeStamp
    mapping(uint => mapping(address => uint256)) private startTime;
    // userAddress => rewardBalance
    mapping(uint => mapping(address => uint256)) private rewardBalance;
    // userAddress => isStaking boolean
    mapping(uint => mapping(address => bool)) private stakingInfo;
    
    using SafeMath for uint;

    constructor(){
        stakeIDCounter = 0;
    }

    /// @notice             Returns staked token balance by pool id
    /// @param  _stakeID    Id of the stake pool
    /// @param  _account    Address of the staker
    /// @return             Count of staked balance 
    function balanceOf(uint _stakeID, address _account) public view returns (uint256) {
        return stakingBalance[_stakeID][_account];
    }

    /// @notice             Returns Stake Asset Contract casted IERC20 interface by pool id
    /// @param  _stakeID    Id of the stake pool
    function getStakeContract(uint _stakeID) internal view returns(IERC20){
        require(assetInfo[_stakeID].name!="", "Stake: Selected contract is not valid");
        require(assetInfo[_stakeID].active,"Stake: Selected contract is not active");
        return IERC20(assetInfo[_stakeID].tokenAddress);
    }

    /// @notice             Calculates yield time by pool id and staker address 
    /// @param  _stakeID    Id of the stake pool
    /// @param  _user       Address of the staker
    function calculateYieldTime(uint _stakeID, address _user) public view returns(uint256){
        return block.timestamp.sub(startTime[_stakeID][_user], "Stake: Yield Calculation error");
    }
    
    /// @notice             Calculates total yield by pool id and staker address
    /// @param  _stakeID    Id of the stake pool
    /// @param  _user       Address of the staker
    function calculateYieldTotal(uint _stakeID, address _user) public view returns(uint256) {
        //TODO Bu hesaplama üzerinde çalışılacak.
        uint256 rate = 86400;
        uint256 timeRate = calculateYieldTime(_stakeID, _user).mul(10**18).div(rate, "Stake: Yield Calculation error");
        return stakingBalance[_stakeID][_user].mul(timeRate).div(10**18, "Stake: Yield Calculation error");
    } 

    /// @notice             Deposits assets by pool id
    /// @param  _stakeID    Id of the stake pool
    /// @param  _amount     Amount of deposit asset
    function stake(uint _stakeID, uint256 _amount) public{
        IERC20 selectedToken = getStakeContract(_stakeID);
        require(_amount > 0 && selectedToken.balanceOf(_msgSender()) >= _amount, "Stake: You cannot stake zero tokens");
        require(storageAddress != address(0), "Stake: Storage address did not set");

        if(stakingInfo[_stakeID][_msgSender()] == true)
            rewardBalance[_stakeID][_msgSender()]  += calculateYieldTotal(_stakeID, _msgSender());
        else 
            stakingInfo[_stakeID][_msgSender()] = true;
        
        startTime[_stakeID][_msgSender()] = block.timestamp;
        stakingBalance[_stakeID][_msgSender()] += _amount;

        //TODO Transfer edilen adresdeki tokenleri harcayabiliyor muyum bu test edilecek.
        selectedToken.transferFrom(_msgSender(), storageAddress, _amount);
        emit Stake(_msgSender(), _amount);
    } 

    /// @notice             Withdraw assets by pool id
    /// @param  _stakeID    Id of the stake pool
    /// @param  _amount     Amount of withdraw asset
    function unstake(uint _stakeID, uint256 _amount) public {
        IERC20 selectedToken = getStakeContract(_stakeID);
        require(
            stakingInfo[_stakeID][_msgSender()] == true && 
            stakingBalance[_stakeID][_msgSender()] >= _amount, 
            "Stake: does not have staking balance"
        );
        
        startTime[_stakeID][_msgSender()] = block.timestamp;
        rewardBalance[_stakeID][_msgSender()] += calculateYieldTotal(_stakeID, _msgSender());
        stakingBalance[_stakeID][_msgSender()] -= _amount;
        selectedToken.transfer(_msgSender(), _amount);
        if(stakingBalance[_stakeID][_msgSender()] == 0){
            stakingInfo[_stakeID][_msgSender()] = false;
        }        
        emit Unstake(_msgSender(), _amount);
    }

    /// @notice             Withdrawals calculated yield by pool id
    /// @param  _stakeID    Id of the stake pool 
    function withdrawYield(uint _stakeID) public {
        require(assetInfo[_stakeID].name!="", "Stake: Selected contract is not valid");
        require(assetInfo[_stakeID].active,"Stake: Selected contract is not active");
        
        uint256 toTransfer = calculateYieldTotal(_stakeID, _msgSender());
        require(
            toTransfer > 0 ||
            rewardBalance[_stakeID][_msgSender()] > 0,
            "Stake: Nothing to withdraw"
            );
            
        if(rewardBalance[_stakeID][_msgSender()] != 0){
            toTransfer += rewardBalance[_stakeID][_msgSender()];
            rewardBalance[_stakeID][_msgSender()] = 0;
        }

        startTime[_stakeID][_msgSender()] = block.timestamp;
        
        uint length = assetInfo[_stakeID].rewardCount;
        for (uint i=0; i<length; i++) {
            if (rewardInfo[_stakeID][i].isSupportMint){
                //assetInfo[_stakeID].rewards[i].mint(_msgSender(), toTransfer);
            } else{
                IERC20(rewardInfo[_stakeID][i].tokenAddress).transferFrom(storageAddress, _msgSender(), toTransfer);
            }
        }
        emit YieldWithdraw(_msgSender(), toTransfer);
    } 
 
    /// @notice             Checks the address has a stake
    /// @param  _stakeID    Id of the stake pool
    /// @param _user        Address of the staker
    /// todo             Value of stake status
    function isStaking(uint _stakeID, address _user) view public returns(bool){
        return stakingInfo[_stakeID][_user];
    }

    /// @notice Returns stake asset list of active
    function getActiveStakeAssetList() public view returns(AssetInfo[] memory){
        uint length = stakeIDCounter;
        AssetInfo[] memory result = new AssetInfo[](length);
        for (uint i=0; i<length; i++) {
            if (assetInfo[i].active==true) {
                result[i] = assetInfo[i];
            }
        }
        return result;
    }

    /// @notice         Returns stake pool
    /// @return count   Count of stake pool
    function getStakeAssetByID(uint _stakeID) public view returns(AssetInfo memory){
        require(assetInfo[_stakeID].name!="", "Stake: Stake Asset is not valid");
        return assetInfo[_stakeID];
    }

    //  TODO            will be removed if not required
    /// @notice         Returns stake pool
    /// @return count   Count of stake pool
    function stakeItemCount() public view returns(uint){
        return stakeIDCounter;
    }
    
    /// @notice                 Adds new stake asset to the pool
    /// @param  _assetAddress   Address of the token asset
    /// @param  _assetName      Name of the token asset
    /// @param  _rewards        Rewards for the stakers
    function addNewStakeAsset(address _assetAddress, bytes32 _assetName, RewardInfo[] memory _rewards) onlyOwner public {
        require(_assetAddress != address(0), "Stake: New Staking address not valid");
        require(_assetName != "", "Stake: New Staking name not valid");
        uint length = _rewards.length;
        for (uint i=0; i<length; i++) {
            _rewards[i].id = i;
            rewardInfo[stakeIDCounter][i] = _rewards[i];
        }
        assetInfo[stakeIDCounter] = AssetInfo(block.timestamp, 0, _assetAddress, _assetName, length, stakeIDCounter, true);
        
        stakeIDCounter += 1;
    }
    
    /// @notice Disables stake asset for user 
    /// @param  _stakeID  Id of the stake pool    
    function disableStakeAsset(uint _stakeID) public onlyOwner{
        require(assetInfo[_stakeID].name!="", "Stake: Contract is not valid");
        require(assetInfo[_stakeID].active,"Stake: Contract is already disabled");
        assetInfo[_stakeID].active = false;
    }

    /// @notice Enables stake asset for user 
    /// @param  _stakeID  Id of the stake pool
    function enableStakeAsset(uint _stakeID) public onlyOwner{
        require(assetInfo[_stakeID].name!="", "Stake: Contract is not valid");
        require(assetInfo[_stakeID].active==false,"Stake: Contract is already enabled");
        assetInfo[_stakeID].active = true;
    }
 }