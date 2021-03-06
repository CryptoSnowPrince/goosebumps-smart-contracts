// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "../utils/Ownable.sol";
import "../interfaces/IERC20.sol";

contract ReflectionsDistributor is Ownable {
    IERC20 public stakeToken;
    address public treasury;
    uint256 public minAmountReflection = 1000 * 10**9;

    /// @notice The precision of `accRewardPerShare`
    uint256 public immutable ACC_REWARD_PER_SHARE_PRECISION;

    /// @dev Internal balance of STAKE_TOKEN, this gets updated on user deposits / withdrawals
    /// this allows to reward users with STAKE_TOKEN
    uint256 public internalEmpireBalance;

    /// @notice Last reward balance
    uint256 public lastRewardBalance;

    /// @notice Accumulated rewards per share, scaled to `ACC_REWARD_PER_SHARE_PRECISION`
    uint256 public accRewardPerShare;

    /**
     * @notice We do some fancy math here. Basically, any point in time, the amount of STAKE_TOKENs
     * entitled to a user but is pending to be distributed is:
     *
     *   pending reward = (_userAmount * accRewardPerShare) - rewardDebt[_user]
     *
     * Whenever a user deposits or withdraws STAKE_TOKEN. Here's what happens:
     *   1. accRewardPerShare (and `lastRewardBalance`) gets updated
     *   2. User receives the pending reward sent to his/her address
     *   3. User's `rewardDebt` gets updated
     */
    mapping(address => uint256) public rewardDebt;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event ClaimReward(address indexed user, uint256 amount);
    event LogSetStakeToken(address indexed stakeToken);
    event LogSetTreasury(address treasury);
    event LogSetMinAmountReflection(uint256 minAmountReflection);

    /**
     * @param _stakeToken The address of the STAKE_TOKEN token
     */
    constructor(IERC20 _stakeToken, address _treasury) {
        require(
            address(_stakeToken) != address(0) && 
            _treasury != address(0), 
            "ZERO_ADDRESS"
        );
        stakeToken = _stakeToken;
        treasury = _treasury;

        ACC_REWARD_PER_SHARE_PRECISION = 1e24;
    }

    modifier onlyTreasury() {
        require(
            _msgSender() == treasury,
            "ReflectionsDistributor: caller is not the treasury"
        );
        _;
    }

    /**
     * @notice Deposit STAKE_TOKEN for reward token allocation
     * @param _amount The amount of STAKE_TOKEN to deposit
     * @param _userAmount The previous staked amount of STAKE_TOKEN
     */
    function deposit(address _user, uint256 _amount, uint256 _userAmount) external onlyTreasury {
        uint256 _previousAmount = _userAmount;
        uint256 _newAmount = _userAmount + _amount;

        updateReward();
        uint256 _previousRewardDebt = rewardDebt[_user];
        rewardDebt[_user] =
            (_newAmount * accRewardPerShare) /
            ACC_REWARD_PER_SHARE_PRECISION;
        if (_previousAmount != 0) {
            uint256 _pending = (_previousAmount * accRewardPerShare) /
                ACC_REWARD_PER_SHARE_PRECISION -
                _previousRewardDebt;
            if (_pending > 0) {
                safeTokenTransfer(_user, _pending);
                emit ClaimReward(_user, _pending);
            }
        }

        internalEmpireBalance += _amount;
        emit Deposit(_user, _amount);
    }

    /**
     * @notice Withdraw STAKE_TOKEN and harvest the rewards
     * @param _amount The amount of STAKE_TOKEN to withdraw
     * @param _userAmount The new staked amount of STAKE_TOKEN
     */
    function withdraw(address _user, uint256 _amount, uint256 _userAmount) external onlyTreasury {
        uint256 _previousAmount = _userAmount + _amount;
        uint256 _newAmount = _userAmount;

        updateReward();
        uint256 _pending = (_previousAmount * accRewardPerShare) /
            ACC_REWARD_PER_SHARE_PRECISION -
            rewardDebt[_user];
        rewardDebt[_user] =
            (_newAmount * accRewardPerShare) /
            ACC_REWARD_PER_SHARE_PRECISION;
        if (_pending > 0) {
            safeTokenTransfer(_user, _pending);
            emit ClaimReward(_user, _pending);
        }

        internalEmpireBalance -= _amount;

        emit Withdraw(_user, _amount);
    }

    /**
     * @notice Update reward variables
     * @dev Needs to be called before any deposit or withdrawal
     */
    function updateReward() internal {
        uint256 _totalEmpire = internalEmpireBalance;

        uint256 _currRewardBalance = stakeToken.balanceOf(address(this));
        uint256 _rewardBalance = _currRewardBalance;

        // Did ReflectionsDistributor receive any token
        if (
            _rewardBalance >= lastRewardBalance + minAmountReflection &&
            _totalEmpire > 0
        ) {
            uint256 _accruedReward = _rewardBalance - lastRewardBalance;

            accRewardPerShare =
                accRewardPerShare +
                (_accruedReward * ACC_REWARD_PER_SHARE_PRECISION) /
                _totalEmpire;
            lastRewardBalance = _rewardBalance;
        }
    }

    /**
     * @notice Safe token transfer function, just in case if rounding error
     * causes pool to not have enough reward tokens
     * @param _to The address that will receive `_amount` `rewardToken`
     * @param _amount The amount to send to `_to`
     */
    function safeTokenTransfer(address _to, uint256 _amount) internal {
        uint256 _currRewardBalance = stakeToken.balanceOf(address(this));
        uint256 _rewardBalance = _currRewardBalance;

        if (_amount > _rewardBalance) {
            lastRewardBalance = lastRewardBalance - _rewardBalance;
            require(stakeToken.transfer(_to, _rewardBalance), "Transfer fail");
        } else {
            lastRewardBalance = lastRewardBalance - _amount;
            require(stakeToken.transfer(_to, _amount), "Transfer fail");
        }
    }
    
    function setStakeToken(address _stakeToken) external onlyMultiSig {
        require(_stakeToken != address(0), "ZERO_ADDRESS");
        require(_stakeToken != address(stakeToken), "SAME_ADDRESS");
        stakeToken = IERC20(_stakeToken);

        emit LogSetStakeToken(_stakeToken);
    }

    function setTreasury(address _treasury) external onlyMultiSig {
        require(address(0) != _treasury, "ZERO_ADDRESS");
        require(treasury != _treasury, "SAME_ADDRESS");
        treasury = _treasury;
        emit LogSetTreasury(treasury);
    }

    function setMinAmountReflection(uint256 _minAmountReflection)
        external
        onlyMultiSig
    {
        require(minAmountReflection != _minAmountReflection, "SAME_VALUE");
        minAmountReflection = _minAmountReflection;
        emit LogSetMinAmountReflection(minAmountReflection);
    }

    /**
     * @notice View function to see pending reward token on frontend
     * @param _user The address of the user
     * @param _userAmount The staked amount of STAKE_TOKEN
     * @return uint256 `_user`'s pending reward token
     */
    function pendingReward(address _user, uint256 _userAmount ) external view returns (uint256) {
        uint256 _totalEmpire = internalEmpireBalance;
        uint256 _accRewardTokenPerShare = accRewardPerShare;

        uint256 _currRewardBalance = stakeToken.balanceOf(address(this));
        uint256 _rewardBalance = _currRewardBalance;

        if (
            _rewardBalance >= lastRewardBalance + minAmountReflection &&
            _totalEmpire > 0
        ) {
            uint256 _accruedReward = _rewardBalance - lastRewardBalance;
            _accRewardTokenPerShare =
                _accRewardTokenPerShare +
                (_accruedReward * ACC_REWARD_PER_SHARE_PRECISION) /
                _totalEmpire;
        }
        return
            (_userAmount * _accRewardTokenPerShare) /
            ACC_REWARD_PER_SHARE_PRECISION -
            rewardDebt[_user];
    }
}
