import chai, { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract, BigNumber } from "ethers";
import { time } from "@openzeppelin/test-helpers";

const userAmount = ethers.BigNumber.from("1000000");
const rewardAmount = ethers.BigNumber.from("1000000000");
const tokenNameStake = ethers.utils.formatBytes32String("StakeToken");
const tokenNameApple = ethers.utils.formatBytes32String("AppleTokn");
const tokenNameBanana = ethers.utils.formatBytes32String("BananaToken");
const rewardPersecondStandart = ethers.BigNumber.from("1"); //47500000000000000

type RewardDef = {
    tokenAddress: string;
    rewardPerSecond: BigNumber;
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
    let poolRewardBananaAndApple: any
    let poolDisableAlways: any

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
            let activePoolList: string | any[], activePoolExtList: string | any[] 
            [activePoolList, activePoolExtList] =  await stakeContract.getPoolList();
            expect(activePoolList.length).to.eq(0);
            expect(activePoolExtList.length).to.eq(0);
        });
        it("Should add new stake pool rewardApple", async() => {
            let rewardList: RewardDef[] = [];
            
            rewardList.push({tokenAddress: rewardApple.address,
                            rewardPerSecond: rewardPersecondStandart,
                            name: tokenNameApple,
                            feeRate: 1,
                            id: 0});

            await stakeContract.addNewStakePool(defaultStakeToken.address, tokenNameStake, rewardList);
            
            
            let activePoolList: string | any[], activePoolExtList: any[]; 
            [activePoolList, activePoolExtList] =  await stakeContract.getPoolList();
            poolRewardApple = activePoolList[0];
            const poolDefExt = activePoolExtList[0];

            expect(activePoolList.length).to.eq(1);
            expect(poolDefExt.name).to.eq(tokenNameStake)
            expect(poolRewardApple.active).to.eq(false);
        })
        it('Should get poolRewardApple and reward list', async()=>{
            const pool = await stakeContract.getPoolDefByID(poolRewardApple.id)
            const poolRewardList = await stakeContract.getPoolRewardDefList(pool.id);
            const appleReward = poolRewardList[0];

            expect(poolRewardList.length).to.eq(1);
            expect(appleReward.name).to.eq(tokenNameApple);
            expect(appleReward.tokenAddress).to.eq(rewardApple.address);
        });
        it("Should add new stake pool rewardBanana", async() => {
            let rewardList: RewardDef[] = [];
            
            expect( await stakeContract.getPoolCount()).to.eq(1);

            rewardList.push({tokenAddress: rewardBanana.address,
                            rewardPerSecond: rewardPersecondStandart,
                            name: tokenNameBanana,
                            feeRate: 1,
                            id: 0});

            await stakeContract.addNewStakePool(defaultStakeToken.address, tokenNameStake, rewardList);
            
            expect( await stakeContract.getPoolCount()).to.eq(2);

            let activePoolList: string | any[], activePoolExtList: any[]; 
            [activePoolList, activePoolExtList] =  await stakeContract.getPoolList();
            poolRewardBanana = activePoolList[1];
            const poolDefExt = activePoolExtList[1];

            expect(activePoolList.length).to.eq(2);
            expect(poolDefExt.name).to.eq(tokenNameStake)
            expect(poolRewardBanana.active).to.eq(false);
        });
        it('Should get poolRewardBanana and reward list', async()=>{
            const pool = await stakeContract.getPoolDefByID(poolRewardBanana.id)
            const poolRewardList = await stakeContract.getPoolRewardDefList(pool.id);
            const bananaReward = poolRewardList[0];

            expect(poolRewardList.length).to.eq(1);
            expect(bananaReward.name).to.eq(tokenNameBanana);
            expect(bananaReward.tokenAddress).to.eq(rewardBanana.address); 
        });
        it("Should add new stake pool rewardBananaAndApple", async() => {
            let rewardList: RewardDef[] = [];
            
            expect( await stakeContract.getPoolCount()).to.eq(2);

            rewardList.push({tokenAddress: rewardBanana.address,
                            rewardPerSecond: rewardPersecondStandart,
                            name: tokenNameBanana,
                            feeRate: 1,
                            id: 0});

            rewardList.push({tokenAddress: rewardApple.address,
                            rewardPerSecond: rewardPersecondStandart,
                            name: tokenNameApple,
                            feeRate: 3,
                            id: 0});

            await stakeContract.addNewStakePool(defaultStakeToken.address, tokenNameStake, rewardList);
            
            expect( await stakeContract.getPoolCount()).to.eq(3);

            let activePoolList: any[], activePoolExtList: any[]; 
            [activePoolList, activePoolExtList] =  await stakeContract.getPoolList();
                    
            poolRewardBananaAndApple = activePoolList[2];
            //console.log("poolRewardBananaAndApple: " + poolRewardBananaAndApple);
            
            const poolDefExt = activePoolExtList[2];

            expect(activePoolList.length).to.eq(3);
            expect(poolDefExt.name).to.eq(tokenNameStake)
            expect(poolRewardBananaAndApple.active).to.eq(false);
        });
        it('Should get poolRewardBananaAndApple and reward list', async()=>{
            const pool = await stakeContract.getPoolDefByID(poolRewardBananaAndApple.id)
            const poolRewardList = await stakeContract.getPoolRewardDefList(pool.id);
            const bananaReward = poolRewardList[0];
            const appleReward = poolRewardList[1];

            //console.log(poolRewardList);
            
            expect(poolRewardList.length).to.eq(2);
            expect(bananaReward.name).to.eq(tokenNameBanana);
            expect(appleReward.name).to.eq(tokenNameApple);
            expect(bananaReward.tokenAddress).to.eq(rewardBanana.address); 
            expect(appleReward.tokenAddress).to.eq(rewardApple.address); 
        });
        it('Should owner change pools enable', async()=>{
            let pool = await stakeContract.getPoolDefByID(poolRewardBananaAndApple.id);
            let activeBefore = pool.active;
            await stakeContract.enableStakePool(poolRewardBananaAndApple.id);
            pool = await stakeContract.getPoolDefByID(poolRewardBananaAndApple.id);
            let activeAfter = pool.active;
            
            expect(activeBefore).to.be.false;
            expect(activeAfter).to.be.true;

            pool = await stakeContract.getPoolDefByID(poolRewardApple.id);
            activeBefore = pool.active;
            await stakeContract.enableStakePool(poolRewardApple.id);
            pool = await stakeContract.getPoolDefByID(poolRewardApple.id);
            activeAfter = pool.active;
            
            expect(activeBefore).to.be.false;
            expect(activeAfter).to.be.true;

            pool = await stakeContract.getPoolDefByID(poolRewardBanana.id);
            activeBefore = pool.active;
            await stakeContract.enableStakePool(poolRewardBanana.id);
            pool = await stakeContract.getPoolDefByID(poolRewardBanana.id);
            activeAfter = pool.active;
            
            expect(activeBefore).to.be.false;
            expect(activeAfter).to.be.true;
        });
        it('Should owner change pools disable', async()=>{
            let pool = await stakeContract.getPoolDefByID(poolRewardBananaAndApple.id);
            let activeBefore = pool.active;
            await stakeContract.disableStakePool(poolRewardBananaAndApple.id);
            pool = await stakeContract.getPoolDefByID(poolRewardBananaAndApple.id);
            let activeAfter = pool.active;
            
            expect(activeBefore).to.be.true;
            expect(activeAfter).to.be.false;

            pool = await stakeContract.getPoolDefByID(poolRewardApple.id);
            activeBefore = pool.active;
            await stakeContract.disableStakePool(poolRewardApple.id);
            pool = await stakeContract.getPoolDefByID(poolRewardApple.id);
            activeAfter = pool.active;
            
            expect(activeBefore).to.be.true;
            expect(activeAfter).to.be.false;

            pool = await stakeContract.getPoolDefByID(poolRewardBanana.id);
            activeBefore = pool.active;
            await stakeContract.disableStakePool(poolRewardBanana.id);
            pool = await stakeContract.getPoolDefByID(poolRewardBanana.id);
            activeAfter = pool.active;
            
            expect(activeBefore).to.be.true;
            expect(activeAfter).to.be.false;

        });
        it("Should add new stake pool disabled always", async() => {
            let rewardList: RewardDef[] = [];
            
            rewardList.push({tokenAddress: rewardApple.address,
                            rewardPerSecond: rewardPersecondStandart,
                            name: tokenNameApple,
                            feeRate: 100,
                            id: 0});

            await stakeContract.addNewStakePool(defaultStakeToken.address, tokenNameStake, rewardList);
            
            
            let activePoolList: string | any[], activePoolExtList: any[]; 
            [activePoolList, activePoolExtList] =  await stakeContract.getPoolList();
            
            poolDisableAlways = activePoolList[3];
            const poolDefExt = activePoolExtList[3];

            expect(activePoolList.length).to.eq(4);
            expect(poolDefExt.name).to.eq(tokenNameStake)
            expect(poolDisableAlways.active).to.eq(false);
        });
        it('Should active all pool again',async()=>{
            let pool = await stakeContract.getPoolDefByID(poolRewardBananaAndApple.id);
            let activeBefore = pool.active;
            await stakeContract.enableStakePool(poolRewardBananaAndApple.id);
            pool = await stakeContract.getPoolDefByID(poolRewardBananaAndApple.id);
            let activeAfter = pool.active;
            
            expect(activeBefore).to.be.false;
            expect(activeAfter).to.be.true;

            pool = await stakeContract.getPoolDefByID(poolRewardApple.id);
            activeBefore = pool.active;
            await stakeContract.enableStakePool(poolRewardApple.id);
            pool = await stakeContract.getPoolDefByID(poolRewardApple.id);
            activeAfter = pool.active;
            
            expect(activeBefore).to.be.false;
            expect(activeAfter).to.be.true;

            pool = await stakeContract.getPoolDefByID(poolRewardBanana.id);
            activeBefore = pool.active;
            await stakeContract.enableStakePool(poolRewardBanana.id);
            pool = await stakeContract.getPoolDefByID(poolRewardBanana.id);
            activeAfter = pool.active;
            
            expect(activeBefore).to.be.false;
            expect(activeAfter).to.be.true;
        });
    });

    describe('Staking', () => {
        it('Should OWNER deposite reward tokens',async()=>{
            await rewardBanana.connect(owner).approve(stakeContract.address, rewardAmount);
            
            const pool = await stakeContract.getPoolDefByID(poolRewardBanana.id)
            let [rewardDef, rewardVariable] = await stakeContract.getPoolRewardDef(pool.id, 0);
            const beforeRewardBalance = rewardVariable.balance

            await stakeContract.depositToRewardByPoolID(pool.id, 0, rewardAmount);
            
            [rewardDef, rewardVariable] = await stakeContract.getPoolRewardDef(pool.id, 0);
            const afterRewardBalance = rewardVariable.balance;
            
            expect(beforeRewardBalance).to.not.eq(afterRewardBalance);
            expect(afterRewardBalance).to.eq(rewardAmount);
        });
        it('Should OWNER withdraw reward tokens',async()=>{
            const withdrawAmount = ethers.BigNumber.from("1000");

            const pool = await stakeContract.getPoolDefByID(poolRewardBanana.id)
            let [rewardDef, rewardVariable] = await stakeContract.getPoolRewardDef(pool.id, 0);
            const beforeRewardBalance = rewardVariable.balance

            await stakeContract.withdrawRewardByPoolID(pool.id, 0, withdrawAmount);
            
            [rewardDef, rewardVariable] = await stakeContract.getPoolRewardDef(pool.id, 0);
            const afterRewardBalance = rewardVariable.balance;
            
            expect(beforeRewardBalance).to.not.eq(afterRewardBalance);
            expect(afterRewardBalance).to.eq(beforeRewardBalance.sub(withdrawAmount));
        });
        it('Should OWNER deposite multi reward tokens',async()=>{
            const pool = await stakeContract.getPoolDefByID(poolRewardBananaAndApple.id)

            await expect(stakeContract.depositToRewardByPoolID(pool.id, 0, rewardAmount))
                .to.be
                .revertedWith('Stake: No balance allocated for Allowance!');

            await rewardBanana.connect(owner).approve(stakeContract.address, rewardAmount);
            await rewardApple.connect(owner).approve(stakeContract.address, rewardAmount);
            
            const poolRewardList = await stakeContract.getPoolRewardDefList(pool.id);
        
            for (let item of poolRewardList) {
                
                let rewardDef: any, rewardVariable: any; ;
                
                [rewardDef, rewardVariable] = await stakeContract.getPoolRewardDef(pool.id, item.id);
                const beforeRewardBalance = rewardVariable.balance

                await stakeContract.depositToRewardByPoolID(pool.id, item.id, rewardAmount);
                
                [rewardDef, rewardVariable] = await stakeContract.getPoolRewardDef(pool.id, item.id);
                const afterRewardBalance = rewardVariable.balance;

                expect(beforeRewardBalance).to.not.eq(afterRewardBalance, "Failed reward ID:" + item.id);
                expect(afterRewardBalance).to.eq(rewardAmount, "Failed reward ID:" + item.id);
            }
        });
        it('Should fail for disable pool',async()=>{
            const toStake = ethers.BigNumber.from("1000000000000000");

            const pool = await stakeContract.getPoolDefByID(poolDisableAlways.id)

            await expect(stakeContract.stake(pool.id, toStake))
                .to.be
                .revertedWith('Stake: Selected contract is not active');
        });
        it('Should user1 stake token multi reward',async()=>{
            const toStake = userAmount.mul(10).div(100);
            
            const pool = await stakeContract.getPoolDefByID(poolRewardBananaAndApple.id)

            await expect(stakeContract.stake(pool.id, toStake))
                .to.be
                .revertedWith('Stake: No balance allocated for Allowance!');

            await defaultStakeToken.connect(user1).approve(stakeContract.address, toStake);
            await stakeContract.connect(user1).stake(pool.id, toStake);
            
            const userStakeBalance = await stakeContract.balanceOf(pool.id, user1.address);

            expect(userStakeBalance).to.eq(toStake);    
        });
        it('Should user2 stake token single reward',async()=>{
            const toStake = userAmount.mul(10).div(100);
            
            const pool = await stakeContract.getPoolDefByID(poolRewardBanana.id)

            await expect(stakeContract.stake(pool.id, toStake))
                .to.be
                .revertedWith('Stake: No balance allocated for Allowance!');

            await defaultStakeToken.connect(user2).approve(stakeContract.address, toStake);
            await stakeContract.connect(user2).stake(pool.id, toStake);
            
            const userStakeBalance = await stakeContract.balanceOf(pool.id, user2.address);

            expect(userStakeBalance).to.eq(toStake);    
        });
    });

    describe('UnStaking', ()=>{
        it('Should show pending reward',async()=>{
            // Fast-forward time
            await time.increase(1000)
            
            let pendinRewardAmount = await stakeContract.connect(user2).showPendingReward(poolRewardBanana.id);
            
            expect(pendinRewardAmount).to.be.an('array');

            for (let item of pendinRewardAmount) {    
                expect(Number(item.amount)).to.greaterThan(0,"Pending single reward calculation error")
            }            
            
            pendinRewardAmount = await stakeContract.connect(user1).showPendingReward(poolRewardBananaAndApple.id);
            
            expect(pendinRewardAmount).to.be.an('array');

            for (let item of pendinRewardAmount) {
                expect(Number(item.amount)).to.greaterThan(0,"Pending multi reward calculation error")
            }   
        });
        
        it('Should unstake balance from user single reward without TimeDiff',async()=>{
            const beforeStakedBalance = await stakeContract.balanceOf(poolRewardBanana.id, user2.address);
            
            await stakeContract.connect(user2).unStake(poolRewardBanana.id, beforeStakedBalance);

            const afterStakedBalance = await stakeContract.balanceOf(poolRewardBanana.id, user2.address);
            
            expect(afterStakedBalance).to.eq(0);
            
        });
        
        it('Should stake and unstake balance from user single reward',async()=>{
            let beforeStakedBalance = await stakeContract.balanceOf(poolRewardBanana.id, user2.address);
            
            expect(beforeStakedBalance).to.eq(0);

            const toStake = 100;
            const beforeUserStakeTokenBalance = await defaultStakeToken.balanceOf(user2.address);
            const beforeBananaTokenBalance = await rewardBanana.balanceOf(user2.address);

            await defaultStakeToken.connect(user2).approve(stakeContract.address, toStake);
            await stakeContract.connect(user2).stake(poolRewardBanana.id, toStake);
            
            const afterUserStakeTokenBalance = await defaultStakeToken.balanceOf(user2.address);
            
            expect(afterUserStakeTokenBalance).to.eq(beforeUserStakeTokenBalance.sub(toStake));
            let timeStr = await stakeContract.getTime()
            
            // Fast-forward time
            await time.increase(60 * 60)
            timeStr = await stakeContract.getTime()

            let userPendingReward = await stakeContract.showPendingReward(poolRewardBanana.id);
            let pendingBananaRewardAmount;
            for (let item of userPendingReward) {
                pendingBananaRewardAmount = item.amount;
            }

            await stakeContract.connect(user2).unStake(poolRewardBanana.id, toStake);
            
            const afterUnStakeUserStakeTokenBalance = await defaultStakeToken.balanceOf(user2.address);
            const afterUnStakeBananaTokenBalance = await rewardBanana.balanceOf(user2.address);

            expect(pendingBananaRewardAmount).to.eq(afterUnStakeBananaTokenBalance.sub(beforeBananaTokenBalance));
            expect(afterUnStakeUserStakeTokenBalance).to.eq(beforeUserStakeTokenBalance);
        });
    });
});