import chai, { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract, BigNumber } from "ethers";

const userAmount = ethers.BigNumber.from("1000000");
const rewardAmount = ethers.BigNumber.from("1000000000");
const tokenNameStake = ethers.utils.formatBytes32String("StakeToken");
const tokenNameApple = ethers.utils.formatBytes32String("AppleTokn");
const tokenNameBanana = ethers.utils.formatBytes32String("BananaToken");

type RewardDef = {
    tokenAddress: string;
    rewardPerSecond: BigNumber;
    accTokenPerShare: BigNumber;
    name: string;
    feeRate: number;
    id: number;
};

describe('DynamicAssetStake', ()=>{
    let stakeContract: Contract;
    let defaultStakeToken: Contract;
    let rewardApple: Contract;
    let rewardBanana: Contract;
    
    let owner: SignerWithAddress;
    let user1: SignerWithAddress;
    let user2: SignerWithAddress;

    let poolRewardApple: any
    let poolRewardBanana: any

    before(async function () {
        let Token1 = await ethers.getContractFactory('StakeToken');
        let Token2 = await ethers.getContractFactory('AppleToken');
        let Token3 = await ethers.getContractFactory('BananaToken');
        let Contract = await ethers.getContractFactory('DynamicAssetStake');
        
        [owner, user1, user2] = await ethers.getSigners();

        stakeContract = await Contract.deploy();
        defaultStakeToken = await Token1.deploy();
        rewardApple = await Token2.deploy();
        rewardBanana = await Token3.deploy();
        
        await Promise.all([
            defaultStakeToken.connect(owner).transfer(user1.address, userAmount),
            defaultStakeToken.connect(owner).transfer(user2.address, userAmount),
        ]);
    });

    describe('Deployment', () => {
        it("should deploy contracts", async() => {
            expect(stakeContract).to.be.ok
            expect(defaultStakeToken).to.be.ok
            expect(rewardApple).to.be.ok
            expect(rewardBanana).to.be.ok
        })

        it('Should set the right owner', async () => {
            expect(await stakeContract.owner()).to.equal(owner.address);
        });
    });

    describe('Initiation', () => {
        it('Should stake pool must empty', async()=>{
            let activePoolList, activePoolExtList 
            [activePoolList, activePoolExtList] =  await stakeContract.getPoolList();
            expect(activePoolList.length).to.eq(0);
            expect(activePoolExtList.length).to.eq(0);
        });
        it("Should add new stake pool rewardApple", async() => {
            let rewardList: RewardDef[] = [];
            
            rewardList.push({tokenAddress: rewardApple.address,
                            rewardPerSecond: ethers.BigNumber.from("47500000000000000"),
                            accTokenPerShare: ethers.BigNumber.from("0"),
                            name: tokenNameApple,
                            feeRate: 1,
                            id: 0});

            await stakeContract.addNewStakePool(defaultStakeToken.address, tokenNameStake, rewardList);
            
            
            let activePoolList, activePoolExtList; 
            [activePoolList, activePoolExtList] =  await stakeContract.getPoolList();
            poolRewardApple = activePoolList[0];
            const poolDefExt = activePoolExtList[0];

            expect(activePoolList.length).to.eq(1);
            expect(poolDefExt.name).to.eq(tokenNameStake)
            expect(poolRewardApple.active).to.eq(false);
        })

        it('Should get poolRewardApple and reward list', async()=>{
            const pool = await stakeContract.getStakePoolByID(poolRewardApple.id)
            const poolRewardList = await stakeContract.getPoolRewardList(pool.id);
            const appleReward = poolRewardList[0];

            expect(poolRewardList.length).to.eq(1);
            expect(appleReward.name).to.eq(tokenNameApple);
            expect(appleReward.tokenAddress).to.eq(rewardApple.address);
        });

        it("Should add new stake pool rewardBanana", async() => {
            let rewardList: RewardDef[] = [];
            
            expect( await stakeContract.getPoolCount()).to.eq(1);

            rewardList.push({tokenAddress: rewardBanana.address,
                            rewardPerSecond: ethers.BigNumber.from("47500000000000000"),
                            accTokenPerShare: ethers.BigNumber.from("0"),
                            name: tokenNameBanana,
                            feeRate: 1,
                            id: 0});

            await stakeContract.addNewStakePool(defaultStakeToken.address, tokenNameStake, rewardList);
            
            expect( await stakeContract.getPoolCount()).to.eq(2);

            let activePoolList, activePoolExtList; 
            [activePoolList, activePoolExtList] =  await stakeContract.getPoolList();
            poolRewardBanana = activePoolList[1];
            const poolDefExt = activePoolExtList[1];

            expect(activePoolList.length).to.eq(2);
            expect(poolDefExt.name).to.eq(tokenNameStake)
            expect(poolRewardBanana.active).to.eq(false);
        })

        it('Should get poolRewardBanana and reward list', async()=>{
            const pool = await stakeContract.getStakePoolByID(poolRewardBanana.id)
            const poolRewardList = await stakeContract.getPoolRewardList(pool.id);
            const bananaReward = poolRewardList[0];

            expect(poolRewardList.length).to.eq(1);
            expect(bananaReward.name).to.eq(tokenNameBanana);
            expect(bananaReward.tokenAddress).to.eq(rewardBanana.address); 
        });
    });
});