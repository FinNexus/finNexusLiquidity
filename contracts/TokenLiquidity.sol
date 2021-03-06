pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

import "./IStaking.sol";
import "./TokenPool.sol";

/**
 * @title Token liquidityity
 * @dev A smart-contract based mechanism to distribute tokens over time, inspired loosely by
 *      Compound and Uniswap.
 *
 *      Distribution tokens are added to a locked pool in the contract and become unlocked over time
 *      according to a once-configurable unlock schedule. Once unlocked, they are available to be
 *      claimed by users.
 *
 *      A user may deposit tokens to accrue ownership share over the unlocked pool. This owner share
 *      is a function of the number of tokens deposited as well as the length of time deposited.
 *      Specifically, a user's share of the currently-unlocked pool equals their "deposit-seconds"
 *      divided by the global "deposit-seconds". This aligns the new token distribution with long
 *      term supporters of the project, addressing one of the major drawbacks of simple airdrops.
 *
 *      More background and motivation available at:
 *      https://github.com/ampleforth/RFCs/blob/master/RFCs/rfc-1.md
 */
contract TokenLiquidity is IStaking, Ownable {
    using SafeMath for uint256;

    event Staked(address indexed user, uint256 amount, uint256 total, bytes data);
    event Unstaked(address indexed user, uint256 amount, uint256 total, bytes data);
    event TokensClaimed(address indexed user, uint256 amount);
    event Contributed(uint256 indexed amount, uint256 indexed total);

    TokenPool private _stakingPool;
    TokenPool private _distributionPool;

    //
    // Time-bonus params
    //
    uint256 public constant BONUS_DECIMALS = 2;
    uint256 public bonusPeriodSec = 0;

    //
    // Global accounting state
    //
    uint256 public totalContribution = 0;
    uint256 public totalClaimed = 0;

    uint256 public totalLockedShares = 0;
    uint256 private _initialSharesPerToken = 0;

    uint256 public expiration;

    //
    // User accounting state
    //
    // Represents a single stake for a user. A user may have multiple.
    struct Stake {
        uint256 stakingShares;  // the max token B
        uint256 staking; // the token A
        uint256 timestampSec;
    }

    // Caches aggregated values from the User->Stake[] map to save computation.
    // If lastAccountingTimestampSec is 0, there's no entry for that user.
    struct UserTotals {
        uint256 staking; // the token A
        uint256 stakingShareSeconds;
        uint256 lastAccountingTimestampSec;
    }

    // Aggregated staking values per user
    mapping(address => UserTotals) private _userTotals;

    // The collection of stakes for each user. Ordered by timestamp, earliest to latest.
    mapping(address => Stake[]) private _userStakes;


    /**
     * @param stakingToken The token users deposit as stake.
     * @param distributionToken The token users receive as they unstake.
     * @param bonusPeriodSec_ Length of time for bonus to increase linearly to max.
     * @param initialSharesPerToken Number of shares to mint per staking token on first stake.
     * @param _expiration expiration time of this miner poor.
     */
    constructor(IERC20 stakingToken, IERC20 distributionToken,
                uint256 bonusPeriodSec_, uint256 initialSharesPerToken,uint256 _expiration) public {
        // and bonusPeriod to a small value like 1sec.
        require(bonusPeriodSec_ != 0, 'Tokenliquidityity: bonus period is zero');
        require(initialSharesPerToken > 0, 'Tokenliquidityity: initialSharesPerToken is zero');

        _stakingPool = new TokenPool(stakingToken);
        _distributionPool = new TokenPool(distributionToken);
        bonusPeriodSec = bonusPeriodSec_;
        _initialSharesPerToken = initialSharesPerToken;
        expiration = _expiration;
    }

    /**
     * @return The token users deposit as stake.
     */
    function getStakingToken() public view returns (IERC20) {
        return _stakingPool.token();
    }

    function setInitialSharesPerToken(uint init) public onlyOwner {
        _initialSharesPerToken = init;
    }
    function getInitialSharesPerToken() public view returns(uint) {
        return _initialSharesPerToken;
    }
    function setExpiration(uint256 _expiration)public onlyOwner{
        expiration = _expiration;
    }
    function setBonusPeriod(uint period) public onlyOwner{
        bonusPeriodSec = period;
    }

    /**
     * @return The token users receive as they unstake.
     */
    function getDistributionToken() public view returns (IERC20) {
        return _distributionPool.token();
    }

    /**
     * @dev Transfers amount of deposit tokens from the user.
     * @param amount Number of deposit tokens to stake.
     * @param data Not used.
     */
    function stake(uint256 amount, bytes calldata data) external {
        _stakeFor(msg.sender, msg.sender, amount);
    }

    /**
     * @dev Transfers amount of deposit tokens from the caller on behalf of user.
     * @param user User address who gains credit for this stake operation.
     * @param amount Number of deposit tokens to stake.
     * @param data Not used.
     */
    function stakeFor(address user, uint256 amount, bytes calldata data) external {
        _stakeFor(msg.sender, user, amount);
    }

    /**
     * @dev Private implementation of staking methods.
     * @param staker User address who deposits tokens to stake.
     * @param beneficiary User address who gains credit for this stake operation.
     * @param amount Number of deposit tokens to stake.
     */
    function _stakeFor(address staker, address beneficiary, uint256 amount) private {
        require(now < expiration, 'Tokenliquidityity: staking is expired');
        require(amount > 0, 'Tokenliquidityity: stake amount is zero');
        require(beneficiary != address(0), 'Tokenliquidityity: beneficiary is zero address');

        uint256 mintedStakingShares = amount.mul(_initialSharesPerToken).div(10000);
        require(mintedStakingShares > 0, 'Tokenliquidityity: Stake amount is too small');

        //updateAccounting();

        // 1. User Accounting
        UserTotals storage totals = _userTotals[beneficiary];
        totals.staking = totals.staking.add(amount);
        totals.lastAccountingTimestampSec = now;

        Stake memory newStake = Stake(mintedStakingShares, amount, now);
        _userStakes[beneficiary].push(newStake);

        // interactions
        require(_stakingPool.token().transferFrom(staker, address(_stakingPool), amount),
            'Tokenliquidityity: transfer into staking pool failed');

        emit Staked(beneficiary, amount, totalStakedFor(beneficiary), "");
    }

    /**
     * @dev Unstakes a certain amount of previously deposited tokens. User also receives their
     * alotted number of distribution tokens.
     * @param amount Number of deposit tokens to unstake / withdraw.
     * @param data Not used.
     */
    function unstake(uint256 amount, bytes calldata data) external {
        _unstake(amount);
    }
    function unstakeAll() external {
        uint amount = totalStakedFor(msg.sender);
        _unstake(amount);
    }
    /**
     * @param amount Number of deposit tokens to unstake / withdraw.
     * @return The total number of distribution tokens that would be rewarded.
     */
    function unstakeQuery(uint256 amount) public returns (uint256) {
        return _unstake(amount);
    }

    /**
     * @dev Unstakes a certain amount of previously deposited tokens. User also receives their
     * alotted number of distribution tokens.
     * @param amount Number of deposit tokens to unstake / withdraw.
     * @return The total number of distribution tokens rewarded.
     */
    function _unstake(uint256 amount) private returns (uint256) {
        //updateAccounting();

        // checks
        require(amount > 0, 'Tokenliquidityity: unstake amount is zero');
        require(totalStakedFor(msg.sender) >= amount,
            'Tokenliquidityity: unstake amount is greater than total user stakes');

        // 1. User Accounting
        UserTotals storage totals = _userTotals[msg.sender];
        Stake[] storage accountStakes = _userStakes[msg.sender];

        // Redeem from most recent stake and go backwards in time.
        uint256 amountLeft = amount;
        uint256 rewardAmount = 0;
        while (amountLeft > 0) {
            Stake storage lastStake = accountStakes[accountStakes.length - 1];
//            uint256 stakeTimeSec = now.sub(lastStake.timestampSec);
            //uint256 newStakingShareToBurn = 0;
            if (lastStake.staking <= amountLeft) {
                // fully redeem a past stake
                // newStakingShareToBurn = lastStake.stakingShares;
                rewardAmount = computeNewReward(rewardAmount, lastStake.stakingShares, lastStake.timestampSec);
                amountLeft = amountLeft.sub(lastStake.staking);
                accountStakes.length--;
            } else {
                // partially redeem a past stake
                uint256 oneRewardAmountAll = computeNewReward(0, lastStake.stakingShares, lastStake.timestampSec);
                uint256 oneRewardAmountReal = oneRewardAmountAll.mul(amountLeft).div(lastStake.staking);
                rewardAmount += oneRewardAmountReal;
                lastStake.stakingShares =  lastStake.stakingShares.mul(lastStake.staking - amountLeft).div(lastStake.staking);
                lastStake.staking = lastStake.staking.sub(amountLeft);

                amountLeft = 0;
            }
        }
        totals.staking = totals.staking.sub(amount);
        // interactions
        require(_stakingPool.transfer(msg.sender, amount),
            'Tokenliquidityity: transfer out of staking pool failed');
        require(_distributionPool.transfer(msg.sender, rewardAmount),
            'Tokenliquidityity: transfer out of _distribution pool failed');

        emit Unstaked(msg.sender, amount, totalStakedFor(msg.sender), "");
        emit TokensClaimed(msg.sender, rewardAmount);

        return rewardAmount;
    }
    function totalRewards(address account) public view returns(uint256){
        Stake[] storage accountStakes = _userStakes[account];
        uint rewardAmount = 0;
        for (uint256 i = 0; i< accountStakes.length; i++) {
            Stake storage oneStake = accountStakes[i];
            //uint256 stakeTimeSec = now.sub(oneStake.timestampSec);
            rewardAmount = computeNewReward(rewardAmount, oneStake.stakingShares, oneStake.timestampSec);
        }
        return rewardAmount;        
    }
    /**
     * @dev Applies an additional time-bonus to a distribution amount. This is necessary to
     *      encourage long-term deposits instead of constant unstake/restakes.
     *      ends at 100% over bonusPeriodSec, then stays at 100% thereafter.
     * @param currentRewardTokens The current number of distribution tokens already alotted for this
     *                            unstake op. Any bonuses are already applied.
     * @param stakeTimeSec Time for which the tokens were staked. Needed to calculate
     *                     the time-bonus.
     * @return Updated amount of distribution tokens to award, with any bonus included on the
     *         newly added tokens.
     */
    function computeNewReward(uint256 currentRewardTokens,
                                uint256 stakingShare,
                                uint256 stakeTimeSec) public view returns (uint256) { //TODO : private???

        stakeTimeSec = now <expiration ? now.sub(stakeTimeSec) : expiration.sub(stakeTimeSec);        
        //uint256 newRewardTokens = stakingShare;
        if (stakeTimeSec >= bonusPeriodSec) {
            return currentRewardTokens.add(stakingShare);
        }
        uint256 bonusedReward = stakingShare.mul(stakeTimeSec).div(bonusPeriodSec);
        return currentRewardTokens.add(bonusedReward);
    }

    /**
     * @param addr The user to look up staking information for.
     * @return The number of staking tokens deposited for addr.
     */
    function totalStakedFor(address addr) public view returns (uint256) {
        return _userTotals[addr].staking;
    }

    /**
     * @return The total number of deposit tokens staked globally, by all users.
     */
    function totalStaked() public view returns (uint256) {
        return _stakingPool.balance();
    }

    /**
     * @dev Note that this application has a staking token as well as a distribution token, which
     * may be different. This function is required by EIP-900.
     * @return The deposit token used for staking.
     */
    function token() external view returns (address) {
        return address(getStakingToken());
    }


    /**
     * @return Total number of distribution tokens balance.
     */
    function distributionBalance() public view returns (uint256) {
        return _distributionPool.balance();
    }


    /**
     * @dev distribute token to distribution pool. Publicly callable.
     * @return Number of total distribution tokens.
     */
    function contributeTokens(uint256 amount) public returns (uint256) {
        // interactions
        require(_distributionPool.token().transferFrom(msg.sender, address(_distributionPool), amount),
            'Tokenliquidityity: transfer into staking pool failed');

        totalContribution += amount;
        emit Contributed(amount, totalContribution);
        return totalContribution;
    }

    function unlockToken() public onlyOwner {
        uint amount = _distributionPool.balance();
        require(_distributionPool.transfer(owner(), amount),
            'Tokenliquidityity: transfer _distribution pool failed');
        return;
    }

}
