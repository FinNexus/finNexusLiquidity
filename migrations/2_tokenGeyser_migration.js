const Tokenliquidity = artifacts.require("TokenLiquidity");
const FNXCoin = artifacts.require("FNXCoin");
const UniCoin = artifacts.require("UniCoin");
module.exports = async function(deployer, network,accounts) {
    let expiration = Math.floor(Date.now()/1000) + 86400*30;
    let liquidity = await deployer.deploy(Tokenliquidity,"0xDd4b9b3Ce03faAbA4a3839c8B5023b7792be6e2C","0x69120197b77b51d32fFA5eAfe16b3d78115640c6",
    86400*30,1e15,expiration);
};
