# Entry Point Map

> Resupply | 319 entry points | 84 permissionless | 110 role-gated | 118 admin-only | 7 initializers

---

## Protocol Flow Paths

### User / borrower

1. Deployment → `ResupplyPairDeployer.setCreationCode(admin-controlled)` → `addSupportedProtocol(admin-controlled)` → `deploy/deployWithDefaultConfig` → pair exists.
2. Flow 1 → `PairAdder.addPair(admin-controlled)` → `ResupplyRegistry.addPair(admin-controlled)` → `pairsByName[name] == pair` and default swappers are installed.
3. Flow 2 → `ResupplyPair.setOracle/setMaxLTV/setBorrowLimit(admin-controlled)` → configured, borrow-enabled market.
4. Flow 3 ← `borrowLimit > totalBorrow.amount` ◄── governance/borrow-ramp keeps `borrowLimit != 0`.
5. Flow 4 ← user approval of underlying/collateral ◄── ERC20 allowance.
6. Flow 5 → `ResupplyPairCore.addCollateral*` or `borrow(underlyingAmount>0)` → `_userCollateralBalance[user]` increases.
7. Flow 6 → `ResupplyPairCore.borrow` → registry verifies calling pair → `Stablecoin.mint(receiver)` → user debt shares increase.
8. Flow 6 → `ResupplyPairCore.leveragedPosition` ← `ResupplyPair.setSwapper(admin-controlled)` → approved swapper → minted reUSD swapped to collateral.
9. Flow 7 → `ResupplyPairCore.repay` ← payer approval / self balance → `Stablecoin.burn` → debt shares decrease.
10. Flow 8 → `repayWithCollateral` ← approved swapper/path/minOut → collateral swapped and debt burned.
11. Flow 6 → `removeCollateral*` ← post-call `isSolvent(msg.sender)` → collateral shares/underlying paid out.

### Insurance depositor / reward claimant

12. Deployment → bootstrap `InsurancePool._mint(address(this),1e18)` and funding → nonzero pool accounting.
13. Flow 12 → `InsurancePool.deposit/mint` ← receiver not in `withdrawQueue` → assets in / pool shares minted.
14. Flow 13 → `InsurancePool.exit` → `withdrawQueue[user]=now+withdrawTime` ◄── time passes to unlock.
15. Flow 14 → `InsurancePool.redeem/withdraw` ← caller is `_owner` and within `withdrawTimeLimit` → shares burn / reUSD out.
16. Flow 13 → `RewardHandler.queueInsuranceRewards(role-controlled)` → reward balances arrive → permissionless `InsurancePool.getReward(account)` pays account/redirect.

### Liquidator / redeemer

17. Flow 7 ← market/oracle movement makes borrower insolvent ◄── external market state.
18. Flow 17 → `LiquidationHandler.liquidate(user-controlled)` → pair authenticates handler → debt/collateral cleared → insurance burns assets.
19. Flow 12 + Flow 18 → `processCollateral(user-controlled)` ← handler remains active in registry and burn is within `maxBurnableAssets` → collateral to insurance.
20. Flow 2 → `RedemptionHandler.updateGuardSettings(admin-controlled)` → operator-only or conditionally permissionless redemption policy.
21. Flow 20 ← depeg below threshold OR caller is configured redemption operator → `RedemptionHandler.redeem` → pair authenticates handler.
22. Flow 21 → pair reduces `totalBorrow`, transfers collateral, mints write-off weight → handler burns caller reUSD → collateral/underlying out.

### Governance / operations / emissions

23. `GovStaker.stake` → epoch checkpoint ◄── one epoch finalizes weight → `Voter.createNewProposal` → votes → delay → `executeProposal` → `Core.execute`.
24. `EmissionsController.registerReceiver(admin-controlled)` → `setReceiverWeights(admin-controlled)` → epoch passage → receiver `fetchEmissions` → allocated balance → `transferFromAllocation`.
25. Fee-generating pair calls `FeeDeposit.incrementPairRevenue(role-controlled)` → next epoch `FeeDepositController.distribute(user-controlled)` → insurance/staker/sreUSD flows.

---

## Permissionless

Entry points callable by any address with no effective caller restriction. They are ordered by token flow: token-in paths, token-out paths, then paths with no direct token movement.

### `FeeDepositController.distribute()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | — |
| Call chain | → FeeDeposit distribute → epoch allocations/logging/watch → treasury/sreUSD/RewardHandler transfers and reward queues; distribution state/value out |
| State modified | → FeeDeposit distribute → epoch allocations/logging/watch → treasury/sreUSD/RewardHandler transfers and reward queues; distribution state/value out |
| Value flow | Tokens out. |
| Reentrancy guard | N |
| Pause coverage | No global pause |

### `GovStaker.stake(address,uint256)`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any payer credits selected account |
| Parameters | `account(user-controlled)`, `amount(user-controlled)` |
| Call chain | → `_stake(account,amount)` → pending/account state → RSUP `transferFrom(msg.sender)`; value in |
| State modified | → `_stake(account,amount)` → pending/account state → RSUP `transferFrom(msg.sender)`; value in |
| Value flow | Tokens in. |
| Reentrancy guard | N |
| Pause coverage | No |

### `GovStaker.stake(uint256)`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller for self |
| Parameters | `amount(user-controlled)` |
| Call chain | → `_stake(msg.sender,amount)` → pending/account/total-pending state → RSUP `transferFrom`; value in |
| State modified | → `_stake(msg.sender,amount)` → pending/account/total-pending state → RSUP `transferFrom`; value in |
| Value flow | Tokens in. |
| Reentrancy guard | N |
| Pause coverage | No |

### `InsurancePool.deposit()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | any caller; receiver must have no queued withdrawal |
| Parameters | `assets(user-controlled)`, `receiver(user-controlled)` |
| Call chain | → reward checkpoint/ERC4626 deposit → shares mint, reUSD transfer in |
| State modified | → reward checkpoint/ERC4626 deposit → shares mint, reUSD transfer in |
| Value flow | Token supply/value changes as described above. |
| Reentrancy guard | Y |
| Pause coverage | Withdrawal pause does not stop deposits |

### `LinearRewardsErc4626.deposit()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any depositor |
| Parameters | _assets(user-controlled), _receiver(user-controlled) |
| Call chain | → sync rewards → ERC4626 deposit → asset `transferFrom`/share mint; `storedTotalAssets` and supply/balances, value in |
| State modified | → sync rewards → ERC4626 deposit → asset `transferFrom`/share mint; `storedTotalAssets` and supply/balances, value in |
| Value flow | Tokens in. |
| Reentrancy guard | N |
| Pause coverage | No |

### `LinearRewardsErc4626.depositWithSignature()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | signer deposits own assets |
| Parameters | _assets(user-controlled), _receiver(user-controlled), _deadline(user-signed), _approveMax(user-signed), _v(user-signed), _r(user-signed), _s(user-signed) |
| Call chain | → asset `permit` → `deposit` → sync rewards/ERC4626 transferFrom/share mint; value in |
| State modified | → asset `permit` → `deposit` → sync rewards/ERC4626 transferFrom/share mint; value in |
| Value flow | Tokens in. |
| Reentrancy guard | N |
| Pause coverage | No |

### `LinearRewardsErc4626.mint()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any depositor |
| Parameters | _shares(user-controlled), _receiver(user-controlled) |
| Call chain | → sync rewards → ERC4626 mint → asset `transferFrom`/share mint; `storedTotalAssets` and supply/balances, value in |
| State modified | → sync rewards → ERC4626 mint → asset `transferFrom`/share mint; `storedTotalAssets` and supply/balances, value in |
| Value flow | Tokens in. |
| Reentrancy guard | N |
| Pause coverage | No |

### `ResupplyPair.withdrawFees()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | any caller after fee epoch synchronization |
| Parameters | — |
| Call chain | → `_addInterest` → Registry `mint(feeDeposit,fees)` → FeeDeposit `incrementPairRevenue`; clears `claimableFees/claimableOtherFees`, writes `lastFeeEpoch`; reUSD minted to fee deposit |
| State modified | → `_addInterest` → Registry `mint(feeDeposit,fees)` → FeeDeposit `incrementPairRevenue`; clears `claimableFees/claimableOtherFees`, writes `lastFeeEpoch`; reUSD minted to fee deposit |
| Value flow | Token supply/value changes as described above. |
| Reentrancy guard | Y |
| Pause coverage | Pair borrow pause does not block fee withdrawal |

### `ResupplyPairCore.addCollateral()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | any payer may credit a borrower |
| Parameters | _amount(user-controlled), _borrower(user-controlled) |
| Call chain | → underlying `transferFrom` → ERC4626 `deposit` → `_addCollateral`/stake; collateral state, value in |
| State modified | → underlying `transferFrom` → ERC4626 `deposit` → `_addCollateral`/stake; collateral state, value in |
| Value flow | Tokens in. |
| Reentrancy guard | Y |
| Pause coverage | Pair borrow pause does not block |

### `ResupplyPairCore.addCollateralVault()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | any payer may credit a borrower |
| Parameters | _collateralAmount(user-controlled), _borrower(user-controlled) |
| Call chain | → `_addInterest` → `_addCollateral` → collateral `transferFrom` → underlying staking; collateral balance increases, value in |
| State modified | → `_addInterest` → `_addCollateral` → collateral `transferFrom` → underlying staking; collateral balance increases, value in |
| Value flow | Tokens in. |
| Reentrancy guard | Y |
| Pause coverage | Pair borrow pause does not block |

### `ResupplyPairCore.borrow()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | borrower for self; post-call solvency enforced |
| Parameters | _borrowAmount(user-controlled), _underlyingAmount(user-controlled), _receiver(user-controlled) |
| Call chain | → `_addInterest` → oracle update → optional underlying `transferFrom`/ERC4626 deposit → `_borrow` → Registry `mint`; collateral/debt/fee state; underlying in and reUSD out |
| State modified | → `_addInterest` → oracle update → optional underlying `transferFrom`/ERC4626 deposit → `_borrow` → Registry `mint`; collateral/debt/fee state; underlying in and reUSD out |
| Value flow | Tokens in. |
| Reentrancy guard | Y |
| Pause coverage | `borrowLimit=0` blocks positive borrowing |

### `ResupplyPairCore.leveragedPosition()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | borrower for self; approved swapper and post-call solvency required |
| Parameters | _swapperAddress(user-controlled), _borrowAmount(user-controlled), _initialUnderlyingAmount(user-controlled), _amountCollateralOutMin(user-controlled), _path(user-controlled) |
| Call chain | → optional underlying deposit → `_borrow` → approved Swapper `swap` → `_addCollateral`; debt/collateral state, underlying in/reUSD and collateral through swap |
| State modified | → optional underlying deposit → `_borrow` → approved Swapper `swap` → `_addCollateral`; debt/collateral state, underlying in/reUSD and collateral through swap |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | Y |
| Pause coverage | `borrowLimit=0` blocks the borrow leg |

