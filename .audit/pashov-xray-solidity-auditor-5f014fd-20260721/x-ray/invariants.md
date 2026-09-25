# Invariant Map

> Resupply | 52 guards | 49 inferred | 5 not enforced on-chain

---

## 1. Enforced Guards (Reference)

Per-call preconditions. Heading IDs below (`G-N`) are anchor targets from `x-ray.md` attack surfaces. The scope is frozen to the 65 production files in `x-ray/work/audit-scope.txt`.

#### G-1
`require(msg.sender == address(core), "!core")` · `src/dependencies/CoreOwnable.sol:20` · Restricts every `onlyOwner` path inherited from `CoreOwnable` to Core.

#### G-2
`require(msg.sender == _account || isApprovedDelegate[_account][msg.sender], "!CallerOrDelegated")` · `src/dependencies/DelegatedOps.sol:16` · Restricts delegated account actions to the account or its approved delegate.

#### G-3
`require(msg.sender == minter, "!minter")` · `src/dao/GovToken.sol:17` · Restricts governance-token inflation to the configured minter.

#### G-4
`require(!minterFinalized, "minter finalized")` · `src/dao/GovToken.sol:53` · Prevents changing the minter after finalization.

#### G-5
`require(market == address(0), "!init")` · `src/dao/CurveLendOperator.sol:50` · Makes operator initialization single-use.

#### G-6
`require(mintedAmount > mintLimit, "can not reduce")` · `src/dao/CurveLendOperator.sol:100` · Permits principal reduction only when accounted principal exceeds the configured floor.

#### G-7
`require(!acctData.isPermaStaker, "perma staker account")` · `src/dao/staking/GovStaker.sol:118` · Prevents a permanent staker from entering cooldown.

#### G-8
`if (block.timestamp < userCooldown.end && cooldownEpochs != 0) revert InvalidCooldown()` · `src/dao/staking/GovStaker.sol:166` · Prevents an escrow withdrawal before cooldown maturity while cooldowns are enabled.

#### G-9
`require(!accountData[_account].isPermaStaker, "already perma staker account")` · `src/dao/staking/GovStaker.sol:401` · Prevents re-committing an already permanent account.

#### G-10
`if (rewardData[_rewardsToken].rewardsDuration != 0) revert RewardAlreadyAdded()` · `src/dao/staking/MultiRewardsDistributor.sol:128` · Prevents registering the same reward token twice.

#### G-11
`if (_rewardData.rewardsDistributor != msg.sender) revert Unauthorized()` · `src/dao/staking/MultiRewardsDistributor.sol:147` · Restricts reward notification to the token's stored distributor.

#### G-12
`if (block.timestamp <= rewardData[_rewardsToken].periodFinish) revert RewardsStillActive()` · `src/dao/staking/MultiRewardsDistributor.sol:202` · Prevents changing a reward duration during an active stream.

#### G-13
`require(!initialized, "params already set")` · `src/dao/tge/VestManager.sol:74` · Makes TGE parameter initialization single-use.

#### G-14
`require(merkleRootByType[AllocationType.AIRDROP_LOCK_PENALTY] == bytes32(0), "root already set")` · `src/dao/tge/VestManager.sol:125` · Makes the lock-penalty root write single-use.

#### G-15
`require(!hasClaimed[_account][_type], "already claimed")` · `src/dao/tge/VestManager.sol:149` · Prevents a second Merkle claim for the same account/allocation type.

#### G-16
`require(latestProposalTimestamp[account] + minTimeBetweenProposals < block.timestamp, "Too soon")` · `src/dao/Voter.sol:158` · Enforces the per-proposer creation cooldown.

#### G-17
`require(vote.weightYes + vote.weightNo == 0, "Already voted")` · `src/dao/Voter.sol:219` · Permits only one vote record per account/proposal.

#### G-18
`require(!proposal.processed, "Proposal already processed")` · `src/dao/Voter.sol:222` · Prevents voting on a processed proposal.

#### G-19
`require(proposal.createdAt + VOTING_PERIOD > block.timestamp, "Voting period has closed")` · `src/dao/Voter.sol:223` · Closes voting at the stored voting deadline.

#### G-20
`require(_canExecute(proposal), "Proposal cannot be executed")` · `src/dao/Voter.sol:291` · Gates execution on unprocessed state, the execution window, quorum, and a strict yes majority.

#### G-21
`require(isRegisteredReceiver(_receiver), "Invalid receiver")` · `src/dao/emissions/EmissionsController.sol:63` · Restricts receiver allocation fetches to registered receivers.

#### G-22
`require(totalWeight == BPS, "Total weight must be 100%")` · `src/dao/emissions/EmissionsController.sol:150` · Accepts a receiver-weight update only if aggregate stored weight remains 100%.

#### G-23
`if (_newWeights[i] > 0) require(receiver.active, "Receiver not active")` · `src/dao/emissions/EmissionsController.sol:137` · Prevents assigning positive emission weight to an inactive receiver.

#### G-24
`require(!isFinalized, "finalized")` · `src/dao/RetentionIncentives.sol:110` · Makes initial retention-balance loading single-use.

#### G-25
`require(isFinalized, "must finalize first")` · `src/dao/RetentionIncentives.sol:262` · Prevents reward-stream start before the retention weights are finalized.

#### G-26
`require(!initialized, "Already initialized")` · `src/dao/emissions/receivers/SimpleReceiver.sol:32` · Makes a receiver clone's initializer single-use.

#### G-27
`require(operator == msg.sender, "!operator")` · `src/protocol/FeeDeposit.sol:33` · Restricts fee withdrawal to the currently stored operator.

#### G-28
`require(currentEpoch > lastDistributedEpoch, "!new epoch")` · `src/protocol/FeeDeposit.sol:44` · Permits at most one fee-deposit distribution per epoch.

#### G-29
`require(_amount <= maxBurnableAssets(), "!minimumAssets")` · `src/protocol/InsurancePool.sol:202` · Preserves `minimumHeldAssets` during insurance burns.

