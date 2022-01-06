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

    function balanceOf(uint stakeID, address account) public view returns (uint256) {
        return stakingBalance[stakeID][account];
    }

    function getStakeContract(uint stakeID) internal view returns(IERC20){
        require(assetInfo[stakeID].name!="", "Stake: Selected contract is not valid");
        require(assetInfo[stakeID].active,"Stake: Selected contract is not active");
        return IERC20(assetInfo[stakeID].tokenAddress);
    }

    function calculateYieldTime(uint stakeID, address user) public view returns(uint256){
        return block.timestamp.sub(startTime[stakeID][user], "Stake: Yield Calculation error");
    }
    
    function calculateYieldTotal(uint stakeID, address user) public view returns(uint256) {
        //TODO Bu hesaplama üzerinde çalışılacak.
        uint256 rate = 86400;
        uint256 timeRate = calculateYieldTime(stakeID, user).mul(10**18).div(rate, "Stake: Yield Calculation error");
        return stakingBalance[stakeID][user].mul(timeRate).div(10**18, "Stake: Yield Calculation error");
    } 

    function stake(uint stakeID, uint256 _amount) public{
        IERC20 selectedToken = getStakeContract(stakeID);
        require(_amount > 0 && selectedToken.balanceOf(_msgSender()) >= _amount, "Stake: You cannot stake zero tokens");
        require(storageAddress != address(0), "Stake: Storage address did not set");

        if(stakingInfo[stakeID][_msgSender()] == true)
            rewardBalance[stakeID][_msgSender()]  += calculateYieldTotal(stakeID, _msgSender());
        else 
            stakingInfo[stakeID][_msgSender()] = true;
        
        startTime[stakeID][_msgSender()] = block.timestamp;
        stakingBalance[stakeID][_msgSender()] += _amount;

        //TODO Transfer edilen adresdeki tokenleri harcayabiliyor muyum bu test edilecek.
        selectedToken.transferFrom(_msgSender(), storageAddress, _amount);
        emit Stake(_msgSender(), _amount);
    } 

    function unstake(uint stakeID, uint256 _amount) public {
        IERC20 selectedToken = getStakeContract(stakeID);
        require(
            stakingInfo[stakeID][_msgSender()] == true && 
            stakingBalance[stakeID][_msgSender()] >= _amount, 
            "Stake: does not have staking balance"
        );
        
        startTime[stakeID][_msgSender()] = block.timestamp;
        rewardBalance[stakeID][_msgSender()] += calculateYieldTotal(stakeID, _msgSender());
        stakingBalance[stakeID][_msgSender()] -= _amount;
        selectedToken.transfer(_msgSender(), _amount);
        if(stakingBalance[stakeID][_msgSender()] == 0){
            stakingInfo[stakeID][_msgSender()] = false;
        }        
        emit Unstake(_msgSender(), _amount);
    }

    function withdrawYield(uint stakeID) public {
        require(assetInfo[stakeID].name!="", "Stake: Selected contract is not valid");
        require(assetInfo[stakeID].active,"Stake: Selected contract is not active");
        
        uint256 toTransfer = calculateYieldTotal(stakeID, _msgSender());
        require(
            toTransfer > 0 ||
            rewardBalance[stakeID][_msgSender()] > 0,
            "Stake: Nothing to withdraw"
            );
            
        if(rewardBalance[stakeID][_msgSender()] != 0){
            toTransfer += rewardBalance[stakeID][_msgSender()];
            rewardBalance[stakeID][_msgSender()] = 0;
        }

        startTime[stakeID][_msgSender()] = block.timestamp;
        
        uint length = assetInfo[stakeID].rewardCount;
        for (uint i=0; i<length; i++) {
            if (rewardInfo[stakeID][i].isSupportMint){
                //assetInfo[stakeID].rewards[i].mint(_msgSender(), toTransfer);
            } else{
                IERC20(rewardInfo[stakeID][i].tokenAddress).transferFrom(storageAddress, _msgSender(), toTransfer);
            }
        }
        emit YieldWithdraw(_msgSender(), toTransfer);
    } 
 
    function isStaking(uint stakeID, address _user) view public returns(bool){
        return stakingInfo[stakeID][_user];
    }

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

    function getStakeAssetByID(uint _stakeID) public view returns(AssetInfo memory){
        require(assetInfo[_stakeID].name!="", "Stake: Stake Asset is not valid");
        return assetInfo[_stakeID];
    }

    function stakeItemCount() public view returns(uint){
        return stakeIDCounter;
    }
    
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
    
    function disableStakeAsset(uint stakeID) public onlyOwner{
        require(assetInfo[stakeID].name!="", "Stake: Contract is not valid");
        require(assetInfo[stakeID].active,"Stake: Contract is already disabled");
        assetInfo[stakeID].active = false;
    }

    function enableStakeAsset(uint stakeID) public onlyOwner{
        require(assetInfo[stakeID].name!="", "Stake: Contract is not valid");
        require(assetInfo[stakeID].active==false,"Stake: Contract is already enabled");
        assetInfo[stakeID].active = true;
    }
 }