### `RetentionIncentives.donate()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | `amount(user-controlled)` |
| Call chain | → queued-reward state → reward token `transferFrom`; value in |
| State modified | → queued-reward state → reward token `transferFrom`; value in |
| Value flow | Tokens in. |
| Reentrancy guard | N |
| Pause coverage | No |

### `RetentionReceiver.claimEmissions()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller, once per epoch |
| Parameters | — |
| Call chain | → fetch/transfer allocation + treasury `GOV.transferFrom` → rewards `queueNewRewards` → leftovers treasury; writes `lastEpoch,distributedRewards`; value in/out |
| State modified | → fetch/transfer allocation + treasury `GOV.transferFrom` → rewards `queueNewRewards` → leftovers treasury; writes `lastEpoch,distributedRewards`; value in/out |
| Value flow | Tokens enter and leave along the chain shown above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `RouterSwapper.swap()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | any caller while approvals not revoked |
| Parameters | `tokenIn(user-controlled)`, `tokenOut(user-controlled)`, `amountIn(user-controlled)`, `minOut(user-controlled)`, `to(user-controlled)`, `data(user-controlled)` |
| Call chain | → fixed router low-level call with caller payload → output transfer; value in/out |
| State modified | → fixed router low-level call with caller payload → output transfer; value in/out |
| Value flow | Tokens enter and leave along the chain shown above. |
| Reentrancy guard | Y |
| Pause coverage | `approvalsRevoked` explicitly disables swaps |

### `SimpleRewardStreamer.donate()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | `amount(user-controlled)` |
| Call chain | → queued rewards/rate state → token `transferFrom`; value in |
| State modified | → queued rewards/rate state → token `transferFrom`; value in |
| Value flow | Tokens in. |
| Reentrancy guard | N |
| Pause coverage | No |

### `Swapper.swap()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller for existing route; undefined vault route can be installed only when caller is a registered pair |
| Parameters | `tokenIn(user-controlled)`, `tokenOut(user-controlled)`, `amountIn(user-controlled)`, `minOut(user-controlled)`, `to(user-controlled)` |
| Call chain | → ERC4626/Curve route → token transfers to `to`; route may be added; value in/out |
| State modified | → ERC4626/Curve route → token transfers to `to`; route may be added; value in/out |
| Value flow | Tokens enter and leave along the chain shown above. |
| Reentrancy guard | N |
| Pause coverage | No global pause |

### `VestManager.redeem()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any token holder |
| Parameters | `_token(user-controlled)`, `_recipient(user-controlled)`, `_amount(user-controlled)` |
| Call chain | → approved legacy token `transferFrom` to burn address → `_createVest`; legacy value in/future RSUP out |
| State modified | → approved legacy token `transferFrom` to burn address → `_createVest`; legacy value in/future RSUP out |
| Value flow | Tokens in. |
| Reentrancy guard | N |
| Pause coverage | No |

### `CurveLendOperator.reduceAmount()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | any caller when `mintedAmount>mintLimit` |
| Parameters | `_amount(user-controlled)` |
| Call chain | → ERC4626 `withdraw(...,factory,this)` → `mintedAmount-=amount`; value to factory |
| State modified | → ERC4626 `withdraw(...,factory,this)` → `mintedAmount-=amount`; value to factory |
| Value flow | Tokens out. |
| Reentrancy guard | Y |
| Pause coverage | No |

### `CurveLendOperator.withdraw_profit()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | any caller |
| Parameters | — |
| Call chain | → `profit` → ERC4626 withdraw to factory `fee_receiver`; value out |
| State modified | → `profit` → ERC4626 withdraw to factory `fee_receiver`; value out |
| Value flow | Tokens out. |
| Reentrancy guard | Y |
| Pause coverage | No |

### `EmissionsController.transferFromAllocation()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller; debits `allocated[msg.sender]` |
| Parameters | `_recipient(user-controlled)`, `_amount(user-controlled)` |
| Call chain | → allocation amount decrement → GOV `transfer`; value out |
| State modified | → allocation amount decrement → GOV `transfer`; value out |
| Value flow | Tokens out. |
| Reentrancy guard | N |
| Pause coverage | No |

### `InsurancePool.cancelExit()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | caller cancels own queue |
| Parameters | — |
| Call chain | → clears caller withdrawal queue |
| State modified | → clears caller withdrawal queue |
| Value flow | Tokens out. |
| Reentrancy guard | Y |
| Pause coverage | No |

### `InsurancePool.getReward(address)`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | any caller; account must not be queued, payout belongs to account/redirect |
| Parameters | `account(user-controlled)` |
| Call chain | → inherited checkpoint → reward transfers |
| State modified | → inherited checkpoint → reward transfers |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | Y |
| Pause coverage | Withdrawal pause does not stop claims |

### `InsurancePool.mint()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | any caller; receiver must have no queued withdrawal |
| Parameters | `shares(user-controlled)`, `receiver(user-controlled)` |
| Call chain | → reward checkpoint/ERC4626 mint → shares mint, reUSD transfer in |
| State modified | → reward checkpoint/ERC4626 mint → shares mint, reUSD transfer in |
| Value flow | Token supply/value changes as described above. |
| Reentrancy guard | Y |
| Pause coverage | Withdrawal pause does not stop deposits |

### `Keeper.work()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | — |
| Call chain | → fee controller distribute → sreUSD sync → pair withdrawFees → retention claim → Curve operators withdraw_profit; downstream state/value |
| State modified | → fee controller distribute → sreUSD sync → pair withdrawFees → retention claim → Curve operators withdraw_profit; downstream state/value |
| Value flow | Tokens out. |
| Reentrancy guard | N |
| Pause coverage | Honors each callee's local gates only |

### `KeeperV1.work()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | — |
| Call chain | → fee distribute → pair withdrawFees → retention claim; downstream state/value |
| State modified | → fee distribute → pair withdrawFees → retention claim; downstream state/value |
| Value flow | Tokens out. |
| Reentrancy guard | N |
| Pause coverage | Honors callee gates |

### `KeeperV2.work()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | — |
| Call chain | → fee distribute → pair withdrawFees → retention claim; downstream state/value |
| State modified | → fee distribute → pair withdrawFees → retention claim; downstream state/value |
| Value flow | Tokens out. |
| Reentrancy guard | N |
| Pause coverage | Honors callee gates |

### `LinearRewardsErc4626.redeem()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | share owner or allowance-authorized caller |
| Parameters | _shares(user-controlled), _receiver(user-controlled), _owner(user-controlled) |
| Call chain | → sync rewards → allowance spend → share burn/asset transfer; `storedTotalAssets` and supply/balances, value out |
| State modified | → sync rewards → allowance spend → share burn/asset transfer; `storedTotalAssets` and supply/balances, value out |
| Value flow | Tokens out. |
| Reentrancy guard | N |
| Pause coverage | No |

### `LinearRewardsErc4626.withdraw()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | share owner or allowance-authorized caller |
| Parameters | _assets(user-controlled), _receiver(user-controlled), _owner(user-controlled) |
| Call chain | → sync rewards → allowance spend → share burn/asset transfer; `storedTotalAssets` and supply/balances, value out |
| State modified | → sync rewards → allowance spend → share burn/asset transfer; `storedTotalAssets` and supply/balances, value out |
| Value flow | Tokens out. |
| Reentrancy guard | N |
| Pause coverage | No |

### `LiquidationHandler.processCollateral()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller while this remains active handler |
| Parameters | `vault(user-controlled)`, `shares(user-controlled)` |
| Call chain | → ERC4626 redeem → collateral distribution/IP interaction; value out |
| State modified | → ERC4626 redeem → collateral distribution/IP interaction; value out |
| Value flow | Tokens out. |
| Reentrancy guard | N |
| Pause coverage | No |

### `MultiRewardsDistributor.getOneReward()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | any caller; payout belongs to account/redirect |
| Parameters | `account(user-controlled)`, `token(user-controlled)` |
| Call chain | → checkpoint selected reward → token transfer; reward state/value out |
| State modified | → checkpoint selected reward → token transfer; reward state/value out |
| Value flow | Tokens out. |
| Reentrancy guard | Y |
| Pause coverage | No |

### `MultiRewardsDistributor.getReward()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | caller claims own rewards |
| Parameters | — |
| Call chain | → reward checkpoints → transfers reward tokens to caller/redirect |
| State modified | → reward checkpoints → transfers reward tokens to caller/redirect |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | Y |
| Pause coverage | No |

### `MultiRewardsDistributor.getReward(address)`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | any caller; payout belongs to account/redirect |
| Parameters | `account(user-controlled)` |
| Call chain | → reward checkpoints → transfers each earned token; reward state/value out |
| State modified | → reward checkpoints → transfers each earned token; reward state/value out |
| Value flow | Tokens out. |
| Reentrancy guard | Y |
| Pause coverage | No |

### `ResupplyPairCore.removeCollateral()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | borrower removes own collateral; post-call solvency enforced |
| Parameters | _collateralAmount(user-controlled), _receiver(user-controlled) |
| Call chain | → `_removeCollateral` → ERC4626 `redeem`; collateral state, underlying value out |
| State modified | → `_removeCollateral` → ERC4626 `redeem`; collateral state, underlying value out |
| Value flow | Tokens out. |
| Reentrancy guard | Y |
| Pause coverage | Pair borrow pause does not block |

### `ResupplyPairCore.removeCollateralVault()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | borrower removes own collateral; post-call solvency enforced |
| Parameters | _collateralAmount(user-controlled), _receiver(user-controlled) |
| Call chain | → interest/oracle sync → `_removeCollateral` → unstake → collateral token transfer; collateral state/value out |
| State modified | → interest/oracle sync → `_removeCollateral` → unstake → collateral token transfer; collateral state/value out |
| Value flow | Tokens out. |
| Reentrancy guard | Y |
| Pause coverage | Pair borrow pause does not block |

### `ResupplyRegistry.claimFees()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller; supplied pair must be registered |
| Parameters | `pair(user-controlled)` |
| Call chain | → pair `withdrawFees`; fee/reward accounting and value flow |
| State modified | → pair `withdrawFees`; fee/reward accounting and value flow |
| Value flow | Tokens out. |
| Reentrancy guard | N |
| Pause coverage | Pair pause does not block fee withdrawal |

### `RetentionIncentives.getReward()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | caller claims own reward |
| Parameters | — |
| Call chain | → checkpoints → reward token transfer to caller/redirect |
| State modified | → checkpoints → reward token transfer to caller/redirect |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `RetentionIncentives.getReward(address)`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller; payout belongs to account/redirect |
| Parameters | `account(user-controlled)` |
| Call chain | → checkpoints → reward transfer |
| State modified | → checkpoints → reward transfer |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `RewardDistributorMultiEpoch.getReward(address)`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | any caller; payout belongs to account/redirect |
| Parameters | `account(user-controlled)` |
| Call chain | → checkpoints → valid reward-token transfers |
| State modified | → checkpoints → valid reward-token transfers |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | Y |
| Pause coverage | No |

