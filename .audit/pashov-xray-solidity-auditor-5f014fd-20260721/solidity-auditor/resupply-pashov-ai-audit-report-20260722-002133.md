# 🔐 Security Review — resupply

---

## Scope

|                                  |                                                        |
| -------------------------------- | ------------------------------------------------------ |
| **Mode**                         | ALL / exact X-Ray production scope                     |
| **Files reviewed**               | `src/dao/Core.sol` · `src/dao/CurveLendMinterFactory.sol` · `src/dao/CurveLendOperator.sol`<br>`src/dao/GovToken.sol` · `src/dao/RetentionIncentives.sol` · `src/dao/Treasury.sol`<br>`src/dao/TreasuryStableDiversification.sol` · `src/dao/Voter.sol` · `src/dao/emissions/EmissionsController.sol`<br>`src/dao/emissions/receivers/RetentionReceiver.sol` · `src/dao/emissions/receivers/SimpleReceiver.sol` · `src/dao/emissions/receivers/SimpleReceiverFactory.sol`<br>`src/dao/operators/BaseUpgradeableOperator.sol` · `src/dao/operators/BorrowLimitController.sol` · `src/dao/operators/Guardian.sol`<br>`src/dao/operators/GuardianUpgradeable.sol` · `src/dao/operators/PairAdder.sol` · `src/dao/operators/RedemptionOperator.sol`<br>`src/dao/operators/TreasuryManager.sol` · `src/dao/operators/TreasuryManagerUpgradeable.sol` · `src/dao/operators/UpgradeOperator.sol`<br>`src/dao/operators/VeCrvOperator.sol` · `src/dao/staking/AutoStakeCallback.sol` · `src/dao/staking/GovStaker.sol`<br>`src/dao/staking/GovStakerEscrow.sol` · `src/dao/staking/MultiRewardsDistributor.sol` · `src/dao/tge/PermaStaker.sol`<br>`src/dao/tge/VestManager.sol` · `src/dao/tge/VestManagerBase.sol` · `src/dependencies/CoreOwnable.sol`<br>`src/dependencies/DelegatedOps.sol` · `src/dependencies/EpochTracker.sol` · `src/helpers/keepers/Keeper.sol`<br>`src/helpers/keepers/KeeperV1.sol` · `src/helpers/keepers/KeeperV2.sol` · `src/libraries/MathUtil.sol`<br>`src/libraries/SafeERC20.sol` · `src/libraries/VaultAccount.sol` · `src/protocol/BasicVaultOracle.sol`<br>`src/protocol/FeeDeposit.sol` · `src/protocol/FeeDepositController.sol` · `src/protocol/FeeLogger.sol`<br>`src/protocol/InsurancePool.sol` · `src/protocol/InterestRateCalculator.sol` · `src/protocol/InterestRateCalculatorV2.sol`<br>`src/protocol/LiquidationHandler.sol` · `src/protocol/PriceWatcher.sol` · `src/protocol/RedemptionHandler.sol`<br>`src/protocol/ResupplyPair.sol` · `src/protocol/ResupplyPairDeployer.sol` · `src/protocol/ResupplyRegistry.sol`<br>`src/protocol/ReusdOracle.sol` · `src/protocol/RewardDistributorMultiEpoch.sol` · `src/protocol/RewardHandler.sol`<br>`src/protocol/SimpleRewardStreamer.sol` · `src/protocol/Stablecoin.sol` · `src/protocol/Swapper.sol`<br>`src/protocol/UnderlyingOracle.sol` · `src/protocol/Utilities.sol` · `src/protocol/WriteOffToken.sol`<br>`src/protocol/pair/ResupplyPairConstants.sol` · `src/protocol/pair/ResupplyPairCore.sol` · `src/protocol/sreusd/LinearRewardsErc4626.sol`<br>`src/protocol/sreusd/sreUSD.sol` · `src/protocol/swappers/RouterSwapper.sol` |
| **Confidence threshold (1-100)** | 75                                                     |

---

## Findings

[100] **1. Partial insurance capacity causes liquidation recovery to make zero progress [agents: 5]**

`LiquidationHandler.processCollateral` · Confidence: 100

**Description**
The handler enters its redeem-and-burn branch only when the entire currently withdrawable amount fits the pre-redemption insurance capacity, so even fully usable partial capacity—and capacity created by the redemption itself—settles nothing.

**Fix (Option A — clamp before execution)**

