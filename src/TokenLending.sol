// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "forge-std/console2.sol";

interface AggregatorV3Interface {
    function latestAnswer() external view returns (int256);
}

contract TokenLending {
    // === STATE VARIABLES ===
    IERC20 public token;

    // === ORACLE ADDRESS ===
    /**
     * Network: Eth Mainnnet
     * Aggregator: ETH/USD
     * Address: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
     */
    AggregatorV3Interface internal dataFeed = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    // === BALANCES ===
    mapping(address => uint256) public tokenCollateralBalances;
    mapping(address => uint256) public tokenBorrowedBalances;
    mapping(address => uint256) public ethCollateralBalances;
    uint256 public totalTokensInContract;
    uint256 public MIN_HEALTH_FACTOR = 1e18;
    uint256 public PRECISION = 1e18;

    // === EVENTS ===
    event UserHasDespositedTokens();
    event UserHasWithdrawnTokens();
    event UserHasBorrowTokens();
    event UserHasRepaidLoan();

    constructor(address _token) {
        token = IERC20(_token);
    }

    // @notice DEPOSIT and WITHDRAW functions are for users to deposit the borrowable ERC20 tokens into the contract

    // === DEPOSIT: deposit ERC20 tokens (that can then be borrowed by borrowers)
    function deposit(uint256 amount) public {
        // check amount is greater than zero
        require(amount > 0, "Please deposit an amount greater than zero");

        // *** EOA should call approve on the token contract to allow lending contract to spend/transfer it's tokens ***

        // transfer tokens from msg.sender to contract
        token.transferFrom(msg.sender, address(this), amount);

        // update balances
        tokenCollateralBalances[msg.sender] += amount;
        totalTokensInContract += amount;

        // emit event
        emit UserHasDespositedTokens();
    }

    // === WITHDRAW: withdraw ERC20 tokens
    function withdraw(uint256 amount) public {
        // check amount is greater than zero
        require(amount > 0, "Please specify and amount to withdraw");

        // check that user has an existing balance to withdraw
        require(
            tokenCollateralBalances[msg.sender] >= amount,
            "You do not have enough tokens deposited to withdraw that amount"
        );

        // check that contract has enough tokens for user to withdraw requested amount
        require(amount < totalTokensInContract, "There are currently not enough tokens in the contract to withdraw");

        // update balances
        tokenCollateralBalances[msg.sender] -= amount;
        totalTokensInContract -= amount;

        // transfer tokens to user
        token.transfer(msg.sender, amount);

        // emit event
        emit UserHasWithdrawnTokens();
    }

    // Borrow Function: Develop a borrowToken function for users to borrow tokens.
    function bororwTokensWithCollateral(uint256 amount) public payable {
        // check amount is greater than zero
        require(amount > 0, "Please specify an amount to borrow");

        // calculate the max tokens they can borrow based on the ETH transfered into the contract
        uint256 amountEthCollateralInWei = msg.value; // will be in WEI, so 5 ETH = 5 000 000 000 000 000 000 WEI
        uint256 maxTokenBorrowAmount = _calculateMaxTokenBorrowAmount(amountEthCollateralInWei);

        // can't borrow more than the max
        require(amount < maxTokenBorrowAmount, "Borrow amount requested too high");

        // update eth balances
        ethCollateralBalances[msg.sender] += msg.value;

        // udpate token balances
        tokenBorrowedBalances[msg.sender] += amount;
        totalTokensInContract -= amount;

        // transfer tokens to user
        token.transfer(msg.sender, amount);

        // emit event
        emit UserHasBorrowTokens();
    }

    function _calculateMaxTokenBorrowAmount(uint256 amountEthCollateralInWei) internal returns (uint256) {
        // amountInEth = 5000000000000000000 / 1e18 = 5
        uint256 amountInEth = amountEthCollateralInWei / 1e18;
        uint256 ethPriceInUsd = uint256(_getChainlinkDataFeedLatestAnswer()); // returns the price in 4 digit magnitude
        uint256 maxTokenBorrowAmount = amountInEth * ethPriceInUsd;
        return maxTokenBorrowAmount;
    }

    /**
     * Returns the latest answer from Chainlink's ETH-USD feed
     */
    function _getChainlinkDataFeedLatestAnswer() internal view returns (int256) {
        // latestAnswer returns 8 decinamls (e.g. if ETH is $2235, then answer would return 223500000000, or 2235e8)
        int256 answer = dataFeed.latestAnswer();
        return answer / 1e8; // e.g. if ETH is 223500000000 this will return 2235
    }

    // Repay Function: Construct a repayToken function for users to return borrowed tokens.
    function repay(uint256 amountToRepay) public {
        // check amount is greater than zero
        require(amountToRepay > 0, "Please specify an amount to repay");

        // check that the user has an outstanding loan
        require(tokenBorrowedBalances[msg.sender] > amountToRepay, "You do not have an outstanding loan");

        // @notice: As with depositing tokens...
        /// ...the EOA should call approve on the token contract to allow lending contract to spend/transfer it's tokens

        // transfer tokens to contract
        token.transferFrom(msg.sender, address(this), amountToRepay);

        // update balances
        tokenBorrowedBalances[msg.sender] -= amountToRepay;
        totalTokensInContract += amountToRepay;

        // calculate amount of ETH to transfer back to borrower based on the tokens repaid...
        // 1111 * 1e18 = 1111000000000000000000 (aka 1111e18)
        // 1111000000000000000000 / 2235 = 497091722595078299 (aka 0.49 ETH)
        // 1.111000000000000000
        // 0.497091722595078299
        //
        uint256 ethPriceInUsd = uint256(_getChainlinkDataFeedLatestAnswer());
        uint256 ethToRefund = (amountToRepay * 1e18) / ethPriceInUsd; // 1111000000000000000
        // transfer ETH collateral back to borrower
        payable(msg.sender).transfer(ethToRefund);

        // emit event
        emit UserHasRepaidLoan();
    }

    function nukeHealthFactor(address borrower) external {
        // add 987000 tokens to the borrower's borrowed amount
        tokenBorrowedBalances[borrower] += 987000;
    }

    function liquidate(address borrower, uint256 tokenAmountToRepay) external payable {
        // check that borrower has a bad LTV ratio (i.e. tokens borrowed exceed acceptable levels compared to ETH collateral deposited)
        // tokenBorrowedBalances[borrower] - will be in standard magnitude, e.g. 5000
        uint256 tokensCurrentlyBorrowed = tokenBorrowedBalances[borrower];

        require(
            tokenAmountToRepay <= tokensCurrentlyBorrowed,
            "You are trying to repay beyond what was issued for the loan you are trying to liquidate"
        );

        uint256 borrowerHealthFactor = _getBorrowerHealthFactor(borrower);

        require(borrowerHealthFactor < MIN_HEALTH_FACTOR, "User loan is not liquidatable");

        // transfer tokens from liquidator into the contract
        token.transfer(msg.sender, tokenAmountToRepay);

        // update token balances (of borrower) - i.e. loan repaid to a certain level (liquidator has paid off some of their loan)
        tokenBorrowedBalances[borrower] -= tokenAmountToRepay;

        // calculate amount of ETH to send to the liquidator - i.e. the value (in ETH) of the tokens they've repaid
        uint256 tokensPerEth = uint256(_getChainlinkDataFeedLatestAnswer());
        uint256 ethAmountInWei = (tokenAmountToRepay * PRECISION) / (tokensPerEth);

        // calculate their BONUS (10%) in ETH that they will get for liquidating the user and maintaining the health of the protocol
        uint256 bonus = ethAmountInWei / 10; // e.g. 5000000000000000000 / 10 = 500000000000000000
        uint256 totalEthToLiquidator = ethAmountInWei + bonus; // 5000000000000000000 + 500000000000000000 (or 5e18 + 5e17) = 5500000000000000000

        // transfer ETH to liquidator
        payable(msg.sender).transfer(totalEthToLiquidator);
    }

    function _getBorrowerHealthFactor(address borrower) internal view returns (uint256) {
        // get borrower's borrowed tokens amount
        uint256 borrowed = tokenBorrowedBalances[borrower]; // e.g. 10,000 tokens
        uint256 borrowedWithPrecision = borrowed * PRECISION; // i.e. 10,000-000-000-000-000-000-000

        // get borower's ETH collateral amount
        uint256 ethCollateralInWei = ethCollateralBalances[borrower]; // e.g. 5,000,000,000,000,000,000 WEI

        // call oracle to get price of ETH in USD (our tokens are USD-pegged for ease of demonstration)
        uint256 ethPriceInUsd = uint256(_getChainlinkDataFeedLatestAnswer()); // e.g. 2235
        uint256 ethPriceInUsdWithPrecision = ethPriceInUsd * PRECISION; // i.e. 2,235-000-000-000-000-000-000

        // calculate health factor
        uint256 healthFactor = (ethCollateralInWei * ethPriceInUsdWithPrecision) / borrowedWithPrecision;
        return healthFactor;
    }
}
