# Lane 07 — First-principles findings

## Mental-tool trace

[Feynman: processLiquidationDebt] A liquidation adds its unpaid loan to one shared bucket, pays the person who triggered it from the collateral currently in that bucket, and then tries to settle the bucket.

[Socratic: src/protocol/LiquidationHandler.sol:125 — why?] Why is the fixed reward bounded by the current liquidation's collateral only when the vault cannot pay it as assets?

[Inversion: processLiquidationDebt] (1) Leave collateral from an older liquidation parked in the handler; (2) trigger a liquidation that contributes less collateral than the fixed reward; (3) collect the full reward from the pooled old-plus-new balance.

[Feynman: processCollateral] The handler should use whatever insurance capacity is available, but it currently waits until the insurance pool can absorb the whole immediately recoverable amount.

[Socratic: src/protocol/LiquidationHandler.sol:156 — why?] Why is partial insurance capacity treated as zero capacity when the code already clamps the burn after redemption?

[Inversion: processCollateral] (1) Reduce insurance excess below the handler's recoverable debt; (2) create or wait for a larger liquidation backlog; (3) repeatedly call processing and observe that every call makes zero progress.

[Feynman: setEmissionsSchedule] Replacing the future rate list leaves the currently running rate and the old rate-change clock untouched, so the replacement does not actually start when promised.

[Socratic: src/dao/emissions/EmissionsController.sol:326 — why?] Why does a schedule replacement overwrite only the queued rates while preserving both `emissionsRate` and `lastEmissionsUpdate`?

[Inversion: setEmissionsSchedule] (1) Wait until shortly after an old rate checkpoint; (2) install a materially lower first replacement rate; (3) force ordinary emission fetches while the old rate remains live for most of the new interval.

[Feynman: _mintEmissions] The controller catches up one missed week at a time and records each newly minted week's amount.

[Socratic: src/dao/emissions/EmissionsController.sol:266 — why?] Why is the epoch passed into the rate calculation one less than the storage key receiving that minted amount?

[Inversion: _mintEmissions] (1) Leave several epochs unminted; (2) change the schedule at the current epoch; (3) inspect each catch-up iteration for boundary and schedule-clock mismatches.

[Feynman: _calcEmissionsForEpoch] The current rate changes only when the old checkpoint is at least one configured interval behind the epoch being calculated.

[Socratic: src/dao/emissions/EmissionsController.sol:276 — why?] Why can a newly installed interval still be measured from a checkpoint belonging to the replaced schedule?

[Inversion: _calcEmissionsForEpoch] (1) Choose an old checkpoint close to the replacement epoch; (2) replace a high rate with a low rate; (3) quantify how many later epochs still use the high rate.

[Feynman: _getRedemptionFee] The fee compares one market's recent redemption use with the total recent use across all markets, but only refreshes the market currently being redeemed.

[Socratic: src/protocol/RedemptionHandler.sol:143 — why?] Why is `totalWeight` assumed current when every other component of that total has its own independently aging timestamp?

[Inversion: _getRedemptionFee] (1) Accumulate capped usage on several markets; (2) leave those markets untouched until their real usage has fully expired; (3) redeem twice from a fresh target market and use the stale denominator to avoid its concentration surcharge.

[Feynman: redeemFromPair] The public redemption accepts the fee calculation, stores its updated usage accounting, removes the user's stablecoins, and returns collateral.

[Socratic: src/protocol/RedemptionHandler.sol:261 — why?] Why is the lazily updated aggregate persisted as authoritative after only one pair was decayed?

[Inversion: redeemFromPair] (1) Set a maximum fee that accepts the understated quote; (2) execute the redemption; (3) repeat before the target pair decays so the stale cross-pair denominator continues suppressing the surcharge.

[Feynman: setAddressBalances] The first caller permanently chooses everyone's initial reward weight and closes initialization for all later callers.

[Socratic: src/dao/RetentionIncentives.sol:109 — why?] Why can any address finalize the one-time distribution rather than only protocol governance or the deployment transaction?

[Inversion: setAddressBalances] (1) Watch for a separately deployed unfinalized instance; (2) submit an attacker-only balance list first; (3) receive later queued rewards according to the forged weight.

[Feynman: claimEmissions] The receiver pays for elapsed epochs, treating zero as a special “never claimed” marker even when zero is also a real epoch.

[Socratic: src/dao/emissions/receivers/RetentionReceiver.sol:58 — why?] Why does the sentinel value equal a valid epoch while the function is callable by anyone?

[Inversion: claimEmissions] (1) Call during epoch zero; (2) leave `lastEpoch` equal to zero after the call; (3) call again in the same epoch to pull another weekly treasury allocation.

[Feynman: migrateStake] A permanently locked user moves all stake to the registry's replacement contract and trusts that replacement to remember the permanent lock.

[Socratic: src/dao/staking/GovStaker.sol:432 — why?] Why is the production migration callback empty and callable by anyone when permanence depends on its implementation?

