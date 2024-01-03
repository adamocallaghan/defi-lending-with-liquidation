// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract TokenLending {
    // === STATE VARIABLES ===
    IERC20 public token;

    // === BALANCES ===
    mapping(address => uint256) public tokenCollateralBalances;
    mapping(address => uint256) public tokenBorrowedBalances;
    mapping(address => uint256) public ethCollateralBalances;
    uint256 public totalTokensInContract;
    uint256 public MIN_HEALTH_FACTOR = 1000 * 1e12;

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
        require(amount > 0, "Plesee deposit an amount greater than zero");

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

        // user can only borrow as much as they have deposited as collateral
        // require(tokenCollateralBalances[msg.sender] >= amount, "You can't borrow more than you have as collateral");
        uint256 amountEthCollateral = msg.value; // 5 ETH = 5 000 000 000 000 000 000 WEI
        uint256 maxTokenBorrowAmount = _calculateTokenAmountUsingOracle(amountEthCollateral);
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

    function _calculateTokenAmountUsingOracle(uint256 amountEthCollateral) internal returns (uint256) {
        // NEXT CALC IS...
        // 5000000000000000000 * 1000 = 5000000000000000000000
        // 5000000000000000000000 / 1e18 = 5000 (max tokens to borrow)
        uint256 maxTokens = amountEthCollateral * 1000;
        uint256 maxTokenBorrowAmount = maxTokens / 1e18;

        // RATIO OF TOKENS TO ETH IN THE REAL WORLD WOULD BE DYNAMIC
        // IN ORDER TO CALCULATE THE AMOUNT OF OUR TOKEN PER ETH WE'D NEED TO CALL AN ORACLE
        return maxTokenBorrowAmount;
    }

    // Repay Function: Construct a repayToken function for users to return borrowed tokens.
    function repay(uint256 amountToRepay) public {
        // check amount is greater than zero
        require(amountToRepay > 0, "Please specify an amount to repay");

        // check that the user has an outstanding loan
        require(tokenBorrowedBalances[msg.sender] > amountToRepay, "You do not have an outstanding loan");

        // transfer tokens to contract
        token.transferFrom(msg.sender, address(this), amountToRepay);

        // update balances
        tokenBorrowedBalances[msg.sender] -= amountToRepay;
        totalTokensInContract += amountToRepay;

        // calculate amount of ETH to transfer back to borrower based on the tokens repaid
        uint256 ethToRefund = amountToRepay / 1000;
        // transfer ETH collateral back to borrower
        payable(msg.sender).transfer(ethToRefund);

        // emit event
        emit UserHasRepaidLoan();
    }

    function liquidate(address borrower, uint256 tokenAmountToRepay) external payable {
        // check that borrower has a bad LTV ratio (i.e. tokens borrowed exceed acceptable levels compared to ETH collaeral deposited)
        // tokenBorrowedBalances[borrower] - will be in standard magnitude, e.g. 5000
        uint256 tokensCurrentlyBorrowed = tokenBorrowedBalances[borrower];
        require(
            tokenAmountToRepay <= tokensCurrentlyBorrowed,
            "You are trying to repay beyond what was issued for the loan you are trying to liquidate"
        );
        // ethCollateralBalances[borrower] - will be in WEI - so 5 ETH = 5000000000000000000
        uint256 ethCollateralInWei = ethCollateralBalances[borrower];
        // OK! e.g. borrowerHealthFactor = 5000000000000000000 / 5000 (1000000000000000, exactly the same as MIN_HEALTH_FACTOR)
        // OK! e.g. borrowerHealthFactor = 5000000000000000000 / 4000 (1250000000000000, 25% above MIN_HEALTH_FACTOR)
        // LIQUIDATABLE! e.g. borrowerHealthFactor = 5000000000000000000 / 6000 (833333333333333, 16.66% under MIN_HEALTH_FACTOR)
        uint256 borrowerHealthFactor = ethCollateralInWei / tokensCurrentlyBorrowed;

        require(borrowerHealthFactor < MIN_HEALTH_FACTOR, "User loan is not liquidatable");

        // transfer tokens from liquidator into the contract
        token.transfer(msg.sender, tokenAmountToRepay);

        // update token balances (of borrower) - i.e. loan repaid to a certain level
        tokenBorrowedBalances[borrower] -= tokenAmountToRepay;

        // calculate amount of ETH to send to the liquidator - i.e. the value of their tokens repaid in ETH
        uint256 oneEth = 1e18;
        uint256 tokensPerEth = 1000;
        uint256 ethAmount = tokenAmountToRepay / tokensPerEth;
        uint256 ethAmountInWei = ethAmount * 1e18;

        // calculate their BONUS (10%) in ETH that they will get for liquidating the user and maintaining the health of the protocol
        uint256 bonus = ethAmountInWei / 10;
        uint256 totalEthToLiquidator = ethAmountInWei + bonus;

        // transfer ETH to liquidator
        payable(msg.sender).transfer(totalEthToLiquidator);
    }
}