### `SimpleRewardStreamer.getReward()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | caller claims own rewards |
| Parameters | — |
| Call chain | → checkpoint → reward transfer |
| State modified | → checkpoint → reward transfer |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `SimpleRewardStreamer.getReward(address)`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller; payout belongs to account/redirect |
| Parameters | `account(user-controlled)` |
| Call chain | → checkpoint → reward transfer |
| State modified | → checkpoint → reward transfer |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `BorrowLimitController.updatePairBorrowLimit()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | `_pair(user-controlled)` |
| Call chain | → reads ramp/pair → computes time interpolation → Core `execute(pair,setBorrowLimit)`; pair borrowLimit state |
| State modified | → reads ramp/pair → computes time interpolation → Core `execute(pair,setBorrowLimit)`; pair borrowLimit state |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | Ramp cannot update a paused pair (`borrowLimit==0`) |

### `DelegatedOps.setDelegateApproval()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any account manages its own delegate map |
| Parameters | `_delegate(user-controlled)`, `_isApproved(user-controlled)` |
| Call chain | → `isApprovedDelegate[msg.sender][_delegate]=...`; none |
| State modified | → `isApprovedDelegate[msg.sender][_delegate]=...`; none |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `GovStaker.checkpointAccount()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | `account(user-controlled)` |
| Call chain | → reward/account checkpoints → pending stake realization and weight state |
| State modified | → reward/account checkpoints → pending stake realization and weight state |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `GovStaker.checkpointAccountLimit()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | `account(user-controlled)`, `limit(user-controlled)` |
| Call chain | → bounded checkpoint loop → account/reward state |
| State modified | → bounded checkpoint loop → account/reward state |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `GovStaker.checkpointTotal()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | `limit(user-controlled)` |
| Call chain | → bounded global checkpoint loop → total-weight state |
| State modified | → bounded global checkpoint loop → total-weight state |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `GovStaker.migrateStake()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | caller migrates only own stake; requires permanent status and zero cooldown epochs |
| Parameters | — |
| Call chain | → checkpoints/unstake/reward claim → registry new staker `stake(msg.sender,amount)` + hook; RSUP/rewards out and restaked |
| State modified | → checkpoints/unstake/reward claim → registry new staker `stake(msg.sender,amount)` + hook; RSUP/rewards out and restaked |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | Enabled only by cooldown configuration |

### `GovStaker.onPermaStakeMigrate()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller; empty hook |
| Parameters | `account(user-controlled)`, `amount(user-controlled)` |
| Call chain | → no state/call/value |
| State modified | → no state/call/value |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `InsurancePool.earned()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | any caller |
| Parameters | `account(user-controlled)` |
| Call chain | → inherited checkpoint calculations/state → earned amounts |
| State modified | → inherited checkpoint calculations/state → earned amounts |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | Y |
| Pause coverage | No |

### `InsurancePool.exit()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | caller exits own account |
| Parameters | — |
| Call chain | → reward claim → queues full share balance and records unlock time |
| State modified | → reward claim → queues full share balance and records unlock time |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | Y (delegated/inherited guards) |
| Pause coverage | Guardian timer pause affects later redemption, not queueing |

### `LinearRewardsErc4626.syncRewardsAndDistribution()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | — |
| Call chain | → `_distributeRewards` → `_syncRewards`; `storedTotalAssets/rewardsCycleData`, fee/reward value distribution |
| State modified | → `_distributeRewards` → `_syncRewards`; `storedTotalAssets/rewardsCycleData`, fee/reward value distribution |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `LiquidationHandler.liquidate()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | `pair(user-controlled)`, `borrower(user-controlled)`, `collateralForLiquidator(user-controlled)` |
| Call chain | → transient caller record → pair `liquidate` → handler callback/debt settlement; collateral/reUSD value flow |
| State modified | → transient caller record → pair `liquidate` → handler callback/debt settlement; collateral/reUSD value flow |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | Pair borrow pause does not block liquidation |

### `MultiRewardsDistributor.setRewardRedirect()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | caller controls own redirect |
| Parameters | `to(user-controlled)` |
| Call chain | → `rewardRedirect[msg.sender]` SSTORE |
| State modified | → `rewardRedirect[msg.sender]` SSTORE |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | Y |
| Pause coverage | No |

### `PriceWatcher.recordPrice()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | — |
| Call chain | → reads oracle → observation/running-price SSTORE |
| State modified | → reads oracle → observation/running-price SSTORE |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `RedemptionOperator.approveRH()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | — |
| Call chain | → reUSD `forceApprove(current redemptionHandler,max)`; approval state |
| State modified | → reUSD `forceApprove(current redemptionHandler,max)`; approval state |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `RedemptionOperator.setApprovals()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | — |
| Call chain | → fixed token `forceApprove` calls + current RH approval; approval state |
| State modified | → fixed token `forceApprove` calls + current RH approval; approval state |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `ResupplyPair.getUserSnapshot()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | any caller |
| Parameters | _address(user-controlled) |
| Call chain | → `userCollateralBalance(_address)` → redemption/reward checkpoint; returns borrow shares and collateral balance; downstream user/reward state |
| State modified | → `userCollateralBalance(_address)` → redemption/reward checkpoint; returns borrow shares and collateral balance; downstream user/reward state |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | Y |
| Pause coverage | No |

### `ResupplyPairCore.earned()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | any caller |
| Parameters | _account(user-controlled) |
| Call chain | → inherited reward checkpoint/earned computation → removes write-off token from returned list; reward state |
| State modified | → inherited reward checkpoint/earned computation → removes write-off token from returned list; reward state |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | Y |
| Pause coverage | No |

### `ResupplyPairCore.repay()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | any payer may repay a borrower |
| Parameters | _shares(user-controlled), _borrower(user-controlled) |
| Call chain | → `_addInterest` → debt-share calculation → `_repay` → Stablecoin `burn(msg.sender)`; debt state decreases, reUSD burned |
| State modified | → `_addInterest` → debt-share calculation → `_repay` → Stablecoin `burn(msg.sender)`; debt state decreases, reUSD burned |
| Value flow | Token supply/value changes as described above. |
| Reentrancy guard | Y |
| Pause coverage | Pair borrow pause does not block |

### `ResupplyPairCore.repayWithCollateral()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | borrower for self; approved swapper and post-call solvency required |
| Parameters | _swapperAddress(user-controlled), _collateralToSwap(user-controlled), _amountOutMin(user-controlled), _path(user-controlled) |
| Call chain | → `_removeCollateral` to swapper → Swapper `swap` → `_repay`/Stablecoin burn; collateral/debt state, collateral out and reUSD burned |
| State modified | → `_removeCollateral` to swapper → Swapper `swap` → `_repay`/Stablecoin burn; collateral/debt state, collateral out and reUSD burned |
| Value flow | Token supply/value changes as described above. |
| Reentrancy guard | Y |
| Pause coverage | Pair borrow pause does not block |

### `ResupplyPairCore.userCollateralBalance()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | any caller |
| Parameters | _account(user-controlled) |
| Call chain | → `_syncUserRedemptions` → reward/write-off checkpoints → reads/clamps collateral; user epoch/collateral accounting state |
| State modified | → `_syncUserRedemptions` → reward/write-off checkpoints → reads/clamps collateral; user epoch/collateral accounting state |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | Y |
| Pause coverage | No |

### `ResupplyRegistry.claimInsuranceRewards()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | `account(user-controlled)` |
| Call chain | → RewardHandler → InsurancePool claim; rewards to account/redirect |
| State modified | → RewardHandler → InsurancePool claim; rewards to account/redirect |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | IP withdrawal pause does not stop rewards |

### `ResupplyRegistry.claimRewards()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | `account(user-controlled)`, `pairs(user-controlled)` |
| Call chain | → RewardHandler `claimRewards`; rewards to account/redirect |
| State modified | → RewardHandler `claimRewards`; rewards to account/redirect |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `RetentionIncentives.checkpoint_multiple()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | `accounts(user-controlled)` |
| Call chain | → global/user reward-integral and balance checkpoints |
| State modified | → global/user reward-integral and balance checkpoints |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `RetentionIncentives.setAddressBalances()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller before one-time finalization |
| Parameters | `accounts(user-controlled)`, `amounts(user-controlled)` |
| Call chain | → original/current balances and total-supply writes; `isFinalized=true` |
| State modified | → original/current balances and total-supply writes; `isFinalized=true` |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | Finalization permanently closes setup |

### `RetentionIncentives.setRewardRedirect()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | caller controls own redirect |
| Parameters | `to(user-controlled)` |
| Call chain | → redirect SSTORE |
| State modified | → redirect SSTORE |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `RetentionIncentives.user_checkpoint()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | `account(user-controlled)` |
| Call chain | → reward/account checkpoint state |
| State modified | → reward/account checkpoint state |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `RetentionReceiver.allocateEmissions()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | — |
| Call chain | → controller `fetchEmissions`; controller allocation state |
| State modified | → controller `fetchEmissions`; controller allocation state |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `RewardDistributorMultiEpoch.earned()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | any caller |
| Parameters | `account(user-controlled)` |
| Call chain | → checkpoints then returns earned amounts; state modified |
| State modified | → checkpoints then returns earned amounts; state modified |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | Y |
| Pause coverage | No |

### `RewardDistributorMultiEpoch.setRewardRedirect()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | caller controls own redirect |
| Parameters | `to(user-controlled)` |
| Call chain | → redirect SSTORE |
| State modified | → redirect SSTORE |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | Y |
| Pause coverage | No |

### `RewardDistributorMultiEpoch.user_checkpoint()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external, nonReentrant |
| Caller | any caller |
| Parameters | `account(user-controlled)` |
| Call chain | → multi-epoch reward checkpoint state |
| State modified | → multi-epoch reward checkpoint state |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | Y |
| Pause coverage | No |

### `RewardHandler.checkNewRewards()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | `pair(user-controlled)` |
| Call chain | → registered reward sources → pair reward state/checkpoints |
| State modified | → registered reward sources → pair reward state/checkpoints |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `RewardHandler.claimInsuranceRewards()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | `account(user-controlled)` |
| Call chain | → InsurancePool `getReward(account)`; rewards paid to account/redirect |
| State modified | → InsurancePool `getReward(account)`; rewards paid to account/redirect |
| Value flow | Tokens out. |
| Reentrancy guard | N |
| Pause coverage | IP withdrawal pause does not stop reward claims |

### `RewardHandler.claimRewards()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | `account(user-controlled)`, `pairs(user-controlled)` |
| Call chain | → pair reward distributors `getReward(account)`; rewards paid to account/redirect |
| State modified | → pair reward distributors `getReward(account)`; rewards paid to account/redirect |
| Value flow | Tokens out. |
| Reentrancy guard | N |
| Pause coverage | No |