[Inversion: migrateStake] (1) Configure a replacement that inherits the empty callback; (2) migrate a permanent account; (3) start cooldown and withdraw from the replacement because its permanent flag was never set.

[Feynman: findPairPriceWeight] The watcher walks backward in six-hour steps until it finds an observation from before a pair's last update, without knowing where history begins.

[Socratic: src/protocol/PriceWatcher.sol:113 — why?] Why does backward search have no lower bound even though index zero is both the missing-entry sentinel and the history boundary?

[Inversion: findPairPriceWeight] (1) Present a pair whose last update predates the first real watcher observation; (2) request its historical weight; (3) force the loop to subtract past zero and revert.

## Findings

FINDING | contract: LiquidationHandler | function: processLiquidationDebt | bug_class: cross-liquidation-incentive-subsidy | group_key: LiquidationHandler | processLiquidationDebt | cross-liquidation-incentive-subsidy
file: src/protocol/LiquidationHandler.sol:116
path: liquidator -> LiquidationHandler.liquidate -> registered pair liquidation -> processLiquidationDebt -> ERC4626.withdraw -> liquidator receives collateral funded by older liquidations
assumption: A liquidation's incentive cannot consume collateral already held to cover debt from unrelated liquidations.
violation: The asset-withdraw branch checks the handler's aggregate `maxWithdraw` and pays the full fixed incentive without applying the `_collateralAmount` bound that is applied only in the fallback share-transfer branch.
proof: With 1:1 shares, an older 100-share/100-debt liquidation pays 25 assets and then remains parked with 75 shares and 100 debt when insurance `maxBurnableAssets()` is zero; a later liquidation contributes only 1 share and 1 debt, yet aggregate `maxWithdraw` is 76, so lines 125-127 pay its caller 25 assets, of which 24 necessarily come from the older liquidation's collateral.
description: The liquid asset incentive path pays from pooled handler collateral rather than collateral attributable to the current liquidation, allowing a tiny liquidation to appropriate collateral backing prior liquidation debt.
fix: Bound both payout branches to the asset value or share amount attributable to `_collateralAmount`, and account for that bounded slice before merging the remainder into aggregate collateral.

FINDING | contract: LiquidationHandler | function: processCollateral | bug_class: all-or-nothing-liquidation-settlement | group_key: LiquidationHandler | processCollateral | all-or-nothing-liquidation-settlement
file: src/protocol/LiquidationHandler.sol:143
path: liquidation callback or public caller -> processCollateral -> compare recoverable debt with insurance capacity -> no redemption and no burn -> liquidation debt and collateral remain parked
assumption: If the insurance pool can absorb part of recoverable liquidation debt, processing makes at least that much progress.
violation: The entire redeem-and-burn block is skipped when `toBurn > maxBurnable`, even though the block's own post-redemption logic already clamps `toBurn` down to `maxBurnable`.
proof: For 75 assets of withdrawable collateral, 100 recorded debt, and 50 assets of insurance burn capacity, lines 151-156 compute `toBurn=75` and fail the `75 <= 50` guard, so zero is redeemed and zero is burned although 50 debt is immediately burnable; unchanged repeat calls remain no-ops.
description: `processCollateral` requires insurance capacity for the full recoverable amount and therefore stalls completely whenever only partial settlement is possible.
fix: Execute the redemption when collateral is withdrawable, then clamp the actual burn to `min(withdrawnAmount, collateralDebt, maxBurnable)` and reduce debt by that partial amount.

FINDING | contract: EmissionsController | function: setEmissionsSchedule | bug_class: stale-schedule-state | group_key: EmissionsController | setEmissionsSchedule | stale-schedule-state
file: src/dao/emissions/EmissionsController.sol:318
path: owner -> setEmissionsSchedule -> replace queued array only -> next receiver fetch -> _calcEmissionsForEpoch uses old live rate and old checkpoint -> excess or deficient token mint
assumption: As documented, the first rate in a replacement schedule becomes active in the epoch following the update and its duration is measured from that replacement.
violation: The setter replaces `emissionsSchedule`, `epochsPer`, and `tailRate` but neither loads the replacement's first rate into `emissionsRate` nor resets `lastEmissionsUpdate`, so future updates are still timed from the replaced schedule.
proof: If `emissionsRate=10%`, `lastEmissionsUpdate=90`, and at epoch 100 governance installs `[5%]` with `epochsPer=52`, the setter catches up epoch 100 at 10% but leaves both old fields unchanged; the epoch-101 fetch calculates index 100, sees `100-90<52`, and mints at 10%, with the 5% rate not loaded until calculation index 142 (recorded for epoch 143), contrary to the promised epoch-101 activation; at a constant 100 million supply and one-week epochs the 42 delayed epochs add about 4.03 million tokens versus 5%.
description: Replacing the emissions schedule preserves the old active rate and checkpoint, causing the replacement to take effect many epochs later than specified and mis-mint governance supply in the interim.
fix: After minting through the update epoch, make the replacement's last array item the active `emissionsRate`, pop it from the queued schedule, and reset `lastEmissionsUpdate` to the update epoch (or store an explicit pending rate effective next epoch).

