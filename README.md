# Governance Wallet

This repository is an interim working version of a governance-controlled wallet contract.

## Current status

The smart contract currently includes:

- admin creation and removal with multi-admin approval
- a governance-style approval threshold based on admin count
- a single-value transfer flow
- a batch transfer flow with an explicit approval step
- timeout-based reset for stale pending approvals
- guard checks for duplicate approvals and invalid values

## Important note

This is not the final production version. The contract is still being refactored and cleaned up.

## Main contracts

- `src/GovernanceWallet.sol` — public governance logic and transfer execution
- `src/AdminLogic.sol` — shared admin state and approval logic

## Planned cleanup

- merge repeated validation patterns into shared helpers
- tighten naming and error conventions
- add comprehensive tests for admin approval flows and transfers
- finalize security review and production-ready docs

## Build

```bash
forge build
```

## Test

```bash
forge test
```