#### G-30
`require(exitTime > 0 && block.timestamp >= exitTime, "!withdraw time")` · `src/protocol/InsurancePool.sol:305` · Requires a queued and matured insurance-pool exit.

#### G-31
`require(block.timestamp <= exitTime + withdrawTimeLimit, "withdraw time over")` · `src/protocol/InsurancePool.sol:306` · Restricts insurance withdrawal to the configured window.

#### G-32
`require(withdrawQueue[_account] == 0, "claim while queued")` · `src/protocol/InsurancePool.sol:353` · Blocks reward claims while the account is queued to withdraw.

#### G-33
`if (!_isSolvent(_borrower, _exchangeRateInfo.exchangeRate)) revert Insolvent(totalBorrow.toAmount(_userBorrowShares[_borrower], true), _userCollateralBalance[_borrower], _exchangeRateInfo.exchangeRate)` · `src/protocol/pair/ResupplyPairCore.sol:301` · Reverts borrow/collateral mutations that leave the borrower above `maxLTV`.

#### G-34
`if (_assetsAvailable < debtForMint) revert InsufficientDebtAvailable(_assetsAvailable, debtForMint)` · `src/protocol/pair/ResupplyPairCore.sol:648` · Caps new debt plus mint fee by the stored borrow limit.

#### G-35
`if (debtReduction > _totalBorrow.amount || _totalBorrow.amount - debtReduction < minimumLeftoverDebt) revert InsufficientDebtToRedeem()` · `src/protocol/pair/ResupplyPairCore.sol:941` · Preserves the configured debt remainder on redemption.

#### G-36
`if (msg.sender != IResupplyRegistry(registry).redemptionHandler()) revert InvalidRedemptionHandler()` · `src/protocol/pair/ResupplyPairCore.sol:918` · Restricts pair redemption accounting to the registry handler.

#### G-37
`if (msg.sender != liquidationHandler) revert InvalidLiquidator()` · `src/protocol/pair/ResupplyPairCore.sol:997` · Restricts pair liquidation to the registry handler.

#### G-38
`if (!swappers[_swapperAddress]) revert BadSwapper()` · `src/protocol/pair/ResupplyPairCore.sol:1103` · Restricts leverage swaps to stored approved swappers.

#### G-39
`if (_amountCollateralOut < _amountCollateralOutMin) revert SlippageTooHigh(_amountCollateralOutMin, _amountCollateralOut)` · `src/protocol/pair/ResupplyPairCore.sol:1137` · Enforces leverage output slippage against the observed balance delta.

#### G-40
`if (currentEpoch <= lastFeeEpoch || currentEpoch != lastDistributedEpoch) revert FeesAlreadyDistributed()` · `src/protocol/ResupplyPair.sol:322` · Permits one pair-fee withdrawal only after the fee deposit has distributed that epoch.

#### G-41
`require(_fee <= 1e18, "fee too high"); require(_fee >= maxDiscount, "fee higher than max discount")` · `src/protocol/RedemptionHandler.sol:75` · Bounds the stored base redemption fee and preserves `baseRedemptionFee >= maxDiscount`.

#### G-42
`require(feePct <= _maxFeePct, "fee > maxFee")` · `src/protocol/RedemptionHandler.sol:257` · Enforces the redeemer's maximum accepted fee before state and pair redemption calls.

#### G-43
`require(_insuranceSplit + _treasurySplit + _platformSplit + _stakedStableSplit == BPS, "invalid splits")` · `src/protocol/FeeDepositController.sol:178` · Accepts only complete 100% fee split configurations.

#### G-44
`require(IResupplyRegistry(registry).pairsByName(IERC20Metadata(msg.sender).name()) == msg.sender, "!regPair")` · `src/protocol/FeeDeposit.sol:55` · Restricts pair-revenue logging to a registered pair.

#### G-45
`require(IResupplyRegistry(registry).liquidationHandler() == address(this), "!liq handler")` · `src/protocol/LiquidationHandler.sol:144` · Stops collateral processing if the contract is no longer the active handler.

#### G-46
`require(!approvalsRevoked, "approvals revoked")` · `src/protocol/swappers/RouterSwapper.sol:36` · Disables router swaps after the irreversible approval revocation.

#### G-47
`if (useOperators && !operators[msg.sender]) revert TreasuryStableDiversification_NotOperator(msg.sender)` · `src/dao/TreasuryStableDiversification.sol:166` · Restricts permissionless diversification when operator mode is enabled.

#### G-48
`if (received < minOut) revert TreasuryStableDiversification_InsufficientOutput(target.token, minOut, received)` · `src/dao/TreasuryStableDiversification.sol:212` · Enforces target-specific oracle/PPS minimum output after a diversification swap.

#### G-49
`require(currentBorrowLimit >= limitInfo.prevBorrowLimit && currentBorrowLimit <= limitInfo.targetBorrowLimit, "current borrow limit outside of range")` · `src/dao/operators/BorrowLimitController.sol:68` · Continues a ramp only while the pair limit remains inside its stored ramp interval.

#### G-50
`require(balance >= totalOwed + minProfit, "not profitable")` · `src/dao/operators/RedemptionOperator.sol:362` · Requires the flash-cycle balance to cover lender principal/fee plus configured profit.

#### G-51
`require(!stateMigrated, "state already migrated")` · `src/protocol/RewardHandler.sol:234` · Makes reward-handler state migration single-use.

#### G-52
`require(operators[msg.sender] || msg.sender == owner(), "!authorized")` · `src/protocol/Stablecoin.sol:39` · Restricts reUSD minting to a stored operator or owner.

---

## 2. Inferred Invariants (Single-Contract)

Inferred invariants come from Δ-pairs, guard lifts checked against every write site, state-machine edges, temporal predicates, and exact ratio formulas. `On-chain` records whether every in-scope mutation path enforces the property.

#### I-1

`Conservation` · On-chain: **Yes**

> `GovStaker.totalSupply() == Σ GovStaker.balanceOf(account)` over staked, non-cooldown balances.