FINDING | contract: RedemptionHandler | function: _getRedemptionFee | bug_class: stale-global-usage-denominator | group_key: RedemptionHandler | _getRedemptionFee | stale-global-usage-denominator
file: src/protocol/RedemptionHandler.sol:131
path: redeemer -> redeemFromPair -> _getRedemptionFee -> decay only selected pair -> compare selected usage against stale totalWeight -> understated fee -> collateral redemption
assumption: A pair's overusage surcharge is based on its share of current, time-decayed redemption usage across all pairs.
violation: `totalWeight` retains every untouched pair's old usage indefinitely because each call subtracts and decays only the selected pair before persisting the aggregate again.
proof: Let five untouched pairs each have stored usage `0.4e18` and wait three weeks, enough for their real usage to decay to zero at the configured `0.15e18/week`; their stale `2e18` remains in `totalWeight`. After a target pair acquires recent `0.1e18` usage, its next sub-`overWeight` redemption computes `0.1/2.1 = 476` bps, below `overusageStart=800`, while a correctly decayed aggregate computes `0.1/0.1 = 10,000` bps and charges the full 1% `overusageRate`; a 100,000 reUSD redemption therefore avoids up to 1,000 reUSD-equivalent surcharge.
description: Lazy per-pair decay leaves expired usage from untouched pairs in `totalWeight`, enabling redemptions to use an inflated denominator and evade the concentration surcharge.
fix: Before computing the ratio, recompute the aggregate from all active pairs after applying each pair's decay, or replace it with a global decay accounting design that correctly removes components when they reach zero.

## Leads

LEAD | contract: RetentionIncentives | function: setAddressBalances | bug_class: permissionless-one-time-initialization | group_key: RetentionIncentives | setAddressBalances | permissionless-one-time-initialization
file: src/dao/RetentionIncentives.sol:109
code_smells: No authorization modifier; arbitrary address and balance arrays; first caller permanently sets `isFinalized=true`.
description: Any account can seize an unfinalized deployment and assign itself reward weight, but exploitability depends on whether deployment and initialization are guaranteed atomic in the live rollout.
fix: Restrict initialization to the owner and preferably pass the snapshot into construction or an atomic factory call.

LEAD | contract: RetentionIncentives | function: setAddressBalances | bug_class: duplicate-row-supply-inflation | group_key: RetentionIncentives | setAddressBalances | duplicate-row-supply-inflation
file: src/dao/RetentionIncentives.sol:109
code_smells: Repeated addresses overwrite `_balances[address]` while every row is independently added to `_totalSupply`.
description: A duplicate snapshot entry makes total reward weight exceed the sum of account balances and strands part of each distribution, but a malicious caller can already exploit the broader permissionless-initialization issue and the canonical snapshot needs confirmation.
fix: Reject duplicate addresses or update total supply by each address's net balance change.

LEAD | contract: RetentionReceiver | function: claimEmissions | bug_class: epoch-zero-sentinel-collision | group_key: RetentionReceiver | claimEmissions | epoch-zero-sentinel-collision
file: src/dao/emissions/receivers/RetentionReceiver.sol:54
code_smells: `lastEpoch == 0` means both “never claimed” and “claimed during real epoch zero”; function is permissionless.
description: Repeated same-epoch calls during epoch zero each compute `epochsSince=1` and can repeatedly pull `treasuryAllocationPerEpoch`, but confirmation requires a live or deployable receiver that is active before epoch one.
fix: Track initialization with a separate boolean or store `lastEpoch + 1` as the sentinel-safe value.

LEAD | contract: GovStaker | function: migrateStake | bug_class: migration-lock-not-preserved | group_key: GovStaker | migrateStake | migration-lock-not-preserved
file: src/dao/staking/GovStaker.sol:414
code_smells: Migration relies on `onPermaStakeMigrate`, while the in-scope base implementation at line 432 is empty and unrestricted.
description: Migrating into a replacement that inherits the base callback would turn an irreversible staker into an ordinary withdrawable staker, but the concrete registry-selected replacement implementation is needed to prove reachability.
fix: Enforce permanence in the base callback with previous-staker authorization, or require and verify an explicit permanence-preservation interface during migration.

LEAD | contract: PriceWatcher | function: findPairPriceWeight | bug_class: unbounded-history-underflow | group_key: PriceWatcher | findPairPriceWeight | unbounded-history-underflow
file: src/protocol/PriceWatcher.sol:98
code_smells: Backward search decrements a timestamp without a history-floor check; zero is the missing-index sentinel.
description: A pair whose last interest update predates the first real watcher checkpoint makes the search walk past timestamp zero and revert, potentially blocking interest updates that consume the price weight, but production pair-migration timestamps must be confirmed.
fix: Store the earliest checkpoint time and return or use that boundary entry when the requested history predates it.

## Counts

findings: 4
leads: 5
