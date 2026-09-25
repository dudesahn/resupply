# Resupply X-Ray + Solidity Auditor synthesis

Target: `5f014fd5003bba32c0cf2049992f57a768728631`

## Executive summary

This clean-room run combined X-Ray orientation with 12 independent Solidity Auditor lanes executed in two waves. The exact scope was 65 production Solidity files totaling 8,109 nSLOC. Every raw candidate was reviewed once against the workflow's execution, reachability, trigger, and impact gates.

The final result is **10 validated findings** and **22 validated leads**. Four findings have executable Foundry reproductions; the remaining promoted findings were validated by source-level execution and state-flow tracing. Six raw surfaces failed the gates and are excluded from the result set. No prior resupply audit output or ytranche finding content influenced discovery.

X-Ray rated the repository **ADEQUATE** for audit readiness. Its maps show a broad permissioned surface and substantial cross-contract accounting, but limited machine-enforced invariant testing: the repository had conventional tests and a stateless fuzz test, while no Foundry invariant suites or formal verification setup were detected.

## Validated findings

| ID | Confidence | Affected surface | Result | Evidence |
|---|---:|---|---|---|
| F1 | 100 | `LiquidationHandler.processCollateral` | Partial insurance capacity causes liquidation recovery to make zero progress. | 5 lanes + passing PoC |
| F2 | 98 | `RetentionIncentives._updateReward` | Exited InsurancePool depositors continue earning at their stale retention weight. | 2 lanes + passing fork PoC |
| F3 | 95 | `EmissionsController.setEmissionsSchedule` | Replacing a schedule retains the superseded active rate and update clock. | 3 lanes + passing PoC |
| F4 | 95 | `LiquidationHandler.processLiquidationDebt` | A small liquidation can spend collateral backing debt accumulated by earlier liquidations. | 3 lanes + execution/state-flow trace |
| F5 | 90 | `BasicVaultOracle.getPrices` | Vault-underlying downside depegs are omitted from collateral solvency pricing. | Source/oracle-path trace |
| F6 | 90 | `RedemptionHandler._getRedemptionFee` | Stale usage from inactive pairs remains in the denominator and suppresses concentration fees. | State/accounting trace |
| F7 | 90 | `SavingsReUSD.calculateRewardsToDistribute` | Permissionless checkpoint frequency changes the cumulative reward cap. | Passing PoC |
| F8 | 80 | `UnderlyingOracle.getPrices` | The frxUSD redemption path accepts stale or invalid legacy oracle answers. | 2 lanes + source/oracle-path trace |
| F9 | 80 | `RetentionReceiver.setTreasuryAllocationPerEpoch` | Updating the treasury rate reprices elapsed but unclaimed epochs. | Historical-accounting trace |
| F10 | 75 | `PriceWatcher.getCurrentWeight` | A valid fee configuration can emit weights above the six-decimal domain assumed by consumers. | 3 lanes + cross-consumer trace |

The standard Pashov-format report contains the full descriptions and fixes for findings with confidence 80 or higher.

## Validated leads

These are confirmed source-level smells with an incomplete deployed precondition, trust assumption, integration fact, or material-impact proof. They are intentionally not promoted to scored findings.

