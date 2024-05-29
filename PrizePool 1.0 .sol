// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PrizePool is ERC20 {

    uint256 public constant TAX_RATE = 5; // 5%
    uint256 public constant BIWEEKLY_DISTRIBUTION = 50; // 50% of the tax
    uint256 public constant SEMIQUARTERLY_DISTRIBUTION = 20; // 20% of the tax
    uint256 public constant ANNUAL_DISTRIBUTION = 30; // 30% of the tax
    uint256 public constant MIN_BALANCE = 5000 * 10 ** 18; // 5000 tokens
    uint256 public constant THREE_MONTHS = 90 days; // Approximately 3 months in seconds
    uint256 public constant ONE_YEAR = 365 days; // Approximately 1 year in seconds

    uint256 public biWeeklyPool;
    uint256 public semiQuarterlyPool;
    uint256 public annualPool;

    uint256 public lastBiWeeklyDistribution;
    uint256 public lastSemiQuarterlyDistribution;
    uint256 public lastAnnualDistribution;

    mapping(address => uint256) public eligibleBalances;
    address[] public eligibleHolders;

    event BiWeeklyWinner(address indexed winner, uint256 amount);
    event SemiQuarterlyWinner(address indexed winner, uint256 amount);
    event AnnualWinner(address indexed winner, uint256 amount);

    constructor() ERC20("PrizePool", "PPL") {
        _mint(msg.sender, 100000000 * 10 ** 18); // 100 million tokens
        uint256 startTime = block.timestamp + 1 days;
        lastBiWeeklyDistribution = startTime;
        lastSemiQuarterlyDistribution = startTime;
        lastAnnualDistribution = startTime;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        uint256 taxAmount = amount * TAX_RATE / 100;
        uint256 transferAmount = amount - taxAmount;

        biWeeklyPool += taxAmount * BIWEEKLY_DISTRIBUTION / 100;
        semiQuarterlyPool += taxAmount * SEMIQUARTERLY_DISTRIBUTION / 100;
        annualPool += taxAmount * ANNUAL_DISTRIBUTION / 100;

        _transfer(_msgSender(), recipient, transferAmount);

        _updateEligibility(_msgSender());
        _updateEligibility(recipient);

        _checkDistributions();

        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        uint256 currentAllowance = allowance(sender, _msgSender());
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        uint256 taxAmount = amount * TAX_RATE / 100;
        uint256 transferAmount = amount - taxAmount;

        biWeeklyPool += taxAmount * BIWEEKLY_DISTRIBUTION / 100;
        semiQuarterlyPool += taxAmount * SEMIQUARTERLY_DISTRIBUTION / 100;
        annualPool += taxAmount * ANNUAL_DISTRIBUTION / 100;

        _transfer(sender, recipient, transferAmount);

        _updateEligibility(sender);
        _updateEligibility(recipient);

        _checkDistributions();

        return true;
    }

    function _updateEligibility(address account) internal {
        uint256 balance = balanceOf(account);

        if (balance >= MIN_BALANCE && eligibleBalances[account] == 0) {
            eligibleHolders.push(account);
        }

        if (balance < MIN_BALANCE && eligibleBalances[account] != 0) {
            _removeFromEligible(account);
        }

        eligibleBalances[account] = balance;
    }

    function _checkDistributions() internal {
        if (block.timestamp >= lastBiWeeklyDistribution + 2 weeks) {
            _distributeBiWeekly();
        }

        if (block.timestamp >= lastSemiQuarterlyDistribution + THREE_MONTHS) {
            _distributeSemiQuarterly();
        }

        if (block.timestamp >= lastAnnualDistribution + ONE_YEAR) {
            _distributeAnnual();
        }
    }

    function _distributeBiWeekly() internal {
        address winner = _randomEligibleHolder();
        uint256 amount = biWeeklyPool;
        biWeeklyPool = 0;
        lastBiWeeklyDistribution = block.timestamp;

        if (winner != address(0)) {
            _transfer(address(this), winner, amount);
            emit BiWeeklyWinner(winner, amount);
        }
    }

    function _distributeSemiQuarterly() internal {
        address winner = _randomEligibleHolder();
        uint256 amount = semiQuarterlyPool;
        semiQuarterlyPool = 0;
        lastSemiQuarterlyDistribution = block.timestamp;

        if (winner != address(0)) {
            _transfer(address(this), winner, amount);
            emit SemiQuarterlyWinner(winner, amount);
        }
    }

    function _distributeAnnual() internal {
        address winner = _randomEligibleHolder();
        uint256 amount = annualPool;
        annualPool = 0;
        lastAnnualDistribution = block.timestamp;

        if (winner != address(0)) {
            _transfer(address(this), winner, amount);
            emit AnnualWinner(winner, amount);
        }
    }

    function _randomEligibleHolder() internal view returns (address) {
        uint256 eligibleCount = eligibleHolders.length;
        if (eligibleCount == 0) return address(0);

        uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, blockhash(block.number - 1)))) % eligibleCount;

        // Implementing slight edge towards larger holders (5% weight bias)
        if (eligibleBalances[eligibleHolders[randomIndex]] >= MIN_BALANCE * 2) {
            if (uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, randomIndex))) % 100 < 5) {
                return eligibleHolders[randomIndex];
            }
        }

        return eligibleHolders[randomIndex];
    }

    function _removeFromEligible(address account) internal {
        for (uint256 i = 0; i < eligibleHolders.length; i++) {
            if (eligibleHolders[i] == account) {
                eligibleHolders[i] = eligibleHolders[eligibleHolders.length - 1];
                eligibleHolders.pop();
                break;
            }
        }
        eligibleBalances[account] = 0;
    }

    function isEligibleForLottery(address account) external view returns (bool) {
        return eligibleBalances[account] >= MIN_BALANCE;
    }

    function getPools() external view returns (uint256, uint256, uint256) {
        return (biWeeklyPool, semiQuarterlyPool, annualPool);
    }

    function getLastDistributions() external view returns (uint256, uint256, uint256) {
        return (lastBiWeeklyDistribution, lastSemiQuarterlyDistribution, lastAnnualDistribution);
    }
}
