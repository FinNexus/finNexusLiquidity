const Tokenliquidity = artifacts.require("TokenLiquidity");
const FNXCoin = artifacts.require("FNXCoin");
const UniCoin = artifacts.require("UniCoin");
contract('TokenLiquidity', function (accounts){
    it('TokenLiquidity expiration', async function (){
        let liquidity = await Tokenliquidity.deployed();
        let fnx = await FNXCoin.deployed();
        let expiration = Math.floor(Date.now()/1000) + 60;
        await liquidity.setExpiration(expiration);
        await fnx.approve(liquidity.address,1000000000000000);
        await liquidity.stake(1000000000000000,[]);
        let reward = await liquidity.totalRewards(accounts[0]);
        console.log("reward : ",reward.toString(10));
        for (var i=0;i<300;i++){
            await liquidity.setExpiration(expiration);
        }
        reward = await liquidity.totalRewards(accounts[0]);
        console.log("reward : ",reward.toString(10));
        for (var i=0;i<300;i++){
            await liquidity.setExpiration(expiration);
        }
        reward = await liquidity.totalRewards(accounts[0]);
        console.log("reward : ",reward.toString(10));
        for (var i=0;i<300;i++){
            await liquidity.setExpiration(expiration);
        }
        reward = await liquidity.totalRewards(accounts[0]);
        console.log("reward : ",reward.toString(10));
        for (var i=0;i<300;i++){
            await liquidity.setExpiration(expiration);
        }
        reward = await liquidity.totalRewards(accounts[0]);
        console.log("reward : ",reward.toString(10));
    });
});
