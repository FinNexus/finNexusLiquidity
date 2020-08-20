const Tokenliquidity = artifacts.require("TokenLiquidity");
const FNXCoin = artifacts.require("FNXCoin");
const UniCoin = artifacts.require("UniCoin");
module.exports = async function(deployer, network,accounts) {
    let fnx = await deployer.deploy(FNXCoin);
    let uni = await deployer.deploy(UniCoin);
    let expiration = Math.floor(Date.now()/1000) + 86400;
    let liquidity = await deployer.deploy(Tokenliquidity,FNXCoin.address,UniCoin.address,86400,1e15,expiration);
};