**Derivation** — **Δ-pair:** `_stake` adds the same `_amount` to an account's `pendingStake` and `_totalSupply` (`src/dao/staking/GovStaker.sol:100`, `src/dao/staking/GovStaker.sol:104`). `_cooldown` subtracts the same `_amount` from `realizedStake` and `_totalSupply` (`src/dao/staking/GovStaker.sol:139`, `src/dao/staking/GovStaker.sol:145`). Checkpointing only moves pending stake into realized stake without changing their sum (`src/dao/staking/GovStaker.sol:247`). These are all write families for the compared quantities.

**If violated** — Staking weight and reward supply would cease to represent the sum of account stake.

#### I-2

`Conservation` · On-chain: **No**

> `RetentionIncentives.totalSupply() == Σ RetentionIncentives.balanceOf(account)`.

**Derivation** — **Δ-pair + all-write-site enumeration:** ongoing decreases pair `_balances[_account] = ipShares` with `_totalSupply = _totalSupply + ipShares - currentBalance` (`src/dao/RetentionIncentives.sol:163`, `src/dao/RetentionIncentives.sol:169`). Initial loading instead assigns each mapping value but adds every list item to the scalar (`src/dao/RetentionIncentives.sol:118`, `src/dao/RetentionIncentives.sol:120`); no uniqueness guard exists for `_addressList`, so repeated addresses can overwrite the mapping while being counted repeatedly in `_totalSupply`.

**If violated** — Reward-per-weight calculations use a scalar supply larger than the sum of address weights.

#### I-3

`Conservation` · On-chain: **Yes**

> `SimpleRewardStreamer.totalSupply() == Σ SimpleRewardStreamer.balanceOf(account)`.

**Derivation** — **Δ-pair:** `_setWeight` is the only writer: it subtracts the account's prior balance from the scalar, writes the new balance, then adds that new balance back to the scalar (`src/protocol/SimpleRewardStreamer.sol:160`, `src/protocol/SimpleRewardStreamer.sol:167`).

**If violated** — Reward-per-token would use a denominator inconsistent with account weights.

#### I-4

`Bound` · On-chain: **Yes**

> `CurveLendOperator.mintedAmount >= CurveLendOperator.mintLimit` after initialization.

**Derivation** — **Guard lift:** `require(mintedAmount > mintLimit, "can not reduce")` at `src/dao/CurveLendOperator.sol:100`. All write sites are `_setMintLimit`, which writes the limit and increments `mintedAmount` by the exact shortfall when necessary (`src/dao/CurveLendOperator.sol:76`, `src/dao/CurveLendOperator.sol:80`, `src/dao/CurveLendOperator.sol:86`), and `reduceAmount`, which clamps the subtraction to `mintedAmount - mintLimit` (`src/dao/CurveLendOperator.sol:102`, `src/dao/CurveLendOperator.sol:109`).

**If violated** — The operator's accounted market principal would be below its configured floor.

#### I-5

`Ratio` · On-chain: **Yes**

> `splits.insurance + splits.treasury + splits.platform + splits.stakedStable == 10_000`.

**Derivation** — **Guard lift:** `_setSplits` begins at `src/protocol/FeeDepositController.sol:177` and applies `require(_insuranceSplit + _treasurySplit + _platformSplit + _stakedStableSplit == BPS, "invalid splits")` at `src/protocol/FeeDepositController.sol:178`. Constructor setup and the external setter are the complete write-site set and both route through `_setSplits` before all four fields are written (`src/protocol/FeeDepositController.sol:65`, `src/protocol/FeeDepositController.sol:173`, `src/protocol/FeeDepositController.sol:179`).

**If violated** — Configured fee destinations would under- or over-allocate the residual fee balance.

#### I-6

`Ratio` · On-chain: **Yes**

> The sum of all stored `EmissionsController` receiver weights is exactly `BPS == 10_000` once a first receiver exists.

**Derivation** — **Guard lift:** `require(totalWeight == BPS, "Total weight must be 100%")` at `src/dao/emissions/EmissionsController.sol:150`. Registration, the only other write family, gives the first receiver 10,000 and every later receiver zero (`src/dao/emissions/EmissionsController.sol:159`, `src/dao/emissions/EmissionsController.sol:169`); the update writer adjusts a running total for every old/new delta before storing (`src/dao/emissions/EmissionsController.sol:130`, `src/dao/emissions/EmissionsController.sol:148`).

**If violated** — Per-epoch receiver allocations would not describe a complete 100% partition.

#### I-7

`Bound` · On-chain: **Yes**

> For every vest, `0 <= claimed <= vestedAmount(now) <= amount`.

**Derivation** — **Guard lift:** checked subtraction in `_claimableAmount`, `uint112(_vestedAmount(vest) - vest.claimed)`, is the implicit revert guard at `src/dao/tge/VestManagerBase.sol:186`. Vest creation initializes `claimed` to zero and only increases `amount` for a matching duration (`src/dao/tge/VestManagerBase.sol:51`, `src/dao/tge/VestManagerBase.sol:60`); `_vestedAmount` is zero, full `amount`, or the linear fraction `amount * elapsed / duration` (`src/dao/tge/VestManagerBase.sol:190`), and the only claimed writer adds the checked difference (`src/dao/tge/VestManagerBase.sol:116`, `src/dao/tge/VestManagerBase.sol:118`).

**If violated** — A vest could expose more claimable RSUP than its allocation or regress claimed state.

#### I-8

`StateMachine` · On-chain: **Yes**

> `VestManager.initialized` transitions only `false -> true`.

**Derivation** — **Edge:** `initialized == false` at `src/dao/tge/VestManager.sol:74` → `initialized = true` at `src/dao/tge/VestManager.sol:75`; the all-write-site scan found no production reset.

**If violated** — Initialization allocations and redemption ratios could be recomputed.

#### I-9

`StateMachine` · On-chain: **Yes**

> Each `(account, AllocationType)` Merkle claim transitions `hasClaimed` only `false -> true`.

**Derivation** — **Edge:** `hasClaimed[_account][_type] == false` at `src/dao/tge/VestManager.sol:149` → proof verification at `src/dao/tge/VestManager.sol:151` → `hasClaimed[_account][_type] = true` after vest creation at `src/dao/tge/VestManager.sol:162`; no reset writer exists.

**If violated** — The same leaf allocation could create more than one vest.

#### I-10

`StateMachine` · On-chain: **Yes**

> The lock-penalty Merkle root can transition from zero to a value only once.

**Derivation** — **Edge:** `merkleRootByType[AIRDROP_LOCK_PENALTY] == bytes32(0)` at `src/dao/tge/VestManager.sol:125` → `_root` at `src/dao/tge/VestManager.sol:126`; initialization is the only earlier root write (`src/dao/tge/VestManager.sol:101`) and no path returns it to zero.

**If violated** — Eligibility for the finalized lock-penalty distribution could change again.

#### I-11

`StateMachine` · On-chain: **Yes**

> `accountData[account].isPermaStaker` transitions only `false -> true`.

**Derivation** — **Edge:** commitment starts at `src/dao/staking/GovStaker.sol:400`, requires `isPermaStaker == false` at `src/dao/staking/GovStaker.sol:401`, and writes `true` at `src/dao/staking/GovStaker.sol:402`. Account checkpoint reconstruction preserves the prior flag (`src/dao/staking/GovStaker.sol:247`, `src/dao/staking/GovStaker.sol:251`), and no writer sets false.

**If violated** — An account described as permanently staked could regain ordinary cooldown access.

#### I-12

`StateMachine` · On-chain: **Yes**

> An account can populate only one vote record per proposal.

**Derivation** — **Edge:** zero yes/no vote weights at `src/dao/Voter.sol:218`–`src/dao/Voter.sol:219` → the computed stored vote pair at `src/dao/Voter.sol:231`; there is no clearing writer.

**If violated** — Proposal result weights could include the same account more than once.

#### I-13

`StateMachine` · On-chain: **Yes**

> A proposal's `processed` flag transitions only `false -> true`.

**Derivation** — **Edge:** proposal creation writes `processed: false` at `src/dao/Voter.sol:177`–`src/dao/Voter.sol:181`; cancellation writes true after an unprocessed guard (`src/dao/Voter.sol:251`, `src/dao/Voter.sol:253`) and execution writes true after `_canExecute` (`src/dao/Voter.sol:291`, `src/dao/Voter.sol:292`). No writer resets it.

**If violated** — A cancelled or executed payload could return to an executable state.

#### I-14

`StateMachine` · On-chain: **Yes**

> `GovToken.minterFinalized` transitions only `false -> true`, after which `minter` is immutable.

**Derivation** — **Edge:** `setMinter` and `finalizeMinter` begin at `src/dao/GovToken.sol:52` and `src/dao/GovToken.sol:58`, require `minterFinalized == false` at `src/dao/GovToken.sol:53` and `src/dao/GovToken.sol:59`, then finalization writes true at `src/dao/GovToken.sol:60`; no false writer exists.

**If violated** — The authority controlling all future `globalSupply` growth could change after finalization.

#### I-15

`StateMachine` · On-chain: **Yes**

> `CurveLendOperator.market` is initialized exactly once.

**Derivation** — **Edge:** `initialize` begins at `src/dao/CurveLendOperator.sol:49`, requires `market == address(0)` at `src/dao/CurveLendOperator.sol:50`, then writes `market = _market` at `src/dao/CurveLendOperator.sol:51`; the all-write-site scan found no other production writer.

**If violated** — Operator accounting could be redirected to a different ERC-4626 market.

#### I-16

`StateMachine` · On-chain: **Yes**

> A `MultiRewardsDistributor` reward token can move from unregistered (`rewardsDuration == 0`) to registered only once.

**Derivation** — **Edge:** registration requires a positive input at `src/dao/staking/MultiRewardsDistributor.sol:127`, then requires stored `rewardsDuration == 0` through the inverse duplicate guard at `src/dao/staking/MultiRewardsDistributor.sol:128` and writes `_rewardsDuration` at `src/dao/staking/MultiRewardsDistributor.sol:134`. The only later duration writer also requires a nonzero input (`src/dao/staking/MultiRewardsDistributor.sol:190`, `src/dao/staking/MultiRewardsDistributor.sol:204`), so no path returns to zero.

**If violated** — Reward index/distributor accounting could be duplicated for one token.

#### I-17

`StateMachine` · On-chain: **Yes**

> `RouterSwapper.approvalsRevoked` transitions only `false -> true`.

**Derivation** — **Edge:** `revokeApprovals` starts at `src/protocol/swappers/RouterSwapper.sol:53` and moves the initial false value to `approvalsRevoked = true` at `src/protocol/swappers/RouterSwapper.sol:54`; the same path clears all enumerated approvals through `src/protocol/swappers/RouterSwapper.sol:60`, no false writer exists, and both swapping and approval updates test the latch (`src/protocol/swappers/RouterSwapper.sol:36`, `src/protocol/swappers/RouterSwapper.sol:68`).

**If violated** — The router could spend assets again after emergency revocation.

#### I-18

`StateMachine` · On-chain: **Yes**

> `RewardHandler.stateMigrated` transitions only `false -> true`.

**Derivation** — **Edge:** migration begins at `src/protocol/RewardHandler.sol:233`, requires `stateMigrated == false` at `src/protocol/RewardHandler.sol:234`, then writes true at `src/protocol/RewardHandler.sol:235`; no reset writer exists.

**If violated** — Old-handler timestamps and minimum weights could be imported repeatedly.

#### I-19

`StateMachine` · On-chain: **Yes**

> A `SimpleReceiver` storage instance can be initialized at most once.

**Derivation** — **Edge:** a clone's initializer begins at `src/dao/emissions/receivers/SimpleReceiver.sol:30`, requires its zero-initialized `initialized == false` at `src/dao/emissions/receivers/SimpleReceiver.sol:32`, then writes true at `src/dao/emissions/receivers/SimpleReceiver.sol:33`. The implementation constructor separately latches its own storage true (`src/dao/emissions/receivers/SimpleReceiver.sol:24`, `src/dao/emissions/receivers/SimpleReceiver.sol:27`); no false writer exists.

