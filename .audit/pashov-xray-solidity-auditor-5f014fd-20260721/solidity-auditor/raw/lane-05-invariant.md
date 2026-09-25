# Lane 05 — Invariant Analysis

## Mental-tool trace

[Feynman: LiquidationHandler.processCollateral] The handler first asks how much collateral can be redeemed, but it compares that amount with the insurance pool's burn capacity before transferring the redeemed collateral into the pool. The transfer itself increases the pool's burn capacity, so the comparison is made against the wrong state.

[Socratic: src/protocol/LiquidationHandler.sol:156 — why?] Why must the pool be able to burn the full collateral debt before it receives the collateral that funds that burn?

[Inversion: LiquidationHandler.processCollateral] Choose a redeemable amount slightly above the pool's pre-redemption capacity but below its post-redemption capacity; the only branch that redeems is skipped, so a fully fundable settlement becomes a permanent no-op until unrelated state changes.

[Feynman: InsurancePool.maxBurnableAssets] This value is `totalAssets - minimumHeldAssets`; receiving redeemed collateral raises `totalAssets` one-for-one and can turn an apparently impossible burn into a valid one.

[Feynman: LiquidationHandler debt conservation] A liquidation removes debt from the pair and records it in `debtByCollateral`; settlement should move the corresponding collateral into the insurance pool, burn stable assets, and reduce that recorded debt by the same amount.

[Socratic: LiquidationHandler.processCollateral — what if?] What if `withdrawable = debt = 1,500`, the pool currently has only 1,000 of spare burn capacity, and the incoming 1,500 collateral would raise spare capacity to 2,500?

[Feynman: TreasuryStableDiversification.swap] The helper partitions one snapshot of the asset balance across weighted targets, but after a target it may sweep the entire balance of that target token rather than only the amount produced for that target.

[Feynman: TreasuryStableDiversification._isInputForLaterTarget] A zero input token means the protocol's default asset during execution, but the dependency scan compares the literal zero address and therefore fails to recognize that a later target still needs the asset.

[Socratic: TreasuryStableDiversification._isInputForLaterTarget — invariant] If zero is an alias for `asset` in `swap`, why is it not the same alias in the reservation check?

[Inversion: TreasuryStableDiversification.swap] Put an asset-preserving target before a default-input swap target; the first target sweeps all assets, while the later target still calculates a nonzero allocation from the stale snapshot and reverts or receives zero.

[Feynman: RetentionIncentives.setAddressBalances] This is a one-time distribution initializer. Whoever calls it first chooses every weight and permanently finalizes the list, because the function has no authorization check.

[Socratic: RetentionIncentives.setAddressBalances — deployment] Is atomic deployment plus initialization an enforced contract invariant, or only an assumption made by the current deployment script?

[Inversion: RetentionIncentives.setAddressBalances] Separate deployment from initialization by one transaction; a mempool observer supplies a one-address list first and captures all future pro-rata rewards.

[Feynman: EmissionsController.setEmissionsSchedule] The setter mints the old schedule through the current epoch and replaces the future schedule array, but leaves the currently cached rate and its update epoch unchanged.

[Feynman: EmissionsController._calcEmissionsForEpoch] The first new array entry is installed only after the elapsed-epoch condition is met, so with a one-epoch interval the old cached rate survives one epoch longer than the setter's stated next-epoch semantics.

[Socratic: EmissionsController.setEmissionsSchedule — timing] Which rate is supposed to govern the immediately following epoch, and where does the setter install it?

[Inversion: EmissionsController schedule transition] Set a sharply lower schedule at epoch N with `epochsPer = 1`; epoch N+1 still mints at the old high rate, and the first replacement rate begins only at N+2.

[Feynman: PriceWatcher.findPairPriceWeight] The historical search uses mapping value zero as “not found,” although index zero is also a valid sentinel entry, and repeatedly subtracts six hours with no lower bound.

[Socratic: PriceWatcher.findPairPriceWeight — history] What terminates the search when a pair's last-rate timestamp predates the first populated watcher observation?

[Inversion: PriceWatcher.findPairPriceWeight] Give the calculator a pair timestamp earlier than watcher history; the search reaches timestamp zero, subtracts again, and reverts from arithmetic underflow.

