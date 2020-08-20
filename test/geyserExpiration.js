const TokenGeyser = artifacts.require("TokenGeyser");
const FNXCoin = artifacts.require("FNXCoin");
const UniCoin = artifacts.require("UniCoin");
contract('TokenGeyser', function (accounts){
    it('TokenGeyser expiration', async function (){
        let geyser = await TokenGeyser.deployed();
        let fnx = await FNXCoin.deployed();
        let expiration = Math.floor(Date.now()/1000) + 30;
        await geyser.setExpiration(expiration);
        await fnx.approve(geyser.address,1000000000000000);
        await geyser.stake(1000000000000000,[]);
        let reward = await geyser.totalRewards(accounts[0]);
        console.log("reward : ",reward.toString(10));
        for (var i=0;i<300;i++){
            await geyser.setExpiration(expiration);
        }
        reward = await geyser.totalRewards(accounts[0]);
        console.log("reward : ",reward.toString(10));
        for (var i=0;i<300;i++){
            await geyser.setExpiration(expiration);
        }
        reward = await geyser.totalRewards(accounts[0]);
        console.log("reward : ",reward.toString(10));
        for (var i=0;i<300;i++){
            await geyser.setExpiration(expiration);
        }
        reward = await geyser.totalRewards(accounts[0]);
        console.log("reward : ",reward.toString(10));
        for (var i=0;i<300;i++){
            await geyser.setExpiration(expiration);
        }
        reward = await geyser.totalRewards(accounts[0]);
        console.log("reward : ",reward.toString(10));
    });
});