```diff
- uint256 toBurn = withdrawable > collateralDebt ? collateralDebt : withdrawable;
- if (toBurn <= maxBurnable) {
+ uint256 toBurn = MathUtil.min(withdrawable, MathUtil.min(collateralDebt, maxBurnable));
+ if (toBurn != 0) {
```

**Fix (Option B — redeem then recompute)**

```diff
- if (toBurn <= maxBurnable) {
-     vault.redeem(..., insurancePool, address(this));
+ vault.redeem(..., insurancePool, address(this));
+ maxBurnable = insurancePool.maxBurnableAssets();
+ toBurn = MathUtil.min(withdrawnAmount, MathUtil.min(collateralDebt, maxBurnable));
+ if (toBurn != 0) {
```

---

[98] **2. Exited insurance depositors keep earning retention rewards at stale weight [agents: 2]**

`RetentionIncentives._updateReward` · Confidence: 98

**Description**
Insurance share burns are not coupled to retention checkpoints, and `_updateReward` credits the whole elapsed interval at the old weight before synchronizing the user's now-lower InsurancePool balance.

**Fix (Option A — atomic balance hook)**

```diff
+ retentionIncentives.user_checkpoint(owner);
  _burn(owner, shares);
+ retentionIncentives.user_checkpoint(owner);
```

**Fix (Option B — timestamped eligibility)**

```diff
- rewards[account] = earned(accountUsingStoredWeight);
+ rewards[account] = earnedAcrossInsuranceBalanceCheckpoints(account);
```

---

[95] **3. Replacement emissions schedules retain the old active rate and clock [agents: 3]**

`EmissionsController.setEmissionsSchedule` · Confidence: 95

**Description**
The setter replaces the queued rates and interval but leaves `emissionsRate` and `lastEmissionsUpdate` from the superseded plan, causing history-dependent over- or under-minting after a documented schedule replacement.

**Fix**

```diff
  emissionsSchedule = _rates;
+ emissionsRate = emissionsSchedule[emissionsSchedule.length - 1];
+ emissionsSchedule.pop();
+ lastEmissionsUpdate = getEpoch();
  epochsPer = _epochsPer;
```

---

[95] **4. Small liquidations can spend collateral backing earlier liquidation debt [agents: 3]**

`LiquidationHandler.processLiquidationDebt` · Confidence: 95

**Description**
The liquid incentive branch pays the fixed incentive from the handler's aggregate vault balance without capping it to collateral contributed by the current liquidation, cross-subsidizing searchers from earlier recoveries.

**Fix**

```diff
- if (withdrawable >= liquidateIncentive) {
-     vault.withdraw(liquidateIncentive, liquidationCaller, address(this));
+ uint256 currentAssets = vault.convertToAssets(collateralAmount);
+ uint256 incentive = MathUtil.min(liquidateIncentive, currentAssets);
+ if (withdrawable >= incentive) {
+     vault.withdraw(incentive, liquidationCaller, address(this));
```

---

[90] **5. Collateral solvency ignores downside depegs of the vault underlying [agents: 1]**

`BasicVaultOracle.getPrices` · Confidence: 90

**Description**
The oracle prices only ERC-4626 shares in underlying units and hard-pegs those units to reUSD, so a discounted supported stablecoin can mint near-par debt that never becomes insolvent on chain.

**Fix**

```diff
- price = vault.convertToAssets(1e18);
+ price = vault.convertToAssets(1e18) * validatedUnderlyingPriceInReUSD / 1e18;
+ require(price != 0 && underlyingAnswerIsFresh);
```

---

[90] **6. Expired redemption usage from inactive pairs suppresses concentration fees [agents: 1]**

`RedemptionHandler._getRedemptionFee` · Confidence: 90

**Description**
Only the selected pair's usage is decayed while `totalWeight` retains stale usage from untouched pairs, inflating the denominator and letting redeemers evade the intended overusage surcharge.

**Fix**

```diff
- uint256 total = totalWeight - selected.usage + decayedSelectedUsage;
+ uint256 total = currentGloballyDecayedUsage();
+ total = total - oldSelectedUsage + decayedSelectedUsage;
```

---

[90] **7. Permissionless checkpoint frequency changes the sreUSD reward cap [agents: 1]**

`SavingsReUSD.calculateRewardsToDistribute` · Confidence: 90

**Description**
Each checkpoint recomputes the cap from `storedTotalAssets` after prior releases, so frequent callers obtain discrete compounding and accelerate capped rewards relative to a single checkpoint over the same interval.

