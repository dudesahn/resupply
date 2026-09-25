# Lane 08 — Asymmetry

## Mental-tool markers

[Feynman: ResupplyPair._updateConvexPool] This moves all collateral that the pair believes is parked in one Convex pool into another pool, then records the new pool number. A pool number of zero has a second meaning everywhere else in the pair: collateral is held directly and there is no external staking position. The migration routine does not honor that second meaning.

[Socratic: src/protocol/ResupplyPair.sol:392 — why?] Why is collateral always placed into Convex pool zero when zero is explicitly treated by the accounting, deposit, and withdrawal paths as “do not use Convex”? The hidden assumption is that zero can be both a real destination and a sentinel without any transition logic.

[Inversion: ResupplyPair._updateConvexPool] (1) Move from PID 7 to PID 0 while 1,000 shares are staked; (2) move from PID 0 to PID 7 while 1,000 shares are held directly; (3) make a small new deposit after either transition and compare what `totalCollateral` counts with where all old and new shares actually sit.

[Feynman: LiquidationHandler.processCollateral] This should turn as much seized vault collateral as current liquidity permits into assets for the insurance pool, destroy the same amount of reserve reUSD, and leave only the uncovered debt for later. Instead, it does nothing whenever the immediately coverable debt is even one unit above the reserve’s present burn capacity.

[Socratic: src/protocol/LiquidationHandler.sol:156 — why?] Why does “too much work for the reserve” skip all work when the routine later contains an explicit cap to the reserve maximum? The hidden assumption is that partial settlement is unnecessary even though both the comments and later clamp describe it as supported.

[Inversion: LiquidationHandler.processCollateral] (1) Set withdrawable debt one wei above `maxBurnableAssets`; (2) add many smaller liquidations of the same collateral after the first oversized one; (3) keep increasing reserve assets but stop one wei short of the entire accumulated debt and observe that none of the available capacity is ever used.

[Feynman: EmissionsController.setEmissionsSchedule] This replaces the future inflation plan after first finishing the current epoch under the old plan. The next epoch is documented to use the new plan, but the routine changes only the list and interval; it leaves the active rate and the old plan’s elapsed-time anchor in place.

[Socratic: src/dao/emissions/EmissionsController.sol:326 — why?] Why does deployment take the first active rate out of the list and establish its clock, while replacement stores the whole list and preserves both old values? The hidden assumption is that a new interval measured from an old schedule’s timestamp produces the same transition.

[Inversion: EmissionsController.setEmissionsSchedule] (1) Replace a schedule halfway through the old interval; (2) replace it just after the old interval would have elapsed; (3) change `epochsPer` at the same time and compare the first new-rate epoch in all three cases.

[Feynman: LiquidationHandler.processLiquidationDebt] A normal same-chain liquidation remembers the person who started it, and this routine pays that person a small amount of seized collateral. The alternate L2-manager entry is allowed to call the same routine directly, but no person is remembered for that branch, so its payment destination is the zero address.

[Socratic: src/protocol/LiquidationHandler.sol:118 — why?] Why is the L2 manager accepted as an alternate caller without either supplying a beneficiary or bypassing the caller reward? The hidden assumption is that transient caller state set only by `liquidate` also exists on a direct L2 call.

[Inversion: LiquidationHandler.processLiquidationDebt] (1) Call from the L2 manager with less than 25 reUSD of withdrawable collateral; (2) call with at least 25 reUSD so the caught withdrawal-to-zero path is used; (3) use a collateral token that accepts zero-address transfers and observe value destruction instead of a revert.

[Feynman: Keeper.canWork] This tells automation whether calling the maintenance routine would accomplish anything. The maintenance routine includes collecting profits from configured lending operators, but the predicate never asks whether any operator has enough profit.

[Socratic: src/helpers/keepers/Keeper.sol:68 — why?] Why are pair loops mirrored between `work` and `canWork` while the operator loop exists only in `work`? The implicit belief is that some unrelated weekly task will always wake the keeper when operator profit needs collection.

[Inversion: Keeper.canWork] (1) Let operator profit cross the threshold immediately after weekly maintenance; (2) keep every fee, retention, and savings condition false; (3) configure an operator as the sole actionable item and gate calls strictly on `canWork`.

[Feynman: RetentionIncentives.setAddressBalances] This one-time routine fixes every participant’s starting reward weight and the denominator used to split all future rewards. It can be called by anyone before finalization, and repeated addresses are counted repeatedly in the denominator even though only their last weight survives.

