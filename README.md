# Donut Trumpet Token Contract

## Overview
The Donut Trumpet Token is a configurable deflationary token designed to work with DEXs like Uniswap. During testing, it was observed that Uniswap V3 has specific requirements for token transfers, which have been addressed in this contract.

## Key Features

### Fee Implementation
1. **Default Fee Cut Behaviour**:
   - Uniswap checks if the pool receives the full input amount when a wallet swaps their tokens. To comply with this, the fee is added to the input amount by default instead of being deducted from the input amount.

2. **Conditional Fee Payment**:
   - Uniswap also verifies that the pool sends only the expected amount of tokens when swapped. To accommodate this, the contract includes a feature that allows only one side to pay the fee. If a special fee payer is set for the pool, the fee is paid only when a wallet sells their tokens.

### Trade Tax Application
- When the contract is called by another contract and the recipient is the transaction origin, it is considered a trade, and the trade fee is applied.

### Tax Configuration
- The contract allows for the disabling of fees for transactions and/or trades.
- It is also possible to set special fee percentage to a certain wallet or contract address.
- There is an option to switch the fee application method from being added to the amount to being deducted from the amount, if needed.

## Dependencies
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
nvm install 20
```

```bash
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-foundry-upgrades --no-commit
forge install OpenZeppelin/openzeppelin-contracts-upgradeable --no-commit
```

## Deployment
```bash
forge script script/DonutTrumpet.s.sol --broadcast --private-key <YOUR_PRIVATE_KEY> --rpc-url <YOUR_RPC_URL>
```