**Fix**

```diff
- maxDistribution = rate * deltaTime * storedTotalAssets / 1e18;
+ maxDistribution = cumulativeCycleCap(cycleStartAssets, block.timestamp)
+     - rewardsReleasedUnderCapThisCycle;
```

---

[80] **8. The frxUSD redemption oracle accepts stale or invalid legacy answers [agents: 2]**

`UnderlyingOracle.getPrices` · Confidence: 80

**Description**
The frxUSD branch uses `latestAnswer()` without positivity, timestamp, or round-completeness checks, allowing stale-low prices to omit the surcharge that protects collateral during above-par redemptions.

**Fix**

```diff
- price = uint256(feed.latestAnswer()) * 1e10;
+ (roundId, answer,, updatedAt, answeredInRound) = feed.latestRoundData();
+ require(answer > 0 && answeredInRound >= roundId && block.timestamp - updatedAt <= maxAge);
+ price = uint256(answer) * 1e10;
```

---

[80] **9. Updating the retention treasury rate reprices already elapsed epochs [agents: 1]**

`RetentionReceiver.setTreasuryAllocationPerEpoch` · Confidence: 80

**Description**
The permissionless catch-up claim multiplies every unclaimed historical epoch by the newly set rate, retroactively shifting value between treasury and beneficiaries after the epochs have elapsed.

**Fix**

```diff
  function setTreasuryAllocationPerEpoch(uint256 newRate) external onlyOwner {
+     _settleElapsedEpochs(treasuryAllocationPerEpoch);
      treasuryAllocationPerEpoch = newRate;
+     lastEpoch = getEpoch();
  }
```

---

[75] **10. Price weights can exceed every consumer's assumed six-decimal domain [agents: 3]**

`PriceWatcher.getCurrentWeight` · Confidence: 75

**Description**
A governance-valid redemption fee above 1% lets the watcher emit weights above `1e6`, while fee and interest consumers divide by `1e6` and can therefore exceed their configured multiplier bounds during a market depeg.

---

Findings List

| # | Confidence | Title |
|---|---|---|
| 1 | [100] | Partial insurance capacity causes liquidation recovery to make zero progress |
| 2 | [98] | Exited insurance depositors keep earning retention rewards at stale weight |
| 3 | [95] | Replacement emissions schedules retain the old active rate and clock |
| 4 | [95] | Small liquidations can spend collateral backing earlier liquidation debt |
| 5 | [90] | Collateral solvency ignores downside depegs of the vault underlying |
| 6 | [90] | Expired redemption usage from inactive pairs suppresses concentration fees |
| 7 | [90] | Permissionless checkpoint frequency changes the sreUSD reward cap |
| 8 | [80] | The frxUSD redemption oracle accepts stale or invalid legacy answers |
| 9 | [80] | Updating the retention treasury rate reprices already elapsed epochs |
| 10 | [75] | Price weights can exceed every consumer's assumed six-decimal domain |

---

## Leads

_Vulnerability trails with concrete code smells where the full exploit path could not be completed in one analysis pass. These are not false positives — they are high-signal leads for manual review. Not scored._

