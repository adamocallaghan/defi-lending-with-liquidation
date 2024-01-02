// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract TokenLending {
    // === STATE VARIABLES ===
    IERC20 public token;

    // === BALANCES ===
    mapping(address => uint256) public tokenCollateralBalances;
    mapping(address => uint256) public tokenBorrowedBalances;
    uint256 public totalTokensInContract;

    // === EVENTS ===
    event UserHasDespositedTokens();
    event UserHasWithdrawnTokens();
    event UserHasBorrowTokens();
    event UserHasRepaidLoan();

    constructor(address _token) {
        token = IERC20(_token);
    }

    // Deposit Function: Implement a depositToken function for users to add tokens.
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

    // Withdraw Function: Create a withdrawToken function for users to take back their tokens.
    function withdraw(uint256 amount) public {
        // check amount is greater than zero
        require(amount > 0, "Please specify and amount to withdraw");

        // check that user has an existing balance to withdraw
        require(
            tokenCollateralBalances[msg.sender] >= amount,
            "You do not have enough tokens deposited to withdraw that amount"
        );

        // update balances
        tokenCollateralBalances[msg.sender] -= amount;
        totalTokensInContract -= amount;

        // transfer tokens to user
        token.transfer(msg.sender, amount);

        // emit event
        emit UserHasWithdrawnTokens();
    }

    // Borrow Function: Develop a borrowToken function for users to borrow tokens.
    function bororw(uint256 amount) public {
        // check amount is greater than zero
        require(amount > 0, "Please specify an amount to borrow");

        // user can only borrow as much as they have deposited as collateral
        require(tokenCollateralBalances[msg.sender] >= amount, "You can't borrow more than you have as collateral");

        // udpate balances
        tokenBorrowedBalances[msg.sender] += amount;
        totalTokensInContract -= amount;

        // transfer tokens to user
        token.transfer(msg.sender, amount);

        // emit event
        emit UserHasBorrowTokens();
    }

    // Repay Function: Construct a repayToken function for users to return borrowed tokens.
    function repay(uint256 amount) public {
        // check amount is greater than zero
        require(amount > 0, "Please specify an amount to repay");

        // check that the user has an outstanding loan
        require(tokenBorrowedBalances[msg.sender] > amount, "You do not have an outstanding loan");

        // transfer tokens to contract
        token.transferFrom(msg.sender, address(this), amount);

        // update balances
        tokenBorrowedBalances[msg.sender] -= amount;
        totalTokensInContract += amount;

        // emit event
        emit UserHasRepaidLoan();
    }
}
