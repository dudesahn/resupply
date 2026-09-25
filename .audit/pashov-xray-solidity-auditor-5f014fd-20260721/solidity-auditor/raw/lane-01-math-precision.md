[Feynman: VestManager.setInitializationParams]
This one-time setup divides the RSUP bucket reserved for legacy-token redemption by an advertised maximum legacy-token input, producing the fixed exchange rate used later. The fuzzy assumption is that calling the value a maximum somehow makes later redemptions stop there; this function stores only the ratio and no remaining-cap counter.

[Feynman: VestManager.redeem]
A holder permanently sends one of three accepted legacy tokens to the burn address and receives a new RSUP vest equal to input times the stored ratio. It creates the vest without checking how much of the redemption bucket has already been promised.

[Socratic: src/dao/tge/VestManager.sol:109 — why?]
Why is `_maxRedeemable` used only as the denominator of `redemptionRatio` rather than also being stored and decremented as users redeem?

[Inversion: VestManager.redeem]
1. Redeem exactly `_maxRedeemable`, then redeem one more legacy-token wei from a second accepted token. 2. Split inputs across PRISMA, yPRISMA, and cvxPRISMA to exceed the single aggregate denominator. 3. Front-run a later vest claimant after the contract has promised more RSUP than the redemption allocation.

[Feynman: ResupplyPairCore.redeemCollateral]
This path removes most of the redeemed reUSD amount from aggregate pair debt, pays collateral to the redeemer after a fee, and creates a synthetic loss marker spread among borrowers according to debt shares. If debt has been redeemed often enough relative to the outstanding shares, it shrinks the share units by a trillion before recording the new totals.

[Socratic: src/protocol/pair/ResupplyPairCore.sol:950 — why?]
Why can aggregate debt shares be divided by `1e12` without proving that every nonzero borrower share will also remain nonzero when lazily synchronized?

[Inversion: ResupplyPairCore.redeemCollateral]
1. Leave an account with fewer than `1e12` debt shares before the refactor. 2. Trigger several refactors before that account checkpoints. 3. Choose redemption sizes around the `amount*1e12 < shares` boundary so division floors aggregate and user shares differently.

[Feynman: InsurancePool.deposit]
The depositor first settles rewards, converts assets into pool shares using the current asset-to-share ratio, mints only if the result is nonzero, and then pulls the assets. A zero-share result skips both mint and transfer, so the caller cannot donate through this entry point.

[Feynman: InsurancePool.withdraw]
The exiting owner requests an exact amount of reUSD, the pool rounds the required shares upward, burns those shares, and pays the requested assets. The key assumption is that the manual round-up check itself cannot overflow and that the pool cannot have assets with zero aggregate shares.

[Inversion: InsurancePool.withdraw]
1. Request one asset wei at a very high assets-per-share ratio. 2. Test a pool immediately after a `1e12` share refactor. 3. Push multiplication operands near their maximum through repeated deposits and burns to attack the manual ceil formula.

[Feynman: LinearRewardsErc4626.previewDistributeRewards]
This view computes how much of the current reward pot has unlocked since the prior write, stopping at the cycle end. The uncertain edge is what happens after the cycle has ended but the last distribution timestamp has already moved beyond that old end.

[Inversion: LinearRewardsErc4626.syncRewardsAndDistribution]
1. Call synchronization repeatedly after a cycle ends. 2. Let a long idle interval span multiple fee epochs. 3. Call through deposit or withdraw exactly around `cycleEnd` to try to make elapsed-time subtraction negative or count rewards twice.

[Feynman: LiquidationHandler.processLiquidationDebt]
The active pair tells the handler how much borrower debt disappeared and how many collateral-vault shares arrived. The handler adds that debt to the reserve's unpaid bill, pays the liquidation initiator a fixed 25-underlying reward if the handler's aggregate vault position can supply it, and then tries to redeem the remaining collateral to the InsurancePool. The fuzzy point is that the fixed reward is sized against the handler's aggregate balance, not the collateral from this liquidation.

[Socratic: src/protocol/LiquidationHandler.sol:126 — why?]
Why does the liquid branch compare `maxWithdraw(address(this))` only with the fixed incentive and never cap the withdrawal by `_collateralAmount` from the current liquidation?

[Inversion: LiquidationHandler.processLiquidationDebt]
1. Accumulate old collateral in the handler, then liquidate a new account contributing fewer than 25 underlying units. 2. Create many tiny per-account debts through global redemption before a price shock and liquidate each separately. 3. Alternate illiquid and liquid vault states so old collateral remains pooled when a later tiny liquidation pays the fixed reward.

[Feynman: InterestRateCalculatorV2.getNewRate]
The calculator measures how much the vault assets represented by last update's reference shares grew, divides that growth by elapsed seconds, compares it with the risk-free floor, and applies an off-peg multiplier. It returns the rate and a fresh reference-share amount in narrower integer containers.

[Socratic: src/protocol/InterestRateCalculatorV2.sol:161 — why?]
Why is a user-influenceable vault growth rate narrowed to 64 bits without a bound or saturation check?

[Inversion: InterestRateCalculatorV2.getNewRate]
1. Donate to the collateral vault so the measured rate is just above `2^64`. 2. Make the off-peg multiplier push an otherwise valid rate above `2^64`. 3. Time the manipulation one second after the prior pair update to minimize the donation needed for a cast wrap.

[Feynman: RedemptionHandler._getRedemptionFee]
This routine turns a redemption into a fraction of pair debt, decays the pair's historical usage, adds an imbalance surcharge, subtracts an early-usage discount, and optionally adds any premium of the underlying stable above one dollar. The result is a percentage later subtracted from one, so it must remain at or below one whole unit even though several independently bounded components are added.

[Inversion: RedemptionHandler._getRedemptionFee]
1. Combine the maximum base fee, maximum overuse fee, and an above-peg oracle premium. 2. Submit an amount much larger than pair debt to attack the usage downcast. 3. Trigger fee calculation after a long idle interval with a maximal configured decay rate.

[Feynman: TreasuryStableDiversification._minTargetAmount]
This routine converts the input into a common stable-value unit, converts that value into target-token units, and discounts the result by either a global tolerance or a target execution buffer. When a maximum source-per-target price is configured, it divides the source stable value by that price before sizing output.

[Inversion: TreasuryStableDiversification._minTargetAmount]
1. Use a 6-decimal target to force the final downscale to zero around one micro-unit. 2. Use vault-share tokens whose price per share changes between the conversion and exchange. 3. Put a greater-than-77 decimal value behind a configured token so the decimal exponent overflows.

[Feynman: EmissionsController._calcEmissionsForEpoch]
This routine selects the scheduled annual inflation percentage for an epoch and multiplies current global token supply by that percentage and the epoch duration to obtain newly minted RSUP. Because global supply grows after each mint, missed epochs are caught up with compounding supply.

[Inversion: EmissionsController._calcEmissionsForEpoch]
1. Catch up many epochs in one call and compare the compounded result with the stated annual rate. 2. Push supply and rate toward a multiplication overflow. 3. Change schedules immediately before a rate boundary to probe whether old and new rates are assigned to the intended epochs.

[Feynman: PriceWatcher.getCurrentWeight]
The watcher converts reUSD's distance below one dollar from 1e18 precision to 1e6 precision and integrates that value over time. Its downstream consumers treat 1e6 as a full-scale maximum, but the producer never clamps to that maximum and the oracle's floor moves lower whenever governance selects a redemption fee above the initial 1%.

[Socratic: src/protocol/PriceWatcher.sol:159 — why?]
Why is the 1e6-scaled weight returned without a `min(weight, 1e6)` when both `FeeDepositController` and `InterestRateCalculatorV2` use it as a bounded fraction and their parameter checks assume the largest value is 1e6?

[Inversion: PriceWatcher.getCurrentWeight]
1. Raise the supported base redemption fee above 1%, then hold the pool price at the resulting oracle floor. 2. Feed the resulting greater-than-1e6 average to the fee controller. 3. Feed the same average to the interest calculator after choosing parameters that pass its setter only under the documented 1e6 maximum.

FINDING | contract: VestManager | function: redeem | bug_class: missing-redemption-cap | group_key: VestManager | redeem | missing-redemption-cap
path: holder of an accepted legacy token → redeem after aggregate legacy-token input has reached `_maxRedeemable` → `_createVest` records additional RSUP liabilities → excess redemption vests consume the shared RSUP balance reserved for other allocation classes and later valid claims revert
proof: `setInitializationParams` at `src/dao/tge/VestManager.sol:107-112` uses `_maxRedeemable` only to derive `redemptionRatio`; `redeem` at lines 174-190 has no cumulative-input or remaining-allocation check. The launch constants allocate 25% of 60,000,000 RSUP = 15,000,000 RSUP against `MAX_REDEEMABLE = 173,153,585e18`, producing ratio `86628295914289039`. Redeeming exactly that advertised maximum promises 14,999,999.999999999829054815 RSUP; a subsequent accepted-token redemption of 1,000,000 tokens succeeds and promises another 86,628.295914289039 RSUP, taking total redemption liabilities to 15,086,628.295914288868054815 RSUP, 86,628.295914288868054815 above the entire redemption allocation.
description: `_maxRedeemable` is only a division denominator, so the permissionless redemption path can promise more RSUP than the allocation that was used to price those promises.
fix: Store and decrement a single aggregate remaining legacy-token cap (or remaining RSUP redemption allocation) before transferring tokens and creating a vest, revert when it is exceeded, and use a checked downcast for the vest amount.