[Socratic: src/dao/RetentionIncentives.sol:109 — why?] Why does a permanent one-time distribution setter lack both the owner check used by adjacent configuration setters and a uniqueness check matching its scalar sum to mapping contents? The hidden assumption is that deployment is always atomic and snapshot input is always pre-sanitized.

[Inversion: RetentionIncentives.setAddressBalances] (1) Win the first call with one attacker address and all weight; (2) submit the same address twice with two different balances; (3) provide a longer address list than balance list and force permanent initialization failure for that transaction.

[Feynman: PriceWatcher.getCurrentWeight] This turns the reUSD discount into a six-decimal severity number consumed as a bounded fraction by interest and fee logic. Its maximum is controlled indirectly by a redemption-fee floor, but that floor can be configured far outside the one-percent range that makes the number fit the consumers’ assumed bound.

[Socratic: src/protocol/PriceWatcher.sol:159 — why?] Why is a value documented and consumed like a number between zero and one million returned without a one-million cap? The hidden assumption is that another contract’s mutable fee will never exceed one percent.

[Inversion: PriceWatcher.getCurrentWeight] (1) Raise the redemption fee floor to five percent and push reUSD to that floor; (2) use the allowed 100-percent fee and a near-zero pool price; (3) feed the resulting weight into both the rate amplifier and additional-fee formula to compare them with their configured maxima.

## Paired-surface coverage

- Governance and authority: `Core.execute` voter/operator branches; global/exact permissions; proposal create/cancel/execute; full/partial voting; guardian legacy/upgradeable variants; treasury unsafe/safe execution; exact/full retrieval.
- Token and allocation lifecycle: RSUP mint/OFT movement; reUSD mint/burn/OFT movement; receiver registration/deactivation/reactivation; emission fetch/transfer; initial/replacement emission schedules; retention initial/follow-on checkpoints.
- Lending operators and keepers: factory add/remove; operator increase/reduce/profit; keeper `work`/`canWork`; legacy/current keeper variants; borrow-limit start/update/cancel/preview.
- Staking, vesting, and rewards: stake/cooldown/unstake/migrate; account/total checkpoints and views; add/invalidate rewards; single/all reward claims; vest create/claim/callback; Merkle/redemption allocations.
- Pair core: underlying/vault collateral add/remove; borrow/repay; leverage/repay-with-collateral; redemption preview/execute; liquidation pair/handler settlement; pause/unpause; local/Convex custody; deployment/prediction and add/update protocol variants.
- Reserves, fees, and savings: insurance deposit/mint/withdraw/redeem and exit/cancel; fee pull/pair withdrawal/logging; reward sync/preview/distribution; savings deposit/mint/withdraw/redeem; OFT share debit/credit.
- Routing and diversification: simple swap deposit/withdraw/swap branches; router encode/decode and approve/revoke; diversification default/explicit inputs, chained targets, direct return/vault deposit, guarded/unguarded price branches.

## Findings

FINDING | contract: ResupplyPair | function: _updateConvexPool | bug_class: zero-sentinel-custody-desynchronization | group_key: ResupplyPair | _updateConvexPool | zero-sentinel-custody-desynchronization
path: Core governance calls `setConvexPool` across PID zero → `_updateConvexPool` moves or ignores collateral using pool-zero semantics → `convexPid` selects the opposite local/staked accounting branch → collateral is omitted from `totalCollateral` and cannot be unstaked by normal exits/liquidations
pair_or_branch: Convex PID migration vs local-custody (`pid == 0`) / staked-custody (`pid != 0`) operational branches
asymmetry: `_stakeUnderlying`, `_unstakeUnderlying`, and `totalCollateral` all use PID zero as the “collateral stays locally” sentinel (`ResupplyPair.sol:399-423`), but `_updateConvexPool` always reads `poolInfo(currentPid)` and always calls `booster.deposit(_pid, stakedBalance, true)`, including transitions to and from zero (`ResupplyPair.sol:375-395`).
proof: With `convexPid = 7`, 1,000 collateral shares staked in PID 7, and zero local shares, `setConvexPool(0)` withdraws 1,000 then deposits all 1,000 into real Convex PID 0 before recording the sentinel zero. `totalCollateral()` now takes the zero branch and reports the local balance, 0; `_unstakeUnderlying` also skips withdrawal, so a 1,000-share user removal cannot obtain the PID-0 shares. In the reverse clean state (`convexPid = 0`, 1,000 local shares, no PID-0 stake), `setConvexPool(7)` reads a zero PID-0 staking balance, deposits zero into PID 7, and records 7, after which `totalCollateral()` reports zero and ignores the 1,000 local shares. Both traces follow lines 375-423 directly.
description: The pool migration routine treats PID zero as a real Convex pool while every live accounting path treats it as a no-staking sentinel, desynchronizing custody and accounting on either zero-boundary transition.
fix: Give `_updateConvexPool` explicit zero-transition branches: withdraw only when the old PID is nonzero, include the pair’s local collateral when enabling staking, deposit only when the new PID is nonzero, and verify the post-transition accounted balance.