**If violated** — Receiver name and initial claimer set could be replaced by reinitialization.

#### I-20

`Temporal` · On-chain: **Yes**

> `FeeDeposit.lastDistributedEpoch` is strictly increasing and can be written at most once per epoch.

**Derivation** — **Temporal:** `currentEpoch` is snapshotted at `src/protocol/FeeDeposit.sol:43`; `require(currentEpoch > lastDistributedEpoch, "!new epoch")` at `src/protocol/FeeDeposit.sol:44` is checked before `lastDistributedEpoch = currentEpoch` at `src/protocol/FeeDeposit.sol:46`; this is the only writer.

**If violated** — One epoch's fee-deposit balance could be pulled repeatedly.

#### I-21

`Temporal` · On-chain: **Yes**

> Successive `PriceWatcher` observations appended by `updatePriceData` are at least `UPDATE_INTERVAL == 6 hours` apart.

**Derivation** — **Temporal:** the current timestamp is snapshotted at `src/protocol/PriceWatcher.sol:67`; `if (timedifference < UPDATE_INTERVAL) return` at `src/protocol/PriceWatcher.sol:72` is checked before the timestamp is appended at `src/protocol/PriceWatcher.sol:74`; the constructor's explicit zero sentinel is the sole non-live-time seed (`src/protocol/PriceWatcher.sol:38`).

**If violated** — Cumulative price-weight observations would not retain their intended minimum spacing.

#### I-22

`Temporal` · On-chain: **Yes**

> A nonzero `GovStaker.cooldowns[account]` is withdrawable only after its stored `end`, unless cooldowns are globally disabled.

**Derivation** — **Temporal:** cooldown stores `end = block.timestamp + cooldownEpochs * epochLength` at `src/dao/staking/GovStaker.sol:147`–`src/dao/staking/GovStaker.sol:150`; `_unstake` checks `if (block.timestamp < userCooldown.end && cooldownEpochs != 0) revert InvalidCooldown()` before deleting state and withdrawing (`src/dao/staking/GovStaker.sol:163`, `src/dao/staking/GovStaker.sol:168`).

**If violated** — Escrowed stake could leave before the configured delay.

#### I-23

`Temporal` · On-chain: **Yes**

> An `InsurancePool` exit is redeemable only in `[withdrawQueue[account], withdrawQueue[account] + withdrawTimeLimit]`.

**Derivation** — **Temporal:** `exit` stores `block.timestamp + withdrawTime` (`src/protocol/InsurancePool.sol:255`, `src/protocol/InsurancePool.sol:267`). Both withdrawal routes check `exitTime > 0 && block.timestamp >= exitTime` and `block.timestamp <= exitTime + withdrawTimeLimit` at `src/protocol/InsurancePool.sol:303`–`src/protocol/InsurancePool.sol:306` before `_clearWithdrawQueue` writes zero (`src/protocol/InsurancePool.sol:299`).

**If violated** — Insurance shares could exit before cooldown or after the withdrawal window.

#### I-24

`Temporal` · On-chain: **Yes**

> A voter proposal accepts votes only before `createdAt + VOTING_PERIOD` and executes only from `createdAt + VOTING_PERIOD + EXECUTION_DELAY` through `createdAt + EXECUTION_DEADLINE`.

**Derivation** — **Temporal:** creation snapshots `createdAt` at `src/dao/Voter.sol:177`–`src/dao/Voter.sol:179`; voting checks `proposal.createdAt + VOTING_PERIOD > block.timestamp` at `src/dao/Voter.sol:223`, and `_canExecute` checks both execution-window boundaries and processed state at `src/dao/Voter.sol:309`–`src/dao/Voter.sol:311`.

**If violated** — Proposal state transitions would occur outside their stored governance windows.

#### I-25

`Temporal` · On-chain: **Yes**

> `ResupplyPair.lastFeeEpoch` is strictly increasing, and a pair can withdraw fees only for the epoch already distributed by `FeeDeposit`.

**Derivation** — **Temporal:** `if (currentEpoch <= lastFeeEpoch || currentEpoch != lastDistributedEpoch) revert FeesAlreadyDistributed()` at `src/protocol/ResupplyPair.sol:327` is checked before `lastFeeEpoch = currentEpoch` at `src/protocol/ResupplyPair.sol:331`; `src/protocol/ResupplyPair.sol:322` supplies the external epoch snapshot and this is the only local writer.

**If violated** — Pair fees could be minted twice or entered the deposit out of epoch order.

#### I-26

`Ratio` · On-chain: **Yes**

> Each `SimpleRewardStreamer` cycle sets `rewardRate = (new reward + undistributed leftover) / duration` and `periodFinish = block.timestamp + duration`.

**Derivation** — **Temporal:** the `block.timestamp >= periodFinish` branch at `src/protocol/SimpleRewardStreamer.sol:243` selects either the new reward or `(periodFinish - block.timestamp) * old rewardRate` carryover before division by `duration` through `src/protocol/SimpleRewardStreamer.sol:251`; the same update stores current time and `block.timestamp + duration` at `src/protocol/SimpleRewardStreamer.sol:252`–`src/protocol/SimpleRewardStreamer.sol:254`.

**If violated** — Streamed reward accrual would not match the queued-plus-leftover cycle amount, modulo division dust.

#### I-27

`Ratio` · On-chain: **Yes**

> `LinearRewardsErc4626.totalAssets()` equals `storedTotalAssets + previewDistributeRewards()`, where the preview is the current cycle's linear pro-rata reward through the earlier of now and `cycleEnd`.

