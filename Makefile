-include .env

# === DEPLOY CONTRACTS ===

deploy-token:
	forge create src/MyToken.sol:MyToken --private-key $(TOKEN_OWNER_PK)

deploy-lending:
	forge create src/TokenLending.sol:TokenLending --private-key $(DEPLOYER_PK) --constructor-args $(TOKEN_CONTRACT_ADDRESS)

# === APPROVE, DESPOSIT & WTIHDRAW TOKENS ===

approve-tokens-to-lending:
	cast send $(TOKEN_CONTRACT_ADDRESS) "approve(address,uint)" $(LENDING_CONTRACT_ADDRESS) 999999 --private-key $(TOKEN_OWNER_PK)

deposit-tokens:
	cast send $(LENDING_CONTRACT_ADDRESS) "deposit(uint)" 123456 --private-key $(TOKEN_OWNER_PK)

check-tokens-deposited:
	cast call $(LENDING_CONTRACT_ADDRESS) "totalTokensInContract()(uint)"

withdraw-tokens:
	cast send $(LENDING_CONTRACT_ADDRESS) "withdraw(uint)" 456 --private-key $(TOKEN_OWNER_PK)

# === BORROW TOKENS WITH COLLATERAL ===

# We will ask to borrow 4000 tokens using 5 ETH as collateral (1 ETH = 1000 tokens hardcoded in our contract)
# Our health factor after this should be 0.8 (i.e. we've borrowed 80%/4000 tokens of the max of 5000 that we could)
borrow-tokens-with-eth:
	cast send $(LENDING_CONTRACT_ADDRESS) "bororwTokensWithCollateral(uint)" 4000 --private-key $(DEPLOYER_PK) --value 5ether

check-tokens-borrowed:
	cast call $(LENDING_CONTRACT_ADDRESS) "tokenBorrowedBalances(address)(uint)" $(DEPLOYER_ADDRESS)

check-eth-balance-of-contract:
	cast balance $(LENDING_CONTRACT_ADDRESS)


# === REPAY TOKENS & GET BACK ETH COLLATERAL ===

approve-tokens-to-lending-deployer:
	cast send $(TOKEN_CONTRACT_ADDRESS) "approve(address,uint)" $(LENDING_CONTRACT_ADDRESS) 999999 --private-key $(DEPLOYER_PK)

repay-tokens:
	cast send $(LENDING_CONTRACT_ADDRESS) "repay(uint)" 1111 --private-key $(DEPLOYER_PK)

# === LIQUIDATE BORROWER ===

# Liquidation will fail at first because we have ensured that our borrower's health factor is above 1 when borrowing
liquidate-borrower:
	cast send $(LENDING_CONTRACT_ADDRESS) "liquidate(address,uint)" $(DEPLOYER_ADDRESS) 1655 --private-key $(TOKEN_OWNER_PK)

# We will add a bunch of tokens to the borrowers tokenBorrowedBalances - this should nuke their health factor to well below 1 and allow liquidation
nuke-health-factor:
	cast send $(LENDING_CONTRACT_ADDRESS) "nukeHealthFactor(address)" $(DEPLOYER_ADDRESS) --private-key $(TOKEN_OWNER_PK)