[Feynman: ResupplyPairCore._calculateInterest] If the new debt would exceed the uint128 storage limit, the function returns zero interest instead of preserving the unpaid amount or rejecting the transition.

[Socratic: ResupplyPairCore._addInterest — accounting] Should time advance after the calculation silently discards accrued interest?

[Inversion: ResupplyPairCore interest boundary] Place debt just below `type(uint128).max`, accrue enough interest to cross the boundary, and call any interest-touching operation; zero is accrued while the timestamp advances, permanently waiving that interval's interest.

[Feynman: GovStaker migration] The base migration callback is empty, but successor implementations can and do override it to authenticate the predecessor and establish permanent-stake state; the empty base hook alone is not a demonstrated invariant violation.

[Feynman: Pair liquidation accounting] Pair debt is removed before collateral debt is recorded in the handler, and settlement later burns insurance assets while decrementing exactly the handler ledger; the observed defect is sequencing of capacity evaluation, not a missing ledger write.

## Findings

FINDING | contract: LiquidationHandler | function: processCollateral | bug_class: capacity-check-before-inflow | group_key: LiquidationHandler | processCollateral | capacity-check-before-inflow
file: src/protocol/LiquidationHandler.sol
invariant: Redeemable liquidation collateral must be processed whenever transferring it to the insurance pool would make the corresponding stable-asset burn valid.
violation_path: A liquidation records 1,500 units in `debtByCollateral` and leaves vault shares redeemable for 1,500 units in the handler; the insurance pool has 11,000 assets and `minimumHeldAssets = 10,000`, so pre-redemption `maxBurnableAssets()` is 1,000. `processCollateral` computes `toBurn = 1,500`, compares it to the stale 1,000 capacity, skips the entire redemption/burn branch, and returns successfully. Had it first redeemed the shares to the insurance pool, pool assets would become 12,500 and burn capacity 2,500, enough to settle the full 1,500 debt. Every permissionless retry sees the same state and remains a no-op until unrelated pool state changes.
proof: The branch containing both `vault.redeem(...)` and `insurancePool.burnAssets(...)` executes only when the pre-transfer `toBurn <= maxBurnable`; `maxBurnableAssets` is derived from current pool assets net of the minimum reserve, while the skipped redemption's receiver is the insurance pool itself. Thus the prospective inflow is excluded from the predicate that decides whether the inflow may occur.
description: `processCollateral` checks insurance burn capacity before delivering the collateral that increases that capacity, causing otherwise fully funded liquidation settlements to become stuck no-ops.
fix: Redeem the available collateral into the insurance pool first, then recompute `maxBurnableAssets()` and burn the clamped amount, or calculate prospective post-redemption capacity with conservative preview/slippage handling and support partial progress.

## Leads

LEAD | contract: TreasuryStableDiversification | function: swap / _isInputForLaterTarget | bug_class: default-token-alias-reservation | group_key: TreasuryStableDiversification | swap | default-token-alias-reservation
file: src/protocol/TreasuryStableDiversification.sol
code_smells: Execution normalizes `inputToken == address(0)` to the default asset, but `_isInputForLaterTarget` does not; the completion path can also transfer or deposit the contract's entire target-token balance rather than the amount allocated to the current target.
invariant: Completing one weighted target must not consume assets reserved for later targets.
violation_path: Configure target 0 with `token = asset`, weight 1, no pool, and target 1 with `inputToken = address(0)`, weight 1, plus a valid asset-to-token pool. With 100 asset, target 0 receives a 50-unit allocation. The dependency scan fails to recognize target 1's zero input as `asset`, so target 0 sweeps all 100 asset. Target 1 still derives 50 from the original `remainingAssets` calculation but has no source balance and reverts; an all-asset variant can instead complete with a silently incorrect allocation.
description: A contract-valid target ordering can either revert every diversification attempt or defeat weighted allocation because the reservation scan gives the default input token different semantics from execution.
fix: Normalize every later zero input token to `asset` during dependency checks and return/deposit only the current target's received allocation while explicitly reserving `remainingAssets`.