FINDING | contract: LiquidationHandler | function: processCollateral | bug_class: all-or-nothing-partial-settlement-dos | group_key: LiquidationHandler | processCollateral | all-or-nothing-partial-settlement-dos
path: liquidation records debt and seized collateral → `processCollateral` computes coverable debt above current reserve capacity → outer condition skips all redemption and burning → uncovered reUSD supply and collateral debt persist despite available insurance assets
pair_or_branch: intended partial settlement / oversized-capacity branch vs within-capacity branch
asymmetry: The within-capacity branch recomputes `toBurn` and explicitly clamps it to `maxBurnable` (`LiquidationHandler.sol:168-176`), but the outer branch enters that code only when the original `toBurn <= maxBurnable` (`LiquidationHandler.sol:151-156`); an oversized amount is not clamped, it is ignored completely.
proof: Let `maxWithdraw(handler) = 150,000e18`, `debtByCollateral = 150,000e18`, insurance assets be `110,000e18`, and `minimumHeldAssets = 10,000e18`, so `maxBurnableAssets = 100,000e18`. Line 151 sets `toBurn = 150,000e18`; line 156 is false. The function redeems 0, burns 0, and leaves all `150,000e18` debt recorded even though `100,000e18` is immediately coverable. Increasing insurance capacity to `149,999e18` still processes nothing; only enough capacity for the full accumulated debt unlocks the branch. A large liquidation can therefore prevent all later partial processing for the same collateral.
description: Liquidation settlement is accidentally all-or-nothing at the reserve cap, contrary to its “withdraw what is possible” design and its own unreachable clamp.
fix: Compute the processable amount as the minimum of collateral liquidity, recorded debt, and `maxBurnableAssets`, then redeem only the corresponding collateral amount and burn/decrement that partial amount.

FINDING | contract: EmissionsController | function: setEmissionsSchedule | bug_class: replacement-schedule-state-desynchronization | group_key: EmissionsController | setEmissionsSchedule | replacement-schedule-state-desynchronization
path: Core replaces the emissions plan → setter checkpoints the current epoch but preserves the old active rate and update timestamp → subsequent epochs use transition timing inherited from the old plan → RSUP is irreversibly over- or under-minted relative to the announced replacement schedule
pair_or_branch: constructor initialization vs administrative schedule replacement
asymmetry: The constructor selects the last supplied rate as `emissionsRate` and removes it from the pending schedule (`EmissionsController.sol:111-115`), while the setter stores the full replacement array and changes only `epochsPer`/`tailRate`, leaving `emissionsRate` and `lastEmissionsUpdate` from the old schedule untouched (`EmissionsController.sol:318-329`). `_calcEmissionsForEpoch` then applies the new interval to that old timestamp (`EmissionsController.sol:274-291`).
proof: Assume the old active rate is 10%, `lastEmissionsUpdate = 100`, and at epoch 105 governance calls `setEmissionsSchedule([1%, 2%], 10, 0.5%)`. Line 325 first mints through epoch 105 under the old plan. The setter leaves `emissionsRate = 10%` and `lastEmissionsUpdate = 100`. When epoch 106 is minted, `_calcEmissionsForEpoch(105)` sees `105 - 100 < 10` and still uses 10%, despite line 316 promising updates in the epoch after the setter. Epochs 106 through 110 likewise use 10%; the 2% replacement rate is not selected until the calculation whose input epoch reaches 110. The excess RSUP already minted into the controller cannot be undone by a later schedule correction.
description: Replacing the emissions schedule does not initialize the replacement’s active rate or clock, so the new plan starts at a history-dependent epoch rather than the documented next epoch.
fix: After checkpointing the current epoch, set `emissionsRate` to and pop the replacement array’s last rate, and reset `lastEmissionsUpdate` to the current epoch so the new rate governs the next minted epoch.