**Derivation** — **Temporal:** `calculateRewardsToDistribute` uses `rewardCycleAmount * deltaTime / (cycleEnd - lastSync)` from the pre-write cycle snapshot (`src/protocol/sreusd/LinearRewardsErc4626.sol:83`, `src/protocol/sreusd/LinearRewardsErc4626.sol:89`). Preview clamps elapsed time to the stored `cycleEnd` before any state write (`src/protocol/sreusd/LinearRewardsErc4626.sol:101`, `src/protocol/sreusd/LinearRewardsErc4626.sol:109`), and `totalAssets` adds that result to `storedTotalAssets` (`src/protocol/sreusd/LinearRewardsErc4626.sol:188`, `src/protocol/sreusd/LinearRewardsErc4626.sol:190`).

**If violated** — ERC-4626 conversion previews would omit or overstate currently released rewards.

#### I-28

`Conservation` · On-chain: **Yes**

> `SavingsReUSD._debit` and `_credit` preserve local-chain share `totalSupply` by moving equal deltas between a user and `address(this)`.

**Derivation** — **Δ-pair:** debit subtracts `amountSentLD` from `_from` and adds the identical amount to the contract (`src/protocol/sreusd/sreUSD.sol:150`, `src/protocol/sreusd/sreUSD.sol:157`). Credit subtracts `_amountLD` from the contract and adds the identical amount to `_to` (`src/protocol/sreusd/sreUSD.sol:176`, `src/protocol/sreusd/sreUSD.sol:186`). Neither path writes supply.

**If violated** — Cross-chain share transport would alter the vault's local share-supply accounting.

#### I-29

`Conservation` · On-chain: **Yes**

> During `TreasuryStableDiversification.swap`, all default-asset targets consume exactly the snapshotted `assetAmount`; earlier targets receive `assetAmount * weight / totalWeight`, and the last receives the residual.

**Derivation** — **Δ-pair:** `setTargets` sums every default-asset target weight into `totalWeight` and rejects zero weight for such targets (`src/dao/TreasuryStableDiversification.sol:127`, `src/dao/TreasuryStableDiversification.sol:157`, `src/dao/TreasuryStableDiversification.sol:161`). `swap` snapshots `assetAmount`, sets `remainingAssets`, assigns the exact residual to the final default target, and otherwise pairs each `sourceAmount` allocation with `remainingAssets -= sourceAmount` (`src/dao/TreasuryStableDiversification.sol:180`, `src/dao/TreasuryStableDiversification.sol:191`, `src/dao/TreasuryStableDiversification.sol:194`).

**If violated** — Default-asset diversification legs would double-use or strand part of the snapshotted input.

#### I-30

`Conservation` · On-chain: **Yes**

> On pair borrowing, `ΔtotalBorrow.amount == minted debtToken amount + ΔclaimableOtherFees` (the mint fee), while `ΔtotalBorrow.shares == Δ_userBorrowShares[borrower]`.

**Derivation** — **Δ-pair:** `_borrow` computes `debtForMint = borrowAmount * (LIQ_PRECISION + mintFee) / LIQ_PRECISION`, increases total amount by `debtForMint`, and increases total and user shares by the same `_sharesAdded` (`src/protocol/pair/ResupplyPairCore.sol:645`, `src/protocol/pair/ResupplyPairCore.sol:660`, `src/protocol/pair/ResupplyPairCore.sol:665`). It records `debtForMint - borrowAmount` as other fees and mints exactly `borrowAmount` (`src/protocol/pair/ResupplyPairCore.sol:667`, `src/protocol/pair/ResupplyPairCore.sol:671`).

**If violated** — Issued reUSD, fee receivables, and borrower debt would not reconcile for a borrow.

#### I-31

`Conservation` · On-chain: **Yes**

> On every successful pair redemption, `debtReduction + protocolFee == amount`, and `valueToRedeem == amount * (1e18 - totalFeePct) / 1e18`.

**Derivation** — **Δ-pair:** the pair computes `valueToRedeem`, derives `protocolFee` from the fee portion, and defines `debtReduction = amount - protocolFee` (`src/protocol/pair/ResupplyPairCore.sol:935`, `src/protocol/pair/ResupplyPairCore.sol:937`). It subtracts debt reduction, adds protocol fee to claimable fees, and emits all values (`src/protocol/pair/ResupplyPairCore.sol:945`, `src/protocol/pair/ResupplyPairCore.sol:957`, `src/protocol/pair/ResupplyPairCore.sol:972`). Arithmetic outside the successful range reverts.

**If violated** — A redeemed stablecoin unit would be neither retired from pair debt nor represented as a protocol fee.

#### I-32

`Conservation` · On-chain: **Yes**

> A completed `RedemptionOperator` flash cycle retains no operator-local accounting for principal or profit; the observed loan-asset balance is partitioned into `totalOwed` to the lender and the entire remainder to treasury.

**Derivation** — **Δ-pair (negative conservation):** after all swaps/redemptions, the operator snapshots `balance`, requires `balance >= totalOwed + minProfit`, transfers `totalOwed` to the lender, defines `profit = balance - totalOwed`, and transfers that remainder to treasury (`src/dao/operators/RedemptionOperator.sol:360`, `src/dao/operators/RedemptionOperator.sol:374`). There is zero operator storage Δ for either amount; conservation is entirely in token balance movement.

**If violated** — The flash callback would complete with loan-asset value outside the lender/treasury partition.

#### I-33

`Ratio` · On-chain: **Yes**

> For each registered `MultiRewardsDistributor` token, a notification sets `rewardRate = (new reward + undistributed leftover) / rewardsDuration` and `periodFinish = block.timestamp + rewardsDuration`.

**Derivation** — **Temporal:** the `block.timestamp >= periodFinish` branch at `src/dao/staking/MultiRewardsDistributor.sol:158` selects either `_rewardAmount` or `(periodFinish - block.timestamp) * old rewardRate` carryover before division by stored duration through `src/dao/staking/MultiRewardsDistributor.sol:164`; it then stores the rate, current time, and new finish at `src/dao/staking/MultiRewardsDistributor.sol:174`–`src/dao/staking/MultiRewardsDistributor.sol:177`.

**If violated** — A staking reward stream would not correspond to the newly funded reward plus its unvested carryover, modulo division dust.

**Categories:**