### `RouterSwapper.updateApprovals()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | `tokens(user-controlled)` |
| Call chain | → fixed router allowances set to max |
| State modified | → fixed router allowances set to max |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | Cannot restore after permanent revocation |

### `SimpleReceiver.allocateEmissions()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | — |
| Call chain | → controller `fetchEmissions` → mint/allocate; controller allocation state; value allocated |
| State modified | → controller `fetchEmissions` → mint/allocate; controller allocation state; value allocated |
| Value flow | Token supply/value changes as described above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `SimpleRewardStreamer.setRewardRedirect()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | caller controls own redirect |
| Parameters | `to(user-controlled)` |
| Call chain | → redirect SSTORE |
| State modified | → redirect SSTORE |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `SimpleRewardStreamer.user_checkpoint()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | `account(user-controlled)` |
| Call chain | → reward/account checkpoint state |
| State modified | → reward/account checkpoint state |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `Stablecoin.burn()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | self burn or allowance-authenticated burn from another account |
| Parameters | `from(user-controlled)`, `amount(user-controlled)` |
| Call chain | → allowance spend when needed → `_burn`; reUSD supply/value destroyed |
| State modified | → allowance spend when needed → `_burn`; reUSD supply/value destroyed |
| Value flow | Token supply/value changes as described above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `Utilities.isSolvent()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | `pair(user-controlled)`, `account(user-controlled)` |
| Call chain | → pair `userCollateralBalance` reward/write-off checkpoint → solvency calculation; downstream state modified |
| State modified | → pair `userCollateralBalance` reward/write-off checkpoint → solvency calculation; downstream state modified |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `Utilities.isSolventAfterLeverage()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller |
| Parameters | `pair(user-controlled)`, `account(user-controlled)`, `additionalDebt(user-controlled)`, `additionalCollateral(user-controlled)` |
| Call chain | → pair collateral checkpoint → hypothetical solvency calculation; downstream state modified |
| State modified | → pair collateral checkpoint → hypothetical solvency calculation; downstream state modified |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `VestManagerBase.setClaimSettings()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | account controls only its own settings |
| Parameters | `_allowPermissionlessClaims(user-controlled)`, `_recipient(user-controlled)` |
| Call chain | → `claimSettings[msg.sender]=...`; none |
| State modified | → `claimSettings[msg.sender]=...`; none |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `Voter.executeProposal()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any caller after voting period+delay, before deadline, quorum/yes checks |
| Parameters | `id(user-controlled)` |
| Call chain | → marks processed → for each action `Core.execute(target,data)` → arbitrary approved governance leaf; value possible |
| State modified | → marks processed → for each action `Core.execute(target,data)` → arbitrary approved governance leaf; value possible |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

### `WriteOffToken.transfer()`

| Aspect | Detail |
|--------|--------|
| Visibility | public/external |
| Caller | any holder; implementation is a no-op returning true |
| Parameters | `to(user-controlled)`, `amount(user-controlled)` |
| Call chain | → no state/value movement |
| State modified | → no state/value movement |
| Value flow | None directly, unless stated in the chain above. |
| Reentrancy guard | N |
| Pause coverage | No |

---

## Role-Gated

Restricted by an effective modifier, direct caller check, or delegated/internal caller check. Compact tables are used because this surface exceeds 30 functions.

### Account or Approved Delegate

| Contract / function | Required caller | Parameters | Downstream chain, state, and value | NR | Pause coverage |
|---|---|---|---|---|---|
| `GovStaker.cooldown()` | exact `account` or its approved delegate | `account(user-controlled / role-controlled)`, `amount(user-controlled / role-controlled)` | → checkpoints → realizes pending stake → share/cooldown state → RSUP to escrow; value held in escrow | N | No protocol pause; `cooldownEpochs` is admin-configured |
| `GovStaker.exit()` | exact `account` or approved delegate | `account(user-controlled / role-controlled)` | → full cooldown + inherited reward claim → escrow/reward token transfers; stake/reward state | Y | No |
| `GovStaker.irreversiblyCommitAccountAsPermanentStaker()` | exact `account` or approved delegate | `account(user-controlled / role-controlled)` | → `isPermaStaker[account]=true`; irreversible account state | N | No |
| `GovStaker.unstake()` | exact `account` or approved delegate, after cooldown | `account(user-controlled / role-controlled)`, `receiver(user-controlled / role-controlled)` | → clears cooldown → escrow `withdraw(receiver,amount)`; RSUP out | N | No |
| `InsurancePool.getReward(address,address)` | exact `account`, and account not queued | `account(user-controlled; must equal caller)`, `forwardTo(user-controlled)` | → inherited checkpoint → reward transfer to chosen address | Y | Withdrawal pause does not stop claims |
| `InsurancePool.redeem()` | exact `_owner == msg.sender`, valid withdrawal window | `shares(user-controlled)`, `receiver(user-controlled)`, `_owner(user-controlled; must equal caller)` | → clears/reduces queue → burns shares → reUSD transfer to receiver | Y | `withdrawTimeLimit=0` makes ordinary window effectively unusable |
| `InsurancePool.withdraw()` | exact `_owner == msg.sender`, valid withdrawal window | `assets(user-controlled)`, `receiver(user-controlled)`, `_owner(user-controlled; must equal caller)` | → clears/reduces queue → burns shares → reUSD transfer to receiver | Y | Covered by withdrawal-timer pause |
| `PermaStaker.safeExecute()` | delegated OZ owner or `operator` | `target(role-controlled)`, `data(role-controlled)` | → `target.call`, requires success; arbitrary downstream/value | N | No |
| `RetentionIncentives.getReward(address,address)` | exact `account` may select forwarding address | `account(user-controlled / role-controlled)`, `forwardTo(user-controlled / role-controlled)` | → checkpoints → reward transfer to chosen address | N | No |
| `RewardDistributorMultiEpoch.getReward(address,address)` | exact `account` may select forwarding address | `account(user-controlled / role-controlled)`, `forwardTo(user-controlled / role-controlled)` | → checkpoints → rewards to chosen address | Y | No |
| `SimpleRewardStreamer.getReward(address,address)` | exact `account` may select forwarding address | `account(user-controlled / role-controlled)`, `forwardTo(user-controlled / role-controlled)` | → checkpoint → reward transfer to selected address | N | No |
| `VestManager.merkleClaim()` | account/self delegate plus Merkle proof | `_account(user-controlled)`, `_recipient(user-controlled)`, `_amount(protocol-derived)`, `_type(protocol-derived)`, `_proof(user-signed)`, `_index(protocol-derived)` | → proof verify → `_createVest` → `hasClaimed=true`; future value claim | N | No |
| `VestManagerBase.claim()` | Role-Gated (conditional) — `_account` itself unless its stored settings opted into permissionless claims | `_account(user-controlled)` | → `_enforceClaimSettings` → `_claim` writes vest.claimed → token transfer to account/redirect; value out | N | No |
| `VestManagerBase.claimWithCallback()` | account/self delegate | `_account(user-controlled)`, `_callback(user-controlled)` | → `_claim` → token transfer callback → callback `onClaim`; vest claimed state/value out | N | No |
| `Voter.createNewProposal()` | `account` itself or `isApprovedDelegate[account][msg.sender]`, with minimum stake weight | `account(user-controlled)`, `payload(user-controlled)`, `description(user-controlled)` | → staker weight reads → pushes proposal/payload/description and timestamp; none | N | No |
| `Voter.voteForProposal(address,uint256,uint256,uint256)` | account/self delegate | `account(user-controlled)`, `id(user-controlled)`, `pctYes(user-controlled)`, `pctNo(user-controlled)` | → `_voteForProposal` → writes vote/results; none | N | No |
| `Voter.voteForProposal(address,uint256)` | account/self delegate | `account(user-controlled)`, `id(user-controlled)` | → `_voteForProposal` → writes account vote and proposal results; none | N | No |

### Authenticated Protocol Contracts

| Contract / function | Required caller | Parameters | Downstream chain, state, and value | NR | Pause coverage |
|---|---|---|---|---|---|
| `AutoStakeCallback.onClaim()` | exact immutable `vestManager` | `recipient(protocol-derived)`, `amount(protocol-derived)` | → `GovStaker.stake(recipient,amount)`; stake accounting; RSUP into staker | N | No |
| `FeeDeposit.incrementPairRevenue()` | caller must be registry-listed pair | `amount(protocol-derived)` | → RewardHandler `setPairWeight(msg.sender,amount)`; pair weight state | N | No |
| `GovStakerEscrow.withdraw()` | exact immutable `staker` | `receiver(protocol-derived)`, `amount(protocol-derived)` | → RSUP transfer; value out | N | No |
| `InsurancePool.burnAssets()` | exact registry liquidation handler | `amount(protocol-derived)` | → reward epoch/accounting refactor → asset burn; reUSD value destroyed | N | Withdrawal pause does not apply |
| `LiquidationHandler.migrateInsurancePool()` | exact newly registered handler; old handler must be inactive | — | → old/new IP approvals/state handoff | N | No |
| `LiquidationHandler.processDebt()` | caller is registry pair or configured L2 manager | `debtAmount(protocol-derived)`, `collateralAmount(protocol-derived)`, `liquidator(protocol-derived)` | → accounting/transfers → InsurancePool burn/settlement; debt and collateral value flow | N | No |
| `RedemptionOperator.onFlashLoan()` | exact CRVUSD lender, initiator=this, token=CRVUSD | `initiator(protocol-derived; authenticated callback)`, `token(protocol-derived; authenticated callback)`, `amount(protocol-derived; authenticated callback)`, `fee(protocol-derived; authenticated callback)`, `data(protocol-derived; authenticated callback)` | → `_handleFlashCallback` → swaps/redeem/repay/profit; value in/out | N (entered under guarded initiator transaction) | RH guard applies |
| `RedemptionOperator.onFraxLoan()` | exact FRXUSD lender, asset=FRXUSD | `asset(protocol-derived; authenticated callback)`, `amount(protocol-derived; authenticated callback)`, `data(protocol-derived; authenticated callback)` | → fee calc → callback handler → swaps/redeem/repay/profit; value in/out | N (entered under guarded initiator transaction) | RH guard applies |
| `ResupplyPairCore.liquidate()` | exact registry liquidation handler | _borrower(protocol-derived) | → interest/oracle/solvency sync → clears borrower debt/collateral → handler `processDebt` → collateral transfer/insurance settlement | Y | Pair borrow pause does not block liquidation |
| `ResupplyPairCore.redeemCollateral()` | exact registry redemption handler | _caller(protocol-derived), _amount(protocol-derived), _totalFeePct(protocol-derived), _receiver(protocol-derived) | → debt/fee/share-refactor state → oracle update/unstake → collateral transfer → WriteOffToken `mint`; collateral out | Y | Pair borrow pause does not block redemption |
| `ResupplyRegistry.mint()` | caller must be registered pair | `to(protocol-derived)`, `amount(protocol-derived)` | → Stablecoin `mint(to,amount)`; reUSD supply/value out | N | Pair borrowLimit pause indirectly blocks ordinary borrow minting, not this gate itself |

### Governance and Voter Roles

| Contract / function | Required caller | Parameters | Downstream chain, state, and value | NR | Pause coverage |
|---|---|---|---|---|---|
| `SimpleReceiver.claimEmissions()` | Core admin or `approvedClaimers[msg.sender]` | `receiver(role-controlled)` | → fetch → read allocation → controller `transferFromAllocation` → GOV transfer; value out | N | No |

### Guardian

| Contract / function | Required caller | Parameters | Downstream chain, state, and value | NR | Pause coverage |
|---|---|---|---|---|---|
| `Guardian.cancelProposal()` | exact `guardian` | `proposalId(role-controlled)` | → registry voter → Core → Voter `cancelProposal`; proposal processed | N | No |
| `Guardian.pauseAllPairs()` | exact `guardian` | — | → registry pairs → Core → each pair `pause`; sets borrow limits to zero | N | This is the pair pause entry |
| `Guardian.pausePair()` | exact `guardian` | `pair(role-controlled)` | → Core → pair `pause`; sets borrow limit zero | N | This is the pair pause entry |
| `Guardian.recoverERC20()` | exact `guardian` | `token(role-controlled)` | → token transfer all to guardian; value out | N | No |
| `Guardian.revertVoter()` | exact `guardian` and Core permission must exist | — | → Core → Core `setVoter(guardian)`; voter state | N | No |
| `Guardian.setRegistryAddress()` | exact `guardian` plus Core permission | `_key(role-controlled)`, `_address(role-controlled)` | → Core → Registry `setAddress`; registry state | N | No |
| `Guardian.updateProposalDescription()` | exact `guardian` | `proposalId(role-controlled)`, `newDescription(role-controlled)` | → Core → Voter setter; description state | N | No |
| `GuardianUpgradeable.cancelProposal()` | exact `guardian` | `proposalId(role-controlled)` | → Core → Voter cancel; state | N | No |
| `GuardianUpgradeable.cancelRamp()` | exact `guardian` | `_pair(role-controlled)` | → Core → BorrowLimitController `cancelRamp`; ramp cleared | N | No |
| `GuardianUpgradeable.pauseAllPairs()` | exact `guardian` | — | → registry pairs → Core → pair pause | N | Pair borrow pause only |
| `GuardianUpgradeable.pauseIPWithdrawals()` | exact `guardian` | — | → Core → InsurancePool `setWithdrawTimers(current,0)`; withdraw window zero | N | IP withdrawals practically require exact unlock timestamp |
| `GuardianUpgradeable.pausePair()` | exact `guardian` | `pair(role-controlled)` | → Core → pair pause | N | Pair borrow pause only |
| `GuardianUpgradeable.recoverERC20()` | exact `guardian` | `token(role-controlled)` | → token transfer all to guardian; value out | N | No |
| `GuardianUpgradeable.revokeSwapperApprovals()` | exact `guardian` | `key(role-controlled)` | → registry swapper → Core → RouterSwapper `revokeApprovals`; approvals revoked | N | Disables RouterSwapper swaps |
| `GuardianUpgradeable.setRegistryAddress()` | exact `guardian`; key must not be guarded | `_key(role-controlled)`, `_address(role-controlled)` | → Core → Registry setAddress; state | N | No |
| `GuardianUpgradeable.updateProposalDescription()` | exact `guardian` | `proposalId(role-controlled)`, `newDescription(role-controlled)` | → Core → Voter update; state | N | No |
| `GuardianUpgradeable.updateRedemptionGuardSettings()` | exact `guardian` | `guardEnabled(role-controlled)`, `priceThreshold(role-controlled)` | → Core → RedemptionHandler `updateGuardSettings`; guard state | N | Controls conditional redemption gate |

### Managers, Operators, and Approved Deployers

| Contract / function | Required caller | Parameters | Downstream chain, state, and value | NR | Pause coverage |
|---|---|---|---|---|---|
| `Core.execute()` | exact `voter` or caller+target/selector authorized in `operatorPermissions` (optional hook) | `target(role-controlled)`, `data(role-controlled)` | → preHook → `target.functionCall(data)` → postHook; arbitrary downstream state/value | Y | No global pause |
| `CurveLendMinterFactory.borrow()` | exact `markets[_market]` operator | `_market(role-controlled)`, `_amount(role-controlled)` | → CRVUSD `safeTransfer(msg.sender,amount)`; value out | N | Removing mapping blocks it |
| `FeeDeposit.distributeFees()` | exact configured `operator` | — | → epoch check/`lastDistributedEpoch` → entire fee-token balance transferred to operator | N | No |
| `FeeLogger.logTotalFeeDistribution()` | exact FeeDeposit operator or Core owner | `epoch(role-controlled)`, `amount(role-controlled)` | → total-fee log SSTORE/event | N | No |
| `PermaStaker.claimAndStake()` | OZ owner or `operator` | — | → vest manager `claim(this)` → GovStaker `stake(this,amount)`; vest value into stake | N | No |
| `PermaStaker.execute()` | internal `_execute` enforces OZ owner or `operator` | `target(role-controlled)`, `data(role-controlled)` | → target exclusion for vest manager → `target.call`; arbitrary downstream/value | N | No |
| `PermaStaker.migrateStaker()` | OZ owner or `operator` | — | → old staker `migrateStake` → registry-selected new staker; stake value migrates | N | No |
| `RedemptionHandler.redeem()` | Role-Gated (conditional) — exact redemption operator unless guard disabled or reUSD oracle is below threshold | `pair(role-controlled / keeper-provided)`, `amount(role-controlled / keeper-provided)`, `minCollateralOut(role-controlled / keeper-provided)`, `receiver(role-controlled / keeper-provided)` | → pair `redeemCollateral` → reUSD burn → optional vault redeem → collateral to receiver; pair/redemption state and value | N | Guard is the only local coverage; pair borrow pause does not block redemption |
| `RedemptionOperator.executeRedemption()` | `approvedCallers[msg.sender]` | `bestPair(keeper-provided)`, `flashAmount(keeper-provided)`, `minReusdFromSwap(keeper-provided)`, `minProfit(keeper-provided)`, `maxFeePct(keeper-provided)` | → authenticated flash lender → callback → Curve/vault swaps → RH redeem → lender repayment → profit treasury; no persistent local accounting; value in/out | Y | Redemption guard still enforced in RH |
| `RedemptionOperator.setApprovedCaller()` | fixed CORE or exact `manager` | `_caller(role-controlled)`, `_status(role-controlled)` | → `approvedCallers` SSTORE; none | N | No |
| `RedemptionOperator.sweep()` | fixed CORE or exact `manager` | `token(role-controlled)`, `to(role-controlled)`, `amount(role-controlled)` | → ERC20 `safeTransfer`; value out | N | No |
| `ResupplyPairDeployer.deployWithDefaultConfig()` | `approvedDeployers[msg.sender]` or Core owner | _protocolId(role-controlled), _collateral(role-controlled), _underlyingStaking(role-controlled), _underlyingStakingId(role-controlled) | → `_deploy`/CREATE2 with stored defaults → burn ERC4626 shares → Core/Registry registration; deployed-pair state/value burned | N | Approval revocation blocks caller |
| `RewardHandler.queueInsuranceRewards()` | exact FeeDeposit operator | `amount(role-controlled)` | → token approval/InsurancePool reward queue; value into IP rewards | N | No |
| `RewardHandler.queueStakingRewards()` | exact FeeDeposit operator | `amount(role-controlled)` | → token approval/GovStaker reward queue; value into staking rewards | N | No |
| `Stablecoin.mint()` | approved operator or token owner | `to(role-controlled)`, `amount(role-controlled)` | → `_mint`; reUSD supply/value out | N | Operator revocation is the mint kill switch |
| `TreasuryManager.approveTokenFromPrismaFeeReceiver()` | exact `manager` | `token(role-controlled)`, `spender(role-controlled)`, `amount(role-controlled)` | → Core → fixed Prisma receiver `setTokenApproval`; approval authority | N | No |
| `TreasuryManager.claimLpIncentives()` | exact `manager` | — | → configured receiver `claimEmissions(manager)` → emissions transfer; value to manager | N | No |
| `TreasuryManager.claimLpIncentivesTo()` | exact `manager` | `_to(role-controlled)` | → receiver `claimEmissions(_to)`; value out | N | No |
| `TreasuryManager.execute()` | exact `manager` | `_target(role-controlled)`, `_data(role-controlled)` | → Core → Treasury `execute` → target call; arbitrary state/value | N | No |
| `TreasuryManager.recoverERC20()` | exact `manager` | `token(role-controlled)` | → token balance → `safeTransfer(manager,all)`; value out | N | No |
| `TreasuryManager.retrieveETH()` | exact `manager` | `_to(role-controlled)` | → Core → Treasury ETH transfer all; value out | N | No |
| `TreasuryManager.retrieveETHExact()` | exact `manager` | `_to(role-controlled)`, `_amount(role-controlled)` | → Core → Treasury ETH exact transfer; value out | N | No |
| `TreasuryManager.retrieveToken()` | exact `manager` | `_token(role-controlled)`, `_to(role-controlled)` | → Core `execute(treasury, Treasury.retrieveToken)` → token transfer all; value out | N | No |
| `TreasuryManager.retrieveTokenExact()` | exact `manager` | `_token(role-controlled)`, `_to(role-controlled)`, `_amount(role-controlled)` | → Core → Treasury exact transfer; value out | N | No |
| `TreasuryManager.safeExecute()` | exact `manager` | `_target(role-controlled)`, `_data(role-controlled)` | → Core → Treasury `safeExecute` → target call; arbitrary state/value | N | No |
| `TreasuryManager.setLpIncentivesReceiver()` | exact `manager` | `_lpIncentivesReceiver(role-controlled)` | → receiver SSTORE; none | N | No |
| `TreasuryManager.setTokenApproval()` | exact `manager` | `_token(role-controlled)`, `_spender(role-controlled)`, `_amount(role-controlled)` | → Core → Treasury `forceApprove`; approval authority | N | No |
| `TreasuryManager.transferTokenFromPrismaFeeReceiver()` | exact `manager` | `token(role-controlled)`, `to(role-controlled)`, `amount(role-controlled)` | → Core → fixed Prisma receiver `transferToken`; value out | N | No |
| `TreasuryManagerUpgradeable.approveTokenFromPrismaFeeReceiver()` | exact `manager` | `token(role-controlled)`, `spender(role-controlled)`, `amount(role-controlled)` | → Core → fixed Prisma receiver approval; approval authority | N | No |
| `TreasuryManagerUpgradeable.claimLpIncentives()` | exact `manager` | — | → receiver `claimEmissions(manager)`; value to manager | N | No |
| `TreasuryManagerUpgradeable.claimLpIncentivesTo()` | exact `manager` | `_to(role-controlled)` | → receiver `claimEmissions(_to)`; value out | N | No |
| `TreasuryManagerUpgradeable.execute()` | exact `manager` | `_target(role-controlled)`, `_data(role-controlled)` | → Core → Treasury arbitrary call; arbitrary state/value | N | No |
| `TreasuryManagerUpgradeable.recoverERC20()` | exact `manager` | `token(role-controlled)` | → `safeTransfer(manager,all)`; value out | N | No |
| `TreasuryManagerUpgradeable.retrieveETH()` | exact `manager` | `_to(role-controlled)` | → Core → Treasury ETH all; value out | N | No |
| `TreasuryManagerUpgradeable.retrieveETHExact()` | exact `manager` | `_to(role-controlled)`, `_amount(role-controlled)` | → Core → Treasury ETH exact; value out | N | No |
| `TreasuryManagerUpgradeable.retrieveToken()` | exact `manager` | `_token(role-controlled)`, `_to(role-controlled)` | → Core → fixed Treasury `retrieveToken`; value out | N | No |
| `TreasuryManagerUpgradeable.retrieveTokenExact()` | exact `manager` | `_token(role-controlled)`, `_to(role-controlled)`, `_amount(role-controlled)` | → Core → Treasury exact transfer; value out | N | No |
| `TreasuryManagerUpgradeable.safeExecute()` | exact `manager` | `_target(role-controlled)`, `_data(role-controlled)` | → Core → Treasury checked call; arbitrary state/value | N | No |
| `TreasuryManagerUpgradeable.setLpIncentivesReceiver()` | exact `manager` | `_lpIncentivesReceiver(role-controlled)` | → receiver SSTORE; none | N | No |
| `TreasuryManagerUpgradeable.setTokenApproval()` | exact `manager` | `_token(role-controlled)`, `_spender(role-controlled)`, `_amount(role-controlled)` | → Core → Treasury approval; approval authority | N | No |
| `TreasuryManagerUpgradeable.transferTokenFromPrismaFeeReceiver()` | exact `manager` | `token(role-controlled)`, `to(role-controlled)`, `amount(role-controlled)` | → Core → fixed Prisma receiver transfer; value out | N | No |
| `TreasuryStableDiversification.swap()` | Role-Gated (conditional) — configured `operators[msg.sender]` when `useOperators`; any caller when false | `amount(keeper-provided)` | → pull treasury asset excess → optional staking vault → Curve exchange → optional target vault deposit/treasury transfer; transient balances/approvals; value treasury out/diversified back | Y | No |
| `UpgradeOperator.upgradeToAndCall()` | Core admin or exact `manager` | `target(role-controlled)`, `newImplementation(role-controlled)`, `data(role-controlled)` | → Core `execute(target,upgradeToAndCall)` → proxy upgrade/initializer; arbitrary state/value | N | No |
| `VeCrvOperator.claimFees()` | Core admin or exact `manager` | — | → Curve distributor claim(PRISMA voter) → voter proxy transfer to receiver; value out | N | No |
| `VeCrvOperator.claimFees(bool,address)` | Core admin or exact `manager` | `wrap(role-controlled)`, `recipient(role-controlled)` | → claim → voter proxy transfer; optional scrvUSD deposit; value out | N | No |
| `VeCrvOperator.delegateBoost()` | Core admin or exact `manager` | — | → `extendLock` → veBoost boosts Convex/Yearn; external voting-power state | N | No |
| `VeCrvOperator.extendLock()` | Core admin or exact `manager` | — | → Core → Prisma voter proxy execute Curve escrow `increase_unlock_time`; external lock state | N | No |
| `VeCrvOperator.setBoostShare()` | Core admin or exact `manager` | `_newConvexShare(role-controlled)` | → share SSTORE; none | N | No |
| `VeCrvOperator.setReceiver()` | Core admin or exact `manager` | `_receiver(role-controlled)` | → receiver SSTORE; none | N | No |
| `VeCrvOperator.voteForGaugeWeights()` | Core admin or exact `manager` | `votes(role-controlled)` | → Prisma voter proxy `voteForGaugeWeights`; external vote state | N | No |
| `VeCrvOperator.voteInCurveDao()` | Core admin or exact `manager` | `aragon(role-controlled)`, `id(role-controlled)`, `support(role-controlled)` | → Prisma voter proxy `voteInCurveDao`; external vote state | N | No |

### Other Bounded Roles

| Contract / function | Required caller | Parameters | Downstream chain, state, and value | NR | Pause coverage |
|---|---|---|---|---|---|
| `EmissionsController.fetchEmissions()` | exact registered receiver (`validReceiver(msg.sender)`) | — | → `_fetchEmissions` → `_mintEmissions` → GovToken `mint`; writes epochs/allocation/unallocated; value minted/allocated | N | No |
| `GovToken.mint()` | exact `minter` | `_to(role-controlled)`, `_amount(role-controlled)` | → OFT/ERC20 `_mint`; writes balances/supply and `globalSupply`; value minted | N | No |
| `RewardHandler.setPairWeight()` | exact FeeDeposit | `pair(protocol-derived)`, `amount(protocol-derived)` | → pair weight/revenue accounting → fee logger | N | No |
| `WriteOffToken.mint()` | only immutable `owner` changes state; unauthorized callers return without effect | `to(protocol-derived)`, `amount(protocol-derived)` | → `_mint` only for owner; write-off supply/account balance | N | No |

### Rewards and Fee Roles

| Contract / function | Required caller | Parameters | Downstream chain, state, and value | NR | Pause coverage |
|---|---|---|---|---|---|
| `FeeLogger.logInterestFees()` | exact RewardHandler or Core owner | `pair(role-controlled)`, `amount(role-controlled)` | → interest-fee log SSTORE/event | N | No |
| `MultiRewardsDistributor.notifyRewardAmount()` | exact configured distributor for `token` | `token(role-controlled)`, `amount(role-controlled)` | → reward-rate/period state → token `transferFrom(distributor)`; value in | N | No |
| `MultiRewardsDistributor.setRewardsDuration()` | token distributor or Core owner | `token(role-controlled)`, `duration(role-controlled)` | → duration SSTORE after period completion | N | No |
| `RetentionIncentives.queueNewRewards()` | Core owner or exact `rewardHandler`; requires finalized setup | `amount(role-controlled)` | → token `transferFrom` → reward-rate/period state | N | No |
| `RewardDistributorMultiEpoch.addExtraReward()` | deployer-specific `_isRewardManager` (Core or configured reward handler) | `token(role-controlled)` | → extra-reward token/config state | Y | No |
| `RewardDistributorMultiEpoch.invalidateReward()` | deployer-specific reward manager | `token(role-controlled)` | → reward validity/config state | Y | No |
| `SimpleRewardStreamer.queueNewRewards()` | Core owner or configured reward handler | `amount(role-controlled)` | → token `transferFrom` → reward-rate/period state | N | No |
| `SimpleRewardStreamer.setRewardWeight()` | Core owner or configured reward handler | `account(role-controlled)`, `weight(role-controlled)` | → checkpoints → weight/total-weight SSTORE | N | No |
| `SimpleRewardStreamer.setRewardWeights()` | Core owner or configured reward handler | `accounts(role-controlled)`, `weights(role-controlled)` | → repeated checkpoints/weight writes | N | No |

---

## Admin-Only

Top-level owner/Core/governance configuration and asset-control functions.

| Contract | Function | Parameters | State modified / downstream leaf / value | NR | Pause coverage |
|---|---|---|---|---|---|
| `AutoStakeCallback` | `recoverERC20()` | `token(admin-controlled)`, `to(admin-controlled)` | → token balance → transfer all; value out; access: Core admin | N | No |
| `BorrowLimitController` | `cancelRamp()` | `_pair(admin-controlled)` | → clears `pairLimits[_pair]`; none; access: Core admin | N | No |
| `BorrowLimitController` | `setPairBorrowLimitRamp()` | `_pair(admin-controlled)`, `_newBorrowLimit(admin-controlled)`, `_endTime(admin-controlled)` | → pair `borrowLimit()` → writes timed `pairLimits`; none; access: Core admin | N | No |
| `Core` | `setVoter()` | `newVoter(admin-controlled)` | → `voter=SSTORE`; none; access: exact `msg.sender==address(this)` (reachable through authorized self-call) | N | No |
| `CurveLendMinterFactory` | `addMarketOperator()` | `_market(admin-controlled)`, `_initialMintLimit(admin-controlled)` | → proxy clone → markets SSTORE → operator initialize → factory borrow/vault deposit; CRVUSD out; access: OZ `owner()` | Y | No |
| `CurveLendMinterFactory` | `removeMarketOperator()` | `_market(admin-controlled)` | → `markets[_market]=0`; blocks future borrow; access: OZ `owner()` | Y | Borrow pause for removed operator |
| `CurveLendMinterFactory` | `setFeeReceiver()` | `_receiver(admin-controlled)` | → fee receiver SSTORE; none; access: OZ `owner()` | Y | No |
| `CurveLendMinterFactory` | `setImplementation()` | `_implementation(admin-controlled)` | → implementation SSTORE; none; access: OZ `owner()` | Y | No |
| `CurveLendOperator` | `setMintLimit()` | `_newLimit(admin-controlled)` | → `_setMintLimit` → factory `borrow` → vault deposit when limit grows; `mintLimit,mintedAmount`; CRVUSD in; access: exact factory `admin()` / factory owner | Y | Limit can be set down; no separate pause |
| `EmissionsController` | `activateReceiver()` | `_id(admin-controlled)` | → `_fetchEmissions` → `active=true`; may mint/allocate GOV; access: Core admin | N | No |
| `EmissionsController` | `deactivateReceiver()` | `_id(admin-controlled)` | → `_fetchEmissions` → `active=false`; may mint/allocate GOV; access: Core admin | N | No |
| `EmissionsController` | `recoverUnallocated()` | `_recipient(admin-controlled)` | → `unallocated=0` → GOV `transfer`; value out; access: Core admin | N | No |
| `EmissionsController` | `registerReceiver()` | `_receiver(admin-controlled)` | → writes IDs/receiver info/allocation → external `IReceiver.getReceiverId`; none; access: Core admin | N | No |
| `EmissionsController` | `setEmissionsSchedule()` | `_rates(admin-controlled)`, `_epochsPer(admin-controlled)`, `_tailRate(admin-controlled)` | → optional `_mintEmissions` at old rate → schedule/rate config SSTORE; may mint GOV; access: Core admin | N | No |
| `EmissionsController` | `setReceiverWeights()` | `_receiverIds(admin-controlled)`, `_newWeights(admin-controlled)` | → `_fetchEmissions` under old weight → writes `idToReceiver[].weight`; may mint GOV/allocate; access: Core admin | N | No |
| `FeeDeposit` | `setOperator()` | `_operator(admin-controlled)` | → operator SSTORE; access: Core admin | N | No |
| `FeeDepositController` | `setDistribution()` | `_treasuryPct(admin-controlled)`, `_sreUsdPct(admin-controlled)`, `_insurancePct(admin-controlled)`, `_stakingPct(admin-controlled)` | → distribution SSTORE; access: Core admin | N | No |
| `FeeDepositController` | `setTreasury()` | `_treasury(admin-controlled)` | → treasury SSTORE; access: Core admin | N | No |
| `GovStaker` | `setCooldownEpochs()` | `_cooldownEpochs(admin-controlled)` | → cooldown-period SSTORE; access: Core admin | N | Setting zero enables migration; not a global pause |
| `GovToken` | `finalizeMinter()` | — | → `minterFinalized=true` one-way; none; access: OZ `owner()` (Core) | N | No |
| `GovToken` | `setMinter()` | `_minter(admin-controlled)` | → `minter=SSTORE`; none; access: OZ `owner()` (Core) | N | No |
| `Guardian` | `setGuardian()` | `_guardian(admin-controlled)` | → guardian SSTORE; none; access: Core admin | N | n/a |
| `GuardianUpgradeable` | `setGuardedRegistryKey()` | `_key(admin-controlled)`, `_guarded(admin-controlled)` | → `guardedRegistryKeys` SSTORE; none; access: fixed `CORE` | N | n/a |
| `GuardianUpgradeable` | `setGuardian()` | `_guardian(admin-controlled)` | → guardian SSTORE; none; access: fixed `CORE` | N | n/a |
| `InsurancePool` | `setMinimumHeldAssets()` | `_minimumHeldAssets(admin-controlled)` | → minimum reserve SSTORE; access: Core admin | N | No |
| `InsurancePool` | `setWithdrawTimers()` | `_withdrawLength(admin-controlled)`, `_withdrawTimeLimit(admin-controlled)` | → withdrawal timer SSTORE; access: Core admin | N | Setting time limit to zero is guardian withdrawal pause |
| `InterestRateCalculatorV2` | `setParameters()` | `minRate(admin-controlled)`, `maxRate(admin-controlled)`, `vertexRate(admin-controlled)`, `vertexUtilization(admin-controlled)` | → rate-parameter SSTORE; access: Core admin | N | No |
| `Keeper` | `setOperators()` | `_operators(admin-controlled)`, `_minProfit(admin-controlled)` | → operators/minProfit SSTORE; none; access: exact keeper `owner` | N | No |
| `Keeper` | `setOwner()` | `_owner(admin-controlled)` | → owner SSTORE; none; access: exact keeper `owner` | N | No |
| `KeeperV1` | `setOwner()` | `_owner(admin-controlled)` | → owner SSTORE; none; access: exact keeper `owner` | N | No |
| `KeeperV2` | `setOwner()` | `_owner(admin-controlled)` | → owner SSTORE; none; access: exact keeper `owner` | N | No |
| `LiquidationHandler` | `distributeFees()` | — | → accumulated balances transferred/queued to configured receivers; access: Core admin | N | No |
| `LiquidationHandler` | `setInsuranceIncentive()` | `_incentive(admin-controlled)` | → incentive SSTORE; access: Core admin | N | No |
| `MultiRewardsDistributor` | `addReward()` | `token(admin-controlled)`, `distributor(admin-controlled)`, `duration(admin-controlled)` | → reward-token/config SSTORE; access: Core admin | N | No |
| `MultiRewardsDistributor` | `recoverERC20()` | `token(admin-controlled)`, `to(admin-controlled)`, `amount(admin-controlled)` | → ERC20 transfer; value out; access: Core admin | N | No |
| `MultiRewardsDistributor` | `setRewardsDistributor()` | `token(admin-controlled)`, `distributor(admin-controlled)` | → distributor SSTORE; access: Core admin | N | No |
| `PairAdder` | `addPair()` | `_pair(admin-controlled)` | → deployer `deployInfo` check → Core `execute(registry,addPair)` → registry/pair swapper state; access: Core admin | N | No |
| `PermaStaker` | `setOperator()` | `_operator(admin-controlled)` | → `operator=SSTORE`; none; access: OZ `owner()` | N | No |
| `PriceWatcher` | `setOracle()` | `_oracle(admin-controlled)` | → oracle SSTORE; access: Core admin | N | No |
| `RedemptionHandler` | `setMaxRedemptionFee()` | `_maxFee(admin-controlled)` | → max-fee SSTORE; access: Core admin | N | No |
| `RedemptionHandler` | `setOracle()` | `_oracle(admin-controlled)` | → oracle SSTORE; access: Core admin | N | No |
| `RedemptionHandler` | `setRedemptionFee()` | `_fee(admin-controlled)` | → fee SSTORE; access: Core admin | N | No |
| `RedemptionHandler` | `setRedemptionLimit()` | `_limit(admin-controlled)` | → limit SSTORE; access: Core admin | N | No |
| `RedemptionHandler` | `setRedemptionOperator()` | `_operator(admin-controlled)` | → operator SSTORE; access: Core admin | N | No |
| `RedemptionHandler` | `updateGuardSettings()` | `_enabled(admin-controlled)`, `_threshold(admin-controlled)` | → guard state SSTORE; access: Core admin | N | This configures the conditional redemption gate |
| `RedemptionOperator` | `setManager()` | `_manager(admin-controlled)` | → manager SSTORE; none; access: fixed `CORE` | N | No |
| `ResupplyPair` | `pause()` | — | → stores `previousBorrowLimit` → sets `borrowLimit=0`; no token flow; access: Core admin | N | This is the pair borrow pause; other paths remain callable |
| `ResupplyPair` | `setBorrowLimit()` | _limit(admin-controlled) | → `_setBorrowLimit` → `borrowLimit` SSTORE; controls future mint capacity; access: Core admin | N | Setting zero blocks new borrowing |
| `ResupplyPair` | `setConvexPool()` | pid(admin-controlled) | → `_updateConvexPool` → Convex unstake/re-stake → `convexPid` SSTORE; collateral moves between staking pools; access: Core admin | N | No |
| `ResupplyPair` | `setLiquidationFees()` | _newLiquidationFee(admin-controlled) | → bounded `liquidationFee` SSTORE; no token flow; access: Core admin | N | No |
| `ResupplyPair` | `setMaxLTV()` | _newMaxLTV(admin-controlled) | → bounded `maxLTV` SSTORE; no token flow; access: Core admin | N | No |
| `ResupplyPair` | `setMinimumBorrowAmount()` | _min(admin-controlled) | → `minimumBorrowAmount` SSTORE; no token flow; access: Core admin | N | No |
| `ResupplyPair` | `setMinimumLeftoverDebt()` | _min(admin-controlled) | → `minimumLeftoverDebt` SSTORE; no token flow; access: Core admin | N | No |
| `ResupplyPair` | `setMinimumRedemption()` | _min(admin-controlled) | → bounded `minimumRedemption` SSTORE; no token flow; access: Core admin | N | No |
| `ResupplyPair` | `setMintFees()` | _newMintFee(admin-controlled) | → `mintFee` SSTORE; no token flow; access: Core admin | N | No |
| `ResupplyPair` | `setOracle()` | _newOracle(admin-controlled) | → `exchangeRateInfo.oracle` SSTORE; no token flow; access: Core admin | N | No |
| `ResupplyPair` | `setProtocolRedemptionFee()` | _fee(admin-controlled) | → bounded `protocolRedemptionFee` SSTORE; no token flow; access: Core admin | N | No |
| `ResupplyPair` | `setRateCalculator()` | _newRateCalculator(admin-controlled), _updateInterest(admin-controlled) | → optional `_addInterest()` → `rateCalculator` SSTORE; may accrue debt/fees, no direct transfer; access: Core admin | N | No |
| `ResupplyPair` | `setSwapper()` | _swapper(admin-controlled / protocol-derived), _approval(admin-controlled / protocol-derived) | → `swappers[_swapper]` SSTORE; no immediate token flow; access: Core owner or exact registry contract | N | Revocation disables that swapper |
| `ResupplyPair` | `unpause()` | — | → restores `borrowLimit` from `previousBorrowLimit`; no token flow; access: Core admin | N | This restores borrowing |
| `ResupplyPairDeployer` | `addSupportedProtocol()` | _protocolName(admin-controlled), _amountToBurn(admin-controlled), _minShareBurnAmount(admin-controlled), _borrowTokenSig(admin-controlled), _collateralTokenSig(admin-controlled) | → appends `supportedProtocols`; no token flow; access: Core admin | N | No |
| `ResupplyPairDeployer` | `deploy()` | _protocolId(admin-controlled), _configData(admin-controlled), _underlyingStaking(admin-controlled), _underlyingStakingId(admin-controlled) | → `_deploy`/CREATE2 → burn ERC4626 shares → Core/Registry registration; deployed-pair/config state, bootstrap value burned; access: Core admin | N | No |
| `ResupplyPairDeployer` | `setApprovedDeployer()` | _deployer(admin-controlled), _approved(admin-controlled) | → `approvedDeployers` SSTORE; no token flow; access: Core admin | N | Revocation blocks default-config deployments by that address |
| `ResupplyPairDeployer` | `setCreationCode()` | _creationCode(admin-controlled) | → SSTORE2 writes → `contractAddress1/contractAddress2` SSTORE; no token flow; access: Core admin | N | No |
| `ResupplyPairDeployer` | `setDefaultConfigData()` | _oracle(admin-controlled), _rateCalculator(admin-controlled), _maxLTV(admin-controlled), _initialBorrowLimit(admin-controlled), _liquidationFee(admin-controlled), _mintFee(admin-controlled), _protocolRedemptionFee(admin-controlled) | → `_defaultConfigData` SSTORE; no token flow; access: Core admin | N | No |
| `ResupplyPairDeployer` | `updateSupportedProtocol()` | _protocolId(admin-controlled), _protocolName(admin-controlled), _amountToBurn(admin-controlled), _minShareBurnAmount(admin-controlled), _borrowTokenSig(admin-controlled), _collateralTokenSig(admin-controlled) | → selected protocol config SSTORE; no token flow; access: Core admin | N | No |
| `ResupplyRegistry` | `addPair()` | `_pair(admin-controlled)` | → pair list/name/active-pair state and default swapper setup; access: Core admin | N | No |
| `ResupplyRegistry` | `setAddress()` | `_key(admin-controlled)`, `_address(admin-controlled)` | → address-book SSTORE; access: Core admin | N | No |
| `ResupplyRegistry` | `setDefaultSwappers()` | `_swappers(admin-controlled)` | → default-swapper array SSTORE; access: Core admin | N | No |
| `ResupplyRegistry` | `setFeeDeposit()` | `_feeDeposit(admin-controlled)` | → fee-deposit SSTORE; access: Core admin | N | No |
| `ResupplyRegistry` | `setGovStaker()` | `_staker(admin-controlled)` | → staker SSTORE; access: Core admin | N | No |
| `ResupplyRegistry` | `setInsurancePool()` | `_pool(admin-controlled)` | → insurance-pool SSTORE; access: Core admin | N | No |
| `ResupplyRegistry` | `setL2Manager()` | `_manager(admin-controlled)` | → L2 manager SSTORE; access: Core admin | N | No |
| `ResupplyRegistry` | `setLiquidationHandler()` | `_handler(admin-controlled)` | → liquidation-handler SSTORE; access: Core admin | N | No |
| `ResupplyRegistry` | `setRedemptionHandler()` | `_handler(admin-controlled)` | → redemption-handler SSTORE; access: Core admin | N | No |
| `ResupplyRegistry` | `setRewardHandler()` | `_handler(admin-controlled)` | → reward-handler SSTORE; access: Core admin | N | No |
| `ResupplyRegistry` | `setTreasury()` | `_treasury(admin-controlled)` | → treasury SSTORE; access: Core admin | N | No |
| `ResupplyRegistry` | `setVestManager()` | `_manager(admin-controlled)` | → vest-manager SSTORE; access: Core admin | N | No |
| `ResupplyRegistry` | `withdrawTo()` | `token(admin-controlled)`, `to(admin-controlled)`, `amount(admin-controlled)` | → ERC20 transfer; value out; access: Core admin | N | No |
| `RetentionIncentives` | `setRewardHandler()` | `_rewardHandler(admin-controlled)` | → handler SSTORE; access: Core admin | N | No |
| `RetentionReceiver` | `setTreasuryAllocationPerEpoch()` | `_treasuryAllocationPerEpoch(admin-controlled)` | → config SSTORE; none; access: Core admin | N | No |
| `RetentionReceiver` | `sweepERC20()` | `token(admin-controlled)` | → token `balanceOf` → `safeTransfer(registry.treasury,all)`; value out; access: Core admin | N | No |
| `RewardHandler` | `migrateState()` | `pairs(admin-controlled)` | → reads old handler → pair/reward accounting writes; access: Core admin | N | No |
| `RewardHandler` | `setBaseMinimumWeight()` | `_weight(admin-controlled)` | → base-minimum-weight SSTORE; access: Core admin | N | No |
| `RewardHandler` | `setPairMinimumWeight()` | `pair(admin-controlled)`, `weight(admin-controlled)` | → pair-minimum-weight SSTORE; access: Core admin | N | No |
| `RouterSwapper` | `recoverERC20()` | `token(admin-controlled)`, `to(admin-controlled)`, `amount(admin-controlled)` | → token transfer; value out; access: Core admin | N | No |
| `RouterSwapper` | `revokeApprovals()` | `tokens(admin-controlled)` | → router allowances zeroed; `approvalsRevoked=true`; access: Core admin | N | This is the swapper pause/revocation path |
| `SavingsReUSD` | `setMaxDistributionPerSecondPerAsset()` | _maxDistributionPerSecondPerAsset(admin-controlled) | → sync rewards → capped distribution-rate SSTORE; reward accounting/value distribution; access: OZ owner (Core) | N | No |
| `SimpleReceiver` | `setApprovedClaimer()` | `claimer(admin-controlled)`, `approved(admin-controlled)` | → `approvedClaimers[claimer]=approved`; none; access: Core admin | N | No |
| `SimpleReceiverFactory` | `deployNewReceiver()` | `_name(admin-controlled)`, `_approvedClaimers(admin-controlled)` | → `Clones.cloneDeterministic` → receiver `initialize`; pushes `receivers`, writes `nameHashToReceiver`; none; access: Core admin | N | No |
| `SimpleReceiverFactory` | `setImplementation()` | `_implementation(admin-controlled)` | → `implementation=SSTORE`; none; access: Core admin (`msg.sender==address(core)`) | N | No |
| `Stablecoin` | `setOperator()` | `operator(admin-controlled)`, `status(admin-controlled)` | → operators mapping SSTORE; access: OZ `owner()` (Core) | N | Revoking operators stops their mint path |
| `Swapper` | `addPairing()` | `tokenIn(admin-controlled)`, `tokenOut(admin-controlled)`, `pool(admin-controlled)`, `poolType(admin-controlled)` | → route/pairing SSTORE and approvals; access: Core admin | N | No |
| `Treasury` | `execute()` | `target(admin-controlled)`, `data(admin-controlled)` | → `target.call(data)`; arbitrary state/value; access: external wrapper delegates to `_execute(... ) onlyOwner` (Core admin) | N | No |
| `Treasury` | `retrieveETH()` | `_to(admin-controlled)` | → `retrieveETHExact` → low-level value call; ETH out; access: Core admin | N | No |
| `Treasury` | `retrieveETHExact()` | `_to(admin-controlled)`, `_amount(admin-controlled)` | → `_to.call{value:amount}`; ETH out; access: Core admin | N | No |
| `Treasury` | `retrieveToken()` | `_token(admin-controlled)`, `_to(admin-controlled)` | → `retrieveTokenExact` → ERC20 `safeTransfer(all)`; value out; access: Core admin | N | No |
| `Treasury` | `retrieveTokenExact()` | `_token(admin-controlled)`, `_to(admin-controlled)`, `_amount(admin-controlled)` | → ERC20 `safeTransfer`; value out; access: Core admin | N | No |
| `Treasury` | `safeExecute()` | `target(admin-controlled)`, `data(admin-controlled)` | → `target.call(data)`, requires success; arbitrary state/value; access: delegated `_execute.onlyOwner` (Core admin) | N | No |
| `Treasury` | `setTokenApproval()` | `_token(admin-controlled)`, `_spender(admin-controlled)`, `_amount(admin-controlled)` | → ERC20 `forceApprove`; approval/value authority; access: Core admin | N | No |
| `TreasuryManager` | `setManager()` | `_manager(admin-controlled)` | → `manager=SSTORE`; none; access: Core admin | N | No |
| `TreasuryManagerUpgradeable` | `setManager()` | `_manager(admin-controlled)` | → `manager=SSTORE`; none; access: exact fixed `CORE` via `BaseUpgradeableOperator.onlyOwner` | N | No |
| `TreasuryStableDiversification` | `retrieveToken()` | `token(admin-controlled)`, `to(admin-controlled)` | → `retrieveTokenExact(all)` → ERC20 transfer; value out; access: OZ `owner()` | N | No |
| `TreasuryStableDiversification` | `retrieveTokenExact()` | `token(admin-controlled)`, `to(admin-controlled)`, `amount(admin-controlled)` | → ERC20 `safeTransfer`; value out; access: OZ `owner()` | N | No |
| `TreasuryStableDiversification` | `setMaxDeviationBps()` | `newMaxDeviationBps(admin-controlled)` | → config SSTORE; none; access: OZ `owner()` | N | No |
| `TreasuryStableDiversification` | `setMinTreasuryAssetBalance()` | `newMinTreasuryAssetBalance(admin-controlled)` | → config SSTORE; none; access: OZ `owner()` | N | No |
| `TreasuryStableDiversification` | `setOperator()` | `operator(admin-controlled)`, `active(admin-controlled)` | → `operators[operator]=active`; none; access: OZ `owner()` | N | No |
| `TreasuryStableDiversification` | `setTargets()` | `newTargets(admin-controlled)` | → validates ERC4626/pools → replaces `_targets,totalWeight`; none; access: OZ `owner()` | N | No |
| `TreasuryStableDiversification` | `setUseOperators()` | `newUseOperators(admin-controlled)` | → config SSTORE; changes caller gate; access: OZ `owner()` | N | No |
| `UpgradeOperator` | `setManager()` | `_manager(admin-controlled)` | → manager SSTORE; none; access: Core admin | N | No |
| `VeCrvOperator` | `setManager()` | `_manager(admin-controlled)` | → manager SSTORE; none; access: Core admin | N | No |
| `VestManager` | `setInitializationParams()` | `_maxRedeemable(admin-controlled)`, `_merkleRoots(admin-controlled)`, `_nonUserTargets(admin-controlled)`, `_vestDurations(admin-controlled)`, `_allocPercentages(admin-controlled)` | → creates vests/roots/allocations/durations/redemption ratio; no transfer; access: Core admin, manual `!initialized` | N | No |
| `VestManager` | `setLockPenaltyMerkleRoot()` | `_root(admin-controlled)`, `_allocation(admin-controlled)` | → root/allocation SSTORE; none; access: Core admin, root must be unset | N | No |
| `Voter` | `cancelProposal()` | `id(admin-controlled)` | → `proposalData[id].processed=true`; none; access: Core admin | N | No |
| `Voter` | `setMinCreateProposalPct()` | `pct(admin-controlled)` | → config SSTORE; none; access: Core admin | N | No |
| `Voter` | `setMinTimeBetweenProposals()` | `_cooldown(admin-controlled)` | → config SSTORE; none; access: Core admin | N | No |
| `Voter` | `setQuorumPct()` | `pct(admin-controlled)` | → config SSTORE; none; access: Core admin | N | No |
| `Voter` | `updateProposalDescription()` | `id(admin-controlled)`, `description(admin-controlled)` | → `proposalDescription[id]=description`; none; access: Core admin | N | No |

---

## Initialization

One-time deployment entry points. Initializer guards constrain call count/version but do not themselves authenticate the first caller unless stated below.

| Entry point | Exact one-shot gate / caller | Parameters | Downstream chain, state, and value | NR | Pause coverage |
|---|---|---|---|---|---|
| `SimpleReceiver.initialize()` | manual `require(!initialized)`; intended factory caller, but no caller binding | `_name(admin-controlled)`, `_approvedClaimers(admin-controlled)` | → sets `initialized,name,approvedClaimers`; none | N | No |
| `CurveLendOperator.initialize()` | manual `market == address(0)`; intended factory, but no caller binding | `_factory(admin-controlled)`, `_market(admin-controlled)`, `_initialMintLimit(admin-controlled)` | → approve CRVUSD → `_setMintLimit` → factory borrow → ERC4626 deposit; value in | Y | No |
| `GuardianUpgradeable.initialize()` | OZ `initializer`; no role binding inside body | `_guardian(admin-controlled)` | → sets `guardian`; none | N | No |
| `TreasuryManagerUpgradeable.initialize()` | OZ `initializer`; no role binding inside body | `_manager(admin-controlled)` | → sets `manager`; none | N | No |
| `RedemptionOperator.initialize()` | OZ `initializer`; implementation disables initializers | `_manager(admin-controlled)`, `_callers(admin-controlled)` | → initializes NR → token approvals → sets manager/approved callers; approval flow | N (initializes guard) | No |
| `KeeperV1.initialize()` | OZ `initializer`; no role binding inside body | `_owner(admin-controlled)` | → sets `owner`; none | N | No |
| `KeeperV2.initialize()` | OZ `initializer`; empty body | — | → initializer version state only; none | N | No |