LEAD | contract: RetentionIncentives | function: setAddressBalances | bug_class: unprotected-one-shot-initialization | group_key: RetentionIncentives | setAddressBalances | unprotected-one-shot-initialization
file: src/protocol/RetentionIncentives.sol
code_smells: A public caller can provide arbitrary recipients and balances and irreversibly set `finalized = true`; duplicate recipients overwrite stored balances while each list entry is still added to total supply.
invariant: The immutable reward-weight snapshot must be installed only by the authorized deployment process and must conserve the sum of unique account balances.
violation_path: If deployment and initialization are ever separated, a mempool observer calls `setAddressBalances([attacker], [10**30])` first. The attacker becomes the only weighted recipient and the legitimate initializer can no longer act. The current deployment script batches creation and initialization atomically, so no exposed production instance was proven from the reviewed scope.
description: Contract safety relies entirely on an off-chain atomic-deployment convention rather than enforcing authorization and canonical input inside the initializer.
fix: Restrict initialization to an immutable owner or designated initializer, validate equal nonzero lengths and unique recipients, and preferably commit the expected snapshot hash at construction.

LEAD | contract: EmissionsController | function: setEmissionsSchedule / _calcEmissionsForEpoch | bug_class: schedule-transition-off-by-one | group_key: EmissionsController | setEmissionsSchedule | schedule-transition-off-by-one
file: src/protocol/EmissionsController.sol
code_smells: The setter replaces the queued rates, interval, and tail rate but retains the old cached `emissionsRate` and `lastEmissionsUpdate`.
invariant: A replacement schedule documented to take effect in the epoch following the call must use its first configured rate for that next epoch.
violation_path: At epoch 10, with cached rate 10% and `lastEmissionsUpdate = 10`, set a new `[1%]` schedule with `epochsPer = 1`. Minting epoch 11 calculates epoch 10, for which elapsed epochs are zero, and therefore uses the old 10% rate. The 1% rate is installed only while minting epoch 12, making the transition one epoch late and creating unintended over- or under-emission.
description: Schedule replacement can mint one additional epoch at the superseded rate because the cached transition state is not reset consistently with the new array.
fix: Install and consume the first new rate as the next-epoch cached rate and reset `lastEmissionsUpdate` to the transition epoch, with tests for intervals one and greater than one.

LEAD | contract: PriceWatcher | function: findPairPriceWeight | bug_class: unbounded-backward-search | group_key: PriceWatcher | findPairPriceWeight | unbounded-backward-search
file: src/protocol/PriceWatcher.sol
code_smells: The loop treats `timeMap[timestamp] == 0` as absence and subtracts six hours indefinitely without bounding the search at the first recorded timestamp or zero.
invariant: A pair timestamp outside retained watcher history must produce a defined fallback or explicit domain error, not arithmetic underflow in shared interest calculation.
violation_path: Switch a pair to a watcher-backed rate calculator while its `currentRateInfo.lastTimestamp` predates the first populated watcher observation. The next rate query searches backward through empty buckets until `ftime == 0`, then `ftime -= 6 hours` underflows and reverts. Reviewed migration scripts generally accrue before switching, so an active mis-migrated pair was not proven.
description: An implicit deployment-order assumption can brick all pair operations that accrue interest if the pair requests watcher history older than the watcher's first sample.
fix: Store the earliest observation, stop the search at that boundary, and return a documented fallback or custom error; alternatively initialize a valid genesis observation and track presence separately from index zero.

LEAD | contract: ResupplyPairCore | function: _calculateInterest / _addInterest | bug_class: overflow-suppresses-accrual | group_key: ResupplyPairCore | _calculateInterest | overflow-suppresses-accrual
file: src/protocol/pair/ResupplyPairCore.sol
code_smells: When principal plus computed interest exceeds uint128, `_calculateInterest` returns zero, while `_addInterest` can still advance the interest timestamp.
invariant: Reaching a storage boundary must not silently erase earned interest while marking the corresponding time interval as accounted for.
violation_path: Set aggregate borrow amount just below `type(uint128).max` and allow a positive rate and elapsed time to produce interest greater than the remaining headroom. The calculation returns zero; the update records no interest yet advances the timestamp, so that interval can never be recovered. Reaching this boundary requires an extreme economic state and was not shown feasible under current deployment caps.
description: At the uint128 debt ceiling, accrued interest may be permanently waived rather than clamped, deferred, or rejected.
fix: Revert before advancing time, clamp to representable headroom while retaining remainder accounting, or widen the stored amount and explicitly test the maximum-debt boundary.

## Lane summary

- Findings: 1
- Leads: 5