| ID | Surface | What remains to establish |
|---|---|---|
| L1 | `BasicVaultOracle.getPrices` | Whether every supported vault guarantees a nonzero share price under catastrophic loss; otherwise reciprocal bad-debt math can freeze. |
| L2 | `GovStaker.migrateStake` | The concrete successor's enforcement that permanent stake remains permanent after value moves. |
| L3 | `GovStaker.onPermaStakeMigrate` | Whether governance can select an unmodified base staker whose receiver hook is an unauthenticated no-op. |
| L4 | `InsurancePool.maxDeposit/maxMint/maxWithdraw/maxRedeem` | The integration impact of ERC-4626 maximum views disagreeing with cooldown execution state. |
| L5 | `Keeper.canWork` | Whether off-chain automation treats `false` as a hard gate while profitable withdrawals are ready. |
| L6 | `LinearRewardsErc4626.syncRewardsAndDistribution` | A concrete external fee/oracle/reward failure that blocks deposit, withdraw, or redeem. |
| L7 | `LiquidationHandler.migrateCollateral` | The production replacement/helper that accepts, books, and reconciles migrated collateral and debt. |
| L8 | `LiquidationHandler.processLiquidationDebt` | Whether the live L2 manager exercises the zero-beneficiary callback path and how receivers handle it. |
| L9 | `PriceWatcher.findPairPriceWeight` | Whether any migrated pair timestamp predates the watcher's retained observation history. |
| L10 | `RedemptionOperator.executeRedemption` | The approved-bot trust model and any off-chain enforcement of profit and slippage bounds. |
| L11 | `RetentionIncentives.setAddressBalances` | A non-atomic replacement deployment; the reviewed production deployment was atomically finalized. |
| L12 | `RetentionReceiver.claimEmissions` | A receiver funded and active in epoch zero, where zero is both a real epoch and the unclaimed sentinel. |
| L13 | `RewardDistributorMultiEpoch._checkpoint` | A reproducible optional-reward dependency failure on a safety-critical checkpoint path. |
| L14 | `RewardHandler.queueStakingRewards` | A migration proposal that changes the registry staker without atomically replacing the immutable handler reference. |
| L15 | `RouterSwapper.swap` | A protocol-generated residual balance exposed to public arbitrary router calldata; self-funded donations are insufficient. |
| L16 | `SavingsReUSD._debit/_credit` | Enabled peers, remote share prices, and escrow liquidity showing value loss from transporting raw share count. |
| L17 | `Swapper.swap` | A protocol-generated residual outside the atomic pair call; self-funded or accidental donations are insufficient. |
| L18 | `TreasuryStableDiversification.swap` | A live custom-input-only configuration that strands an unconditionally pulled default asset. |
| L19 | `TreasuryStableDiversification.swap / _isInputForLaterTarget` | A live multi-target ordering affected by inconsistent zero-address/default-token normalization. |
| L20 | `Utilities.getPairInterestRate` | A production consumer that treats the V1 helper's overwritten minimum-rate result as authoritative. |
| L21 | `Utilities.getPairRsupRate/getInsurancePoolRewardRates` | The UI/integrator scale contract for the apparently over-scaled reward-rate outputs. |
| L22 | `VestManager.redeem` | Accepted-token supply/accounting that exceeds the documented aggregate redemption maximum. |

## Cross-tool synthesis

The most consequential pattern is not a single primitive; it is inconsistent accounting across time and aggregation boundaries:

- Liquidation and insurance accounting uses aggregate balances while making current-operation decisions. F1 stalls when only partial reserve capacity exists, and F4 can spend value that belongs to older unresolved debt.
- Epoch and checkpoint accounting is history dependent. F2, F3, F7, and F9 allow exit timing, schedule replacement, caller frequency, or a current parameter to alter rewards attributable to another interval.
- Oracle and risk weights lack a uniform validation/domain contract. F5 omits an underlying price dimension, F8 omits feed freshness/validity, and F10 permits producer output beyond consumer assumptions.
- Several retained leads sit at migration and adapter boundaries, where correctness depends on deployment order, successor behavior, residual-balance provenance, or off-chain bot policy that the reviewed contracts do not enforce.

The clearest hardening direction is to make each boundary explicit: settle old intervals before changing parameters, bind current-operation value to current-operation provenance, validate oracle freshness and units at the producer, clamp or reject out-of-domain weights, and encode migration/adaptor postconditions on chain.

## Validation and completeness

The consolidated audit PoC suite passed **4/4**. The existing LiquidationHandler baseline passed **8/8**, and the existing Retention baseline passed **1/1**. Production sources were not modified.

Raw output contained 33 finding blocks and 34 lead blocks across 12 lanes. These collapsed to 37 unique `(Contract, function)` surfaces; all 37 have a recorded disposition. The final set contains 10 findings and 22 leads, while six rejected surfaces are preserved only as exclusion metadata in the validation ledger.

## Artifact map

- `../x-ray/x-ray.md`: audit-readiness report and verdict.
- `../x-ray/entry-points.md`: complete mutating entry-point map.
- `../x-ray/invariants.md`: invariant catalog and testing assessment.
- `../x-ray/architecture.svg`: architecture diagram.
- `../solidity-auditor/raw/`: 12 clean raw lane outputs.
- `../solidity-auditor/validation-ledger.md`: fixed-gate disposition of every raw surface.
- `../solidity-auditor/validation/ValidatedCandidates.t.sol`: four reproducible tests.
- `../solidity-auditor/validation/poc-results.md`: commands and results.
- `../solidity-auditor/resupply-pashov-ai-audit-report-20260722-002133.md`: standard Solidity Auditor report.
- `../solidity-auditor/run-manifest.md`: scope, isolation controls, hashes, and run metadata.