- **Conservation** — two or more storage/accounting quantities change by paired deltas or a flow intentionally has zero local storage delta.
- **Bound** — every in-scope writer preserves a lifted storage bound.
- **Ratio** — a stored or returned quantity is defined by an exact formula over stored snapshots.
- **StateMachine** — a stored value follows a guarded one-way transition with no reverse writer.
- **Temporal** — a stored timestamp, epoch, or duration constrains when a transition can occur.

---

## 3. Inferred Invariants (Cross-Contract)

Trust assumptions that span contract boundaries. Every block cites both the caller-side use and the in-scope callee-side behavior or write sites.

#### X-1

On-chain: **Yes**

> A successful callback claim transfers exactly `_claimed` RSUP to the callback and stakes that same amount for the resolved recipient.

**Caller side** — `src/dao/tge/VestManagerBase.sol:102`, `src/dao/tge/VestManagerBase.sol:105` — The vest manager increments claimed state, transfers `_claimed` to `_callback`, and requires `onClaim` to return true.

**Callee side** — `src/dao/staking/AutoStakeCallback.sol:30`, `src/dao/staking/AutoStakeCallback.sol:32`, `src/dao/staking/GovStaker.sol:100`, `src/dao/staking/GovStaker.sol:106` — The callback authenticates its immutable vest manager, forwards the same amount to `govStaker.stake(recipient, amount)`, and the staker accounts and pulls that amount; any failed leg reverts the transaction.

**If violated** — Callback-claimed RSUP would not map one-for-one into the recipient's stake.

#### X-2

On-chain: **No**

> Returning from `escrow.withdraw(receiver, amount)` implies that `amount` stake tokens were delivered to `receiver`.

**Caller side** — `src/dao/staking/GovStaker.sol:163`, `src/dao/staking/GovStaker.sol:168` — `_unstake` deletes cooldown state and calls `escrow.withdraw` without receiving a delivery result.

**Callee side** — `src/dao/staking/GovStakerEscrow.sol:15`, `src/dao/staking/GovStakerEscrow.sol:21` — The escrow authenticates the immutable staker but calls raw `IERC20.transfer` without checking its boolean return, so callee completion does not enforce delivery for a false-returning token.

**If violated** — Cooldown accounting can be cleared without the assumed token delivery signal being enforced.

#### X-3

On-chain: **Yes**

> `ReusdOracle._clamp` can safely compute `1e18 - baseRedemptionFee`, and the returned floor is `1e18 - baseRedemptionFee`.

**Caller side** — `src/protocol/ReusdOracle.sol:39`, `src/protocol/ReusdOracle.sol:44` — The oracle reads the handler's `baseRedemptionFee`, subtracts it from `1e18`, and uses the result as its price floor.

**Callee side** — `src/protocol/RedemptionHandler.sol:74`, `src/protocol/RedemptionHandler.sol:77` — The handler's sole setter requires `_fee <= 1e18` before writing; Solidity's initial value is zero.

**If violated** — Oracle clamping would revert or expose a floor inconsistent with handler configuration.

#### X-4

On-chain: **No**

> `PriceWatcher.findPairPriceWeight` is bounded by `1e6` when consumers use it as a 1e6-scaled fraction.

**Caller side** — `src/protocol/InterestRateCalculatorV2.sol:175`, `src/protocol/InterestRateCalculatorV2.sol:176`, `src/protocol/FeeDepositController.sol:130` — Both consumers divide products involving the returned weight by `1e6`.

**Callee side** — `src/protocol/PriceWatcher.sol:153`, `src/protocol/PriceWatcher.sol:159`, `src/protocol/RedemptionHandler.sol:74`, `src/protocol/RedemptionHandler.sol:77` — `getCurrentWeight` returns `(1e18 - price) / 1e10`, which can reach `1e8` at a zero price floor; the handler permits `baseRedemptionFee` up to `1e18`, so its setter does not impose a global 1% floor/`1e6` weight bound.

**If violated** — Off-peg rate and fee multipliers can exceed the range implied by treating weight as a bounded fraction.

#### X-5

On-chain: **Yes**

> Every `debtByCollateral[collateral]` decrease by `toBurn` is paired atomically with an insurance-pool burn of the same asset amount.

**Caller side** — `src/protocol/LiquidationHandler.sol:168`, `src/protocol/LiquidationHandler.sol:179`, `src/protocol/LiquidationHandler.sol:92`, `src/protocol/LiquidationHandler.sol:96` — The handler clamps `toBurn`, calls `burnAssets(toBurn)`, then subtracts the same delta; its only other decrease burns the full `collateralDebt` before writing the mapping to zero.

**Callee side** — `src/protocol/InsurancePool.sol:200`, `src/protocol/InsurancePool.sol:204` — The pool authenticates the active handler, rechecks `maxBurnableAssets`, and burns exactly `_amount`; any revert rolls back both sides.

**If violated** — Liquidation debt reduction would not equal the stablecoin assets burned from insurance.

#### X-6

On-chain: **Yes**

> A successful pair liquidation removes all borrower shares/debt and transfers the computed collateral before recording the identical debt amount in the liquidation handler.

**Caller side** — `src/protocol/pair/ResupplyPairCore.sol:1031`, `src/protocol/pair/ResupplyPairCore.sol:1056` — The pair derives `_amountLiquidatorToRepay`, calls `_repay` with a zero payer, removes collateral to the handler, then calls `processLiquidationDebt` with the same repayment amount.

**Callee side** — `src/protocol/LiquidationHandler.sol:116`, `src/protocol/LiquidationHandler.sol:122` — The handler authenticates the calling registered pair and adds exactly `_debtAmount` to `debtByCollateral`.

**If violated** — Liquidated pair debt would not be represented by handler debt awaiting an insurance burn.

#### X-7

On-chain: **Yes**

> A pair clears and mints its accumulated fees to `FeeDeposit` only after that deposit has advanced to the same epoch, and at most once for that pair/epoch.

**Caller side** — `src/protocol/ResupplyPair.sol:322`, `src/protocol/ResupplyPair.sol:339` — The pair reads the deposit epoch, requires equality plus a strictly older local `lastFeeEpoch`, writes the new epoch, clears both fee counters, and mints their sum to the deposit.