- **Zero vault price can freeze bad-debt processing** — `BasicVaultOracle.getPrices` — Code smells: zero is accepted before reciprocal exchange-rate math — Confirm whether every supported vault guarantees `convertToAssets(1e18) > 0` under catastrophic loss.
- **Permanent-stake migration has no enforced sender-side postcondition** — `GovStaker.migrateStake` — Code smells: value moves before an empty virtual hook, with no check that permanence survived — Confirm the concrete production successor and its migration behavior.
- **The production migration receiver hook is an unauthenticated no-op** — `GovStaker.onPermaStakeMigrate` — Code smells: deployable base implementation changes no state — Confirm whether governance can ever select an unmodified base staker as successor.
- **InsurancePool ERC-4626 maxima disagree with executable cooldown state** — `InsurancePool.maxDeposit/maxMint/maxWithdraw/maxRedeem` — Code smells: max views ignore queue readiness and expiry — Integrators can deterministically submit operations that the corresponding state-changing method rejects.
- **Keeper readiness omits profitable operator withdrawals** — `Keeper.canWork` — Code smells: `work` loops `withdraw_profit`, while `canWork` never checks it — Confirm whether automation treats `canWork == false` as a hard execution gate.
- **Savings exits synchronously depend on unrelated fee maintenance** — `LinearRewardsErc4626.syncRewardsAndDistribution` — Code smells: deposit/withdraw/redeem call an oracle/reward/fee pipeline at cycle rollover — Prove the operational fail-open policy for each external dependency.
- **The retired liquidation handler exposes no in-scope migration acceptor** — `LiquidationHandler.migrateCollateral` — Code smells: pull-only authorization to the new handler, but the replacement has no pull-and-book entry point — Confirm the actual migration helper and debt handoff procedure.
- **The L2 liquidation callback has no incentive beneficiary** — `LiquidationHandler.processLiquidationDebt` — Code smells: authorized L2-manager path never sets transient `_liquidationCaller` — Confirm whether the live L2 manager calls this function and how zero-recipient vault/token behavior is handled.
- **Price history search can underflow before the first observation** — `PriceWatcher.findPairPriceWeight` — Code smells: unbounded six-hour backward scan with zero as absence sentinel — Confirm migration timestamps for every watcher-backed pair.
- **Approved redemption bots choose the protocol's own economic bounds** — `RedemptionOperator.executeRedemption` — Code smells: caller-controlled zero profit/slippage floors and full-balance profitability — Confirm the bot trust model and whether manager-signed bounds exist off-chain.
- **Retention initialization is source-level permissionless and non-canonical** — `RetentionIncentives.setAddressBalances` — Code smells: first-caller finalization, duplicate-key supply inflation, no explicit length/uniqueness validation — The reviewed production deployment is atomically finalized, so only replacement/non-atomic deployments remain exposed.
- **Epoch zero can replay the retention claim sentinel** — `RetentionReceiver.claimEmissions` — Code smells: zero means both unclaimed and real epoch zero — Confirm whether any receiver can be funded and activated before epoch one.
- **Optional reward failures can block safety-critical checkpoints** — `RewardDistributorMultiEpoch._checkpoint` — Code smells: liquidation/repay/withdraw paths synchronously harvest external rewards — Establish an actual dependency failure mode and the affected deployed entry points.
- **A staker migration can leave revenue routed to the retired pool** — `RewardHandler.queueStakingRewards` — Code smells: immutable cached staker versus mutable registry staker — Confirm whether the production migration proposal atomically replaces every handler and drains pending balances.
- **Router calldata is unbound while allowances are unlimited** — `RouterSwapper.swap` — Code smells: public arbitrary low-level router call, ignored amount/token/recipient semantics — Prove a protocol-generated residual balance; self-funded or accidental donations alone do not establish victim loss.
- **Cross-chain savings shares are transported by count, not value** — `SavingsReUSD._debit/_credit` — Code smells: independent local PPS and destination inventory dependence — Confirm enabled peers, remote vault implementations, and liquidity seeding.
- **Configured swap routes spend the adapter's whole balance** — `Swapper.swap` — Code smells: public call, ignored `amountIn`, full-balance input, arbitrary recipient — Prove a protocol-generated residual balance outside the atomic pair call.
- **Custom-input-only diversification can strand a treasury asset pull** — `TreasuryStableDiversification.swap` — Code smells: valid zero-weight target set, unconditional default-asset pull, early continue — Confirm whether any live target configuration lacks a default-asset consumer.
- **Default-token aliasing can violate later-target reservation** — `TreasuryStableDiversification.swap / _isInputForLaterTarget` — Code smells: execution normalizes zero input to `asset`, dependency scan does not — Exercise the live multi-target ordering and recovery behavior.
- **The V1 interest helper drops the configured minimum rate** — `Utilities.getPairInterestRate` — Code smells: the second assignment overwrites the first maximum — Identify any production integrator that treats this off-chain helper as authoritative.
- **Reward-rate helpers appear over-scaled by `1e18`** — `Utilities.getPairRsupRate/getInsurancePoolRewardRates` — Code smells: `1e36` allocation padding followed by another per-share normalization — Confirm the UI/integrator scale contract before treating quote distortion as economic loss.
- **Legacy-token redemption does not enforce its documented aggregate maximum** — `VestManager.redeem` — Code smells: `_maxRedeemable` is used only as a ratio denominator — Confirm whether the combined redeemable supply or wrapper accounting can exceed the configured maximum.

---

> ⚠️ This review was performed by an AI assistant. AI analysis can never verify the complete absence of vulnerabilities and no guarantee of security is given. Team security reviews, bug bounty programs, and on-chain monitoring are strongly recommended. For a consultation regarding your projects' security, visit [https://www.pashov.com](https://www.pashov.com)