FINDING | contract: LiquidationHandler | function: processLiquidationDebt | bug_class: alternate-caller-zero-recipient | group_key: LiquidationHandler | processLiquidationDebt | alternate-caller-zero-recipient
path: authorized L2 manager calls `processLiquidationDebt` directly → no preceding `liquidate` call has populated transient `_liquidationCaller` → incentive branch pays address zero → standard collateral either reverts the full debt-processing call or destroys/strands the incentive
pair_or_branch: registered-pair callback branch vs direct L2-manager branch
asymmetry: The registered-pair route is normally reached through `liquidate`, which stores `msg.sender` in `_liquidationCaller` at lines 107-113; the explicitly authorized L2-manager route at lines 116-119 has no analogous writer, yet both branches unconditionally use `_liquidationCaller` as the incentive receiver at lines 124-133.
proof: At the start of an L2-manager transaction transient `_liquidationCaller` is zero. Let the manager report `10e18` collateral shares and debt while `maxWithdraw(handler) = 10e18 < liquidateIncentive = 25e18`. Lines 129-132 compute a positive share incentive, clamp it to `10e18`, and call the collateral token with recipient `address(0)`. A standard zero-recipient-rejecting ERC20 reverts the entire call, including the line-122 debt increment; a permissive token instead sends the incentive to the zero address. If withdrawable is at least `25e18`, the attempted vault withdrawal to zero is caught and silently pays no incentive, demonstrating the same missing-recipient state with a different failure shape.
description: The alternate L2 liquidation callback is authorized without establishing the beneficiary required by shared incentive logic.
fix: Pass an explicit beneficiary for L2 debt reports or select a branch-local recipient (and deliberately skip incentives when none exists) instead of reading transient state that only the same-chain route initializes.

## Leads

LEAD | contract: Keeper | function: canWork | bug_class: predicate-execution-drift | group_key: Keeper | canWork | predicate-execution-drift
pair_or_branch: `canWork` simulation vs `work` execution
asymmetry: `work` iterates `operators` and calls `withdraw_profit` when `profit() > minProfit` (`Keeper.sol:63-65`), while `canWork` checks fees, savings, retention, and pairs only and returns false without checking a single operator (`Keeper.sol:68-75`).
code_smells: With every weekly flag false and one operator at `minProfit + 1`, `canWithdrawProfit(operator)` is true and a direct `work()` would collect profit, but `canWork()` is false. Whether this causes loss depends on the off-chain automation using `canWork` as a hard call gate; otherwise collection is merely delayed until an unrelated task becomes ready.
description: Automation can miss the only actionable maintenance item because the readiness predicate omits an execution branch.

LEAD | contract: RetentionIncentives | function: setAddressBalances | bug_class: one-shot-initialization-asymmetry | group_key: RetentionIncentives | setAddressBalances | one-shot-initialization-asymmetry
pair_or_branch: one-time initialization vs ongoing balance-decrease accounting / adjacent owner configuration
asymmetry: Ongoing decreases subtract the overwritten account balance from `_totalSupply`, but initialization adds every list entry to `_totalSupply` while overwriting duplicate mapping keys; unlike `setRewardHandler`, it also has no owner check (`RetentionIncentives.sol:101-127`).
code_smells: Input `addresses=[A,A]`, `balances=[100,1]` leaves `balanceOf(A)=1` and `_totalSupply=101`, permanently diluting all rewards. An untrusted first caller could instead finalize attacker-chosen weights. The repository deployment action batches CREATE3 deployment and this setter, which appears to close the first-caller race for that deployment, but no source-level uniqueness/length invariant protects the irreversible snapshot.
description: The permanent initialization path has weaker authorization and conservation checks than every subsequent configuration/accounting path; exploitability depends on deployment atomicity or malformed snapshot input.

LEAD | contract: PriceWatcher | function: getCurrentWeight | bug_class: producer-consumer-range-mismatch | group_key: PriceWatcher | getCurrentWeight | producer-consumer-range-mismatch
pair_or_branch: weight producer bound vs InterestRateCalculatorV2/FeeDepositController consumer scaling
asymmetry: `PriceWatcher` returns `(1e18 - price) / 1e10` without a `1e6` cap (`PriceWatcher.sol:153-159`), while both consumers divide by `1e6` as if the weight were a bounded six-decimal fraction (`InterestRateCalculatorV2.sol:175-177`, `FeeDepositController.sol:130-132`). The indirect oracle floor uses mutable `baseRedemptionFee`, whose setter allows up to 100% (`RedemptionHandler.sol:71-78`).
code_smells: At the default 1% floor the maximum weight is the expected `1e6`; at a permitted 5% fee it becomes `5e6`, multiplying the configured off-peg addition fivefold, and at a 100% fee plus near-zero price it approaches `1e8`. A concrete loss path requires governance to select such a fee and a market discount, so this remains a configuration-coupling lead rather than an untrusted-caller finding.
description: Consumers enforce parameter bounds only for a one-million weight while the producer can return one hundred million under another contract’s valid configuration.

## Counts

- FINDING: 4
- LEAD: 3

