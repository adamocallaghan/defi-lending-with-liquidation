## DeFi Lending: Collateralised Lending with Liquidations

**LEVEL UP, SEASON 1**
**Level 3: Collateralised Lending Contract with Liquidation**

Project contains...

CONTRACTS:

- **MyToken.sol**: a basic ERC20 token to be deposited into and borrowed from the Lending contract
- **TokenLending.sol**: the main lending and borrowing contract

FUNCTIONS

- **deposit**: deposit ERC20 tokens (i.e. deployed instance of MyToken) into the contract
- **withdraw**: withdraw ERC20 tokens
- **bororwTokensWithCollateral**: deposit ETH (via msg.value) as collateral and borrow ERC20 tokens from the contract
- **\_calculateMaxTokenBorrowAmount**: an internal function that stands in for an oracle call
- **repay**: repay ERC20 loan and retrieve ETH collateral
- **nukeHealthFactor**: this function reduces the user's health factor so they can be liquidated
- **liquidate**: repay the borrower's loan, liquidate their ETH collateral + a 10% bonus for doing so

OTHER

- **Makefile**: contains forge and cast commands for each step of the contract (e.g. run "make deploy-token" in your shell)
