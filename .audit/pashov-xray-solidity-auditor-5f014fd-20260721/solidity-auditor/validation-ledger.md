# Solidity Auditor validation ledger

Target: `5f014fd5003bba32c0cf2049992f57a768728631`  
Scope: 65 files / 8,109 nSLOC  
Raw inventory: 33 `FINDING` blocks + 34 `LEAD` blocks from 12 independent lanes.

`ALLOWS`, `BLOCKS`, `UNCERTAIN`, and `IRRELEVANT` are the fixed one-pass gate verdicts from `judging.md`. A lead is retained only where the code smell itself was confirmed but reachability, trigger, or material impact remains incomplete. Rejected candidates do not appear in the final report.

Completeness: **37 unique `(Contract, function)` tuples in raw, 37 dispositioned; 31 non-rejected raw function surfaces map to the final findings/leads.** The two EmissionsController tuple spellings map to one canonical finding because the helper was part of the same setter transition, while both raw records remain accounted for here.

| # | Raw `(Contract, function)` | Agents | Gate 1: execution | Gate 2: reachability | Gate 3: trigger | Gate 4: impact | Disposition |
|---:|---|---:|---|---|---|---|---|
| 1 | `BasicVaultOracle.getPrices` | 1 | ALLOWS | ALLOWS for stablecoin depeg; UNCERTAIN for zero-price total loss | ALLOWS for borrower | ALLOWS / UNCERTAIN | **F5** depeg + **L1** zero-price freeze |
| 2 | `EmissionsController.setEmissionsSchedule` | 2 | ALLOWS | ALLOWS during supported schedule replacement | ALLOWS via permissionless receiver call | ALLOWS: irreversible supply skew | **F3** |
| 3 | `EmissionsController.setEmissionsSchedule / _calcEmissionsForEpoch` | 1 | ALLOWS | ALLOWS | ALLOWS via permissionless receiver call | ALLOWS | **F3**, same transition; distinct raw tuple preserved |
| 4 | `GovStakerEscrow.withdraw` | 1 | BLOCKS for fixed `GovToken` behavior | — | — | — | **R1** fixed-token false-return precondition not established |
| 5 | `GovStaker.migrateStake` | 2 | ALLOWS | UNCERTAIN: successor implementation is future configuration | ALLOWS only after governance migration | UNCERTAIN | **L2** |
| 6 | `GovStaker.onPermaStakeMigrate` | 1 | ALLOWS | UNCERTAIN: live successor not shown to use base hook | ALLOWS only after governance migration | UNCERTAIN | **L3** |
| 7 | `InsurancePool.maxDeposit/maxMint/maxWithdraw/maxRedeem` | 1 | ALLOWS | ALLOWS under ordinary cooldown states | ALLOWS to any integrator/user | IRRELEVANT to direct loss; deterministic revert only | **L4** |
| 8 | `InterestRateCalculatorV2._getNewRate` | 1 | ALLOWS arithmetically | BLOCKS economically: requires an extreme, self-funded one-second vault jump | — | — | **R2** implausible/self-funded precondition |
| 9 | `Keeper.canWork` | 1 | ALLOWS | UNCERTAIN: off-chain automation policy not in scope | IRRELEVANT | UNCERTAIN | **L5** |
| 10 | `LinearRewardsErc4626.syncRewardsAndDistribution` | 1 | ALLOWS | UNCERTAIN: needs a concrete external failure | ALLOWS to ordinary vault user | ALLOWS if dependency fails | **L6** |
| 11 | `LiquidationHandler.migrateCollateral` | 1 | ALLOWS | UNCERTAIN: bespoke replacement/helper may exist out of scope | Requires privileged migration | ALLOWS operational stranding | **L7** |
| 12 | `LiquidationHandler.processCollateral` | 5 | ALLOWS | ALLOWS under ordinary partial reserve capacity | ALLOWS to any caller | ALLOWS: bad debt and collateral remain stuck | **F1**, PoC passed |
| 13 | `LiquidationHandler.processLiquidationDebt` | 4 | ALLOWS | ALLOWS for pooled collateral; UNCERTAIN for live L2 path | ALLOWS to permissionless liquidator / role-only L2 manager | ALLOWS / UNCERTAIN | **F4** cross-subsidy + **L8** zero beneficiary |
| 14 | `PriceWatcher.findPairPriceWeight` | 2 | ALLOWS | UNCERTAIN: requires a pre-history pair timestamp | ALLOWS through ordinary pair update | ALLOWS if migration state exists | **L9** |
| 15 | `PriceWatcher.getCurrentWeight` | 3 | ALLOWS | ALLOWS after a supported fee update and depeg | ALLOWS through user/keeper activity; asymmetric-formula amplifier | ALLOWS but configuration-specific | **F10**, confidence 75 |
| 16 | `RedemptionHandler._getRedemptionFee` | 1 | ALLOWS | ALLOWS as untouched pair usage ages | ALLOWS to permissionless redeemer | ALLOWS: surcharge evasion | **F6** |
| 17 | `RedemptionOperator.executeRedemption` | 1 | ALLOWS | ALLOWS for approved bot | UNCERTAIN: trusted role only | ALLOWS if bot is adversarial | **L10** |
| 18 | `ResupplyPairCore._calculateInterest` | 3 | ALLOWS arithmetically | BLOCKS economically at near-`uint128` system debt | — | — | **R3** implausible boundary |
| 19 | `ResupplyPairCore._calculateInterest / _addInterest` | 1 | ALLOWS arithmetically | BLOCKS economically at near-`uint128` system debt | — | — | **R4** same unreachable boundary, distinct raw tuple |
| 20 | `ResupplyPair._updateConvexPool` | 1 | ALLOWS | Requires privileged PID-zero configuration | BLOCKS: no unprivileged amplifier | — | **R5** admin-only operational action under strict gate |
| 21 | `RetentionIncentives._updateReward` | 2 | ALLOWS | ALLOWS after ordinary InsurancePool exit | ALLOWS to former depositor | ALLOWS: captures rewards without retained capital | **F2**, PoC passed |
| 22 | `RetentionIncentives.setAddressBalances` | 8 | ALLOWS on fresh instance | UNCERTAIN: production instance atomically finalized | ALLOWS only during non-atomic replacement deployment | ALLOWS if window exists | **L11** |
| 23 | `RetentionReceiver.claimEmissions` | 2 | ALLOWS | UNCERTAIN: requires funded/active receiver in epoch zero | ALLOWS to any caller | ALLOWS if deployment state exists | **L12** |
| 24 | `RetentionReceiver.setTreasuryAllocationPerEpoch` | 1 | ALLOWS | ALLOWS during ordinary rate update with unclaimed epochs | ALLOWS via permissionless retroactive claim | ALLOWS: treasury/beneficiary value shifts | **F9** |
| 25 | `RewardDistributorMultiEpoch._checkpoint` | 1 | ALLOWS | UNCERTAIN: concrete reward dependency failure not reproduced | ALLOWS to ordinary safety action | ALLOWS if failure exists | **L13** |
| 26 | `RewardHandler.queueStakingRewards` | 1 | ALLOWS | UNCERTAIN: production migration may atomically replace handler | ALLOWS to old-pool holdout after migration | ALLOWS if transition is incomplete | **L14** |
| 27 | `RouterSwapper.swap` | 3 | ALLOWS | UNCERTAIN: no protocol-generated residual balance proved | ALLOWS to any caller | BLOCKS for self-funded donation; UNCERTAIN otherwise | **L15** |
| 28 | `SavingsReUSD._debit/_credit` | 1 | ALLOWS | UNCERTAIN: peers, remote PPS, and escrow inventory not confirmed | ALLOWS to bridge user | ALLOWS if multi-chain state exists | **L16** |
| 29 | `SavingsReUSD.calculateRewardsToDistribute` | 1 | ALLOWS | ALLOWS in every capped reward cycle | ALLOWS to any checkpoint caller | ALLOWS: repeated, path-dependent release | **F7**, PoC passed |
| 30 | `Swapper.swap` | 3 | ALLOWS | UNCERTAIN: no protocol-generated residual balance proved | ALLOWS to any caller | BLOCKS for self-funded donation; UNCERTAIN otherwise | **L17** |
| 31 | `TreasuryStableDiversification.swap` | 1 | ALLOWS | UNCERTAIN: requires valid custom-input-only configuration | ALLOWS to any caller when operator mode is off | Bounded/recoverable custody displacement | **L18** |
| 32 | `TreasuryStableDiversification.swap / _isInputForLaterTarget` | 1 | ALLOWS | UNCERTAIN: requires affected multi-target ordering | ALLOWS to ordinary swap caller | Bounded revert/misallocation | **L19** |
| 33 | `UnderlyingOracle.getPrices` | 2 | ALLOWS | ALLOWS under stale/invalid feed state | ALLOWS to permissionless redeemer | ALLOWS: collateral over-redemption or availability failure | **F8** |
| 34 | `Utilities.getPairInterestRate` | 2 | ALLOWS | ALLOWS in V1 helper branch | IRRELEVANT to on-chain state | UNCERTAIN: consumer not identified | **L20** |
| 35 | `Utilities.getPairRsupRate,getInsurancePoolRewardRates` | 1 | ALLOWS | ALLOWS for every nonzero rate | IRRELEVANT to on-chain state | UNCERTAIN: scale contract with UI unknown | **L21** |
| 36 | `VestManager.redeem` | 1 | ALLOWS | UNCERTAIN: aggregate accepted-token availability above configured maximum not proved | ALLOWS to token holder | ALLOWS if supply exceeds cap | **L22** |
| 37 | `Voter.createNewProposal,_voteForProposal` | 1 | ALLOWS arithmetically | BLOCKS as a distinct exploit: requires roughly 70% stake at current quorum | — | — | **R6** economically redundant governance DoS |

## Validation execution

The isolated worktree installed the commit's declared npm dependencies and successfully compiled the targeted test closure under `FOUNDRY_PROFILE=test`. Foundry's macOS sandbox proxy initialization crashed before execution, so final tests were run outside the sandbox with the approved public Ethereum RPC for the one fork-based Retention setup.

Command:

```text
env MAINNET_URL=https://ethereum.publicnode.com FOUNDRY_PROFILE=test forge test \
  --match-path test/codex-audit/ValidatedCandidates.t.sol --match-test test_PoC -vv
```

Result: **4 passed, 0 failed**.

- `test_PoC_availablePartialInsuranceCapacitySettlesNothing`
- `test_PoC_exitedAccountKeepsAccruingUntilCheckpoint`
- `test_PoC_replacementScheduleRetainsOldRateAndClock`
- `test_PoC_checkpointFrequencyChangesDistributionCap`

The repository's baseline `test/e2e/protocol/LiquidationHandler.t.sol` suite also passed **8/8**, and the pre-existing fork test `test/integration/Retention.t.sol::test_balanceChange` passed **1/1**.