FINDING | contract: PriceWatcher | function: getCurrentWeight | bug_class: fixed-point-range-mismatch | group_key: PriceWatcher | getCurrentWeight | fixed-point-range-mismatch
path: owner selects a supported base redemption fee above 1% → a depressed pool price is clamped to the lower redemption floor → PriceWatcher records a weight above 1e6 → FeeDepositController diverts more than its configured maximum additional fee and InterestRateCalculatorV2 applies a multiplier outside the range accepted by its setter
proof: `RedemptionHandler.setBaseRedemptionFee` permits any fee through 1e18 (`src/protocol/RedemptionHandler.sol:71-77`), `ReusdOracle._clamp` sets the floor to `1e18 - fee` (`src/protocol/ReusdOracle.sol:36-44`), and `PriceWatcher.getCurrentWeight` returns `(1e18-price)/1e10` without a 1e6 cap (`src/protocol/PriceWatcher.sol:153-159`). With a valid 10% fee and a pool price at or below 0.9e18, the weight is 10,000,000. At the deployed `additionalFeeRatio = 200,000`, 1,000,000 units of interest fees route `1,000,000 - 1,000,000/3 = 666,667` units to sreUSD instead of the 166,667-unit maximum at weight 1,000,000. Likewise the deployed calculator values `rateBase = 0.5e18` and `rateRatioAdditional = 0.2e18` pass the line-77 bound as 0.6e18, yet line 176 computes `rateRatio = 0.5e18 + 0.1e18 * 10,000,000 / 1e6 = 1.5e18`.
description: The producer can emit weights up to 1e8 while both consumers and the calculator's configuration invariant assume that 1e6 is the maximum full-scale value.
fix: Clamp the watcher output and accumulated averages to 1e6, or consistently redefine the scale and validate every fee and rate parameter against the producer's actual maximum.

FINDING | contract: LiquidationHandler | function: processLiquidationDebt | bug_class: incentive-cross-subsidy | group_key: LiquidationHandler | processLiquidationDebt | incentive-cross-subsidy
path: an illiquid collateral vault leaves proceeds from prior liquidations in the handler → vault liquidity recovers → searcher liquidates a deeply underwater account whose seized collateral is worth less than the fixed incentive → handler withdraws the full incentive from its aggregate balance → searcher receives collateral belonging to prior liquidations and less debt is covered
proof: At `src/protocol/LiquidationHandler.sol:125-133`, the liquid branch checks aggregate `maxWithdraw(address(this)) >= liquidateIncentive` and withdraws the full incentive without using `_collateralAmount`; only the illiquid share-transfer branch caps to `_collateralAmount`. If 100 underlying units of old collateral remain pooled and a new underwater liquidation contributes shares worth 10, recovered vault liquidity makes aggregate `maxWithdraw = 110`; with the configured 25-unit incentive, line 127 pays 25 even though the current liquidation supplied only 10, consuming 15 units from old collateral. The subsequent `processCollateral` therefore has 15 fewer units available to transfer to the InsurancePool and burn against `debtByCollateral`.
description: The withdrawable-assets branch sizes a per-liquidation reward against pooled collateral rather than the current liquidation's contribution, allowing small liquidations to drain proceeds backing older liquidation debt.
fix: Compute the reward solely from `_collateralAmount` at the current vault conversion rate and cap both the asset-withdraw and share-transfer branches to that contribution before touching the pooled balance.

LEAD | contract: InterestRateCalculatorV2 | function: _getNewRate | bug_class: unchecked-rate-downcast | group_key: InterestRateCalculatorV2 | _getNewRate | unchecked-rate-downcast
code_smells: `getNewRate` derives `_underlyingRate` from externally mutable ERC4626 conversions, but `_getNewRate` narrows that unbounded value to `uint64` at `src/protocol/InterestRateCalculatorV2.sol:160` and narrows the multiplied result again at line 177; a one-second vault-price increase above `2^64 - 1` rate units wraps to a much smaller borrow rate instead of reverting or saturating.
description: A vault donation or abnormal exchange-rate jump may wrap the pair's measured rate and suppress accrued interest, but a profitable fork trace that crosses the 18.446744073709551615e18-per-second threshold while recovering enough of the donated value remains unverified.