**Callee side** — `src/protocol/FeeDeposit.sol:42`, `src/protocol/FeeDeposit.sol:49` — The deposit requires a new epoch, stores it, and transfers its full preexisting balance to the operator before a pair can observe the new epoch.

**If violated** — Fee batches would overlap or enter the deposit before its prior balance was distributed.

#### X-8

On-chain: **Yes**

> `SimpleReceiver.claimEmissions(receiver)` transfers its entire currently allocated amount and reduces its controller allocation by that exact amount.

**Caller side** — `src/dao/emissions/receivers/SimpleReceiver.sol:51`, `src/dao/emissions/receivers/SimpleReceiver.sol:54` — The receiver fetches emissions, reads `allocated(address(this)).amount`, and passes that exact value to `transferFromAllocation`.

**Callee side** — `src/dao/emissions/EmissionsController.sol:210`, `src/dao/emissions/EmissionsController.sol:214` — The controller subtracts `_amount` from `allocated[msg.sender].amount` before transferring the same amount.

**If violated** — Receiver claimable accounting would diverge from governance-token delivery.

#### X-9

On-chain: **No**

> When a new vault reward cycle needs fees, `feeDeposit.operator()` is a callable `FeeDepositController` that is also authorized to call `FeeDeposit.distributeFees()`.

**Caller side** — `src/protocol/sreusd/LinearRewardsErc4626.sol:272`, `src/protocol/sreusd/LinearRewardsErc4626.sol:277` — `_distributeFees` reads the mutable operator, casts it to `IFeeDepositController`, and calls `distribute`.

**Callee side** — `src/protocol/FeeDepositController.sol:69`, `src/protocol/FeeDepositController.sol:72`, `src/protocol/FeeDeposit.sol:32`, `src/protocol/FeeDeposit.sol:37`, `src/protocol/FeeDeposit.sol:40` — The controller calls `feeDeposit.distributeFees`, whose guard requires `msg.sender == operator`, while `FeeDeposit.setOperator` can write any address without an interface or code check.

**If violated** — Vault reward-cycle synchronization cannot automatically pull and distribute the epoch's fees.

---

## 4. Economic Invariants

Higher-order properties derived from the verified §2 and §3 blocks.

#### E-1

On-chain: **Yes**

> A successful borrow adds borrower debt equal to newly issued reUSD plus the protocol's mint-fee receivable.

**Follows from** — `I-30`, whose Δ-pair proves the exact in-body issuance/fee partition and equal total/user share delta.

**If violated** — Protocol debt assets and liabilities would be created in unequal amounts.

#### E-2

On-chain: **Yes**

> A successful redemption partitions the input into pair debt retirement and protocol fee while collateral output is discounted by the effective redemption fee.

**Follows from** — `I-31` + `X-3`. `I-31` establishes `debtReduction + protocolFee == amount` and the collateral-value formula; `X-3` establishes the handler-configured oracle floor. The handler burns the full user input after the pair call (`src/protocol/RedemptionHandler.sol:268`, `src/protocol/RedemptionHandler.sol:275`).

**If violated** — Redeemed reUSD value would not reconcile with debt retirement, fee accrual, and collateral delivery.

#### E-3

On-chain: **Yes**

> Liquidated pair debt is first represented as `debtByCollateral` and is removed from that ledger only by an equal insurance-pool asset burn.

**Follows from** — `X-6` + `X-5`: pair-to-handler debt handoff followed by equal-delta handler debt reduction and insurance burn.

**If violated** — The system would either retire debt without burning insurance assets or burn insurance assets without retiring recorded liquidation debt.

#### E-4

On-chain: **Yes**

> Each fee-controller residual balance is completely assigned among insurance, treasury, staked-stable, and platform-staker destinations, modulo integer division dust absorbed by the platform remainder.

**Follows from** — `I-5` + `X-7`. `I-5` proves the configured BPS weights total 100%; the controller computes the first three splits and transfers `balance - ipAmount - treasuryAmount - stakedStableSplitAmount` as the platform remainder (`src/protocol/FeeDepositController.sol:136`, `src/protocol/FeeDepositController.sol:156`), while `X-7` proves epoch-ordered fee arrival.

**If violated** — An epoch's distributable fee balance would be over-assigned or left outside the destination partition.

#### E-5

On-chain: **Yes**

> For each emission epoch, registered receiver weights describe a complete 100% allocation partition; active receiver claims decrease controller allocation by exactly the governance tokens delivered.

**Follows from** — `I-6` + `X-8`. `I-6` proves aggregate weight is 10,000 BPS; allocation is `weight * emissionsPerEpoch / BPS` (`src/dao/emissions/EmissionsController.sol:237`, `src/dao/emissions/EmissionsController.sol:245`) with inactive shares moved to `unallocated` (`src/dao/emissions/EmissionsController.sol:248`), and `X-8` proves exact active-claim accounting.

**If violated** — Minted governance emissions would not reconcile with active allocations plus the explicit unallocated bucket, apart from per-receiver division dust.

#### E-6

On-chain: **Yes**

> Staking reward accrual uses a supply denominator equal to aggregate active stake, and each reward cycle streams its queued-plus-leftover amount over the configured duration.

**Follows from** — `I-1` + `I-33`: active-stake supply conservation plus the inherited `MultiRewardsDistributor` stream-reset formula.

**If violated** — Staking rewards would be distributed against a denominator or stream rate not backed by the recorded stake/reward cycle.

#### E-7

On-chain: **No**

> Savings reUSD can always advance a new linear-reward cycle using the epoch's fee distribution.

**Follows from** — `I-27` + `X-9`. `I-27` establishes how a valid cycle is streamed into `totalAssets`; `X-9` shows the automatic fee-distribution dependency is not enforced because the mutable fee-deposit operator can be non-controller or otherwise incompatible.

**If violated** — Pending fee rewards remain outside a newly synchronized cycle until the external operator configuration is repaired.
