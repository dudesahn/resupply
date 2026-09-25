# Lane 10 — Numerical Gap Hunter

## Mental-tool trace

[Feynman: SavingsReUSD.calculateRewardsToDistribute] This function decides how much pending reUSD becomes owned by savers over an elapsed interval. It first computes the cycle's straight-line release, then limits that release to a rate times the vault assets already recorded as distributed or deposited.

[Socratic: src/protocol/sreusd/sreUSD.sol:95 — why?] Why is an interval-wide cap based on the mutable end-of-the-previous-checkpoint asset total, when the cap is supposed to describe one schedule independent of how often anyone checkpoints it?

[Inversion: SavingsReUSD.calculateRewardsToDistribute] (1) checkpoint once after a full week; (2) checkpoint once per day while the cap binds; (3) checkpoint every block while holding most shares, then redeem the checkpoint-created excess.

[Feynman: LinearRewardsErc4626._distributeRewards] This function realizes the previewed reward into the asset total and moves the last-accounted time to now, so every public synchronization chooses a new segment boundary for later reward math.

[Socratic: src/protocol/sreusd/LinearRewardsErc4626.sol:124 — why?] Why may any caller choose the next numerical integration boundary merely by calling synchronization?

[Feynman: Utilities.getPairRsupRate] This function estimates the RSUP paid per second for one unit of pair debt by taking the pair's fraction of a global stream and dividing it by the pair's borrow shares.

[Feynman: Utilities.getInsurancePoolRewardRates] This function performs the same two-stage conversion for the insurance pool: global stream to pool stream, then pool stream to one unit of pool shares.

[Socratic: src/protocol/Utilities.sol:261 — why?] Why is `1e36` added before a later `* 1e18 / pairShares` normalization when the comment promises only one extra `1e18` precision factor?

[Inversion: Utilities.getPairRsupRate] (1) set every weight to one receiver; (2) set pair borrow shares to exactly `1e18`; (3) use a one-token-per-second stream so every legitimate ratio cancels and any remaining factor is demonstrably spurious.

[Feynman: Utilities.getPairInterestRate] This function tries to reproduce the live pair's borrow rate for off-chain users, selecting the V1 or V2 formula according to the installed calculator.

[Socratic: src/protocol/Utilities.sol:97 — why?] Why does the second assignment replace the already-selected hard minimum instead of comparing the collateral-derived rate against it?

[Inversion: Utilities.getPairInterestRate] (1) make the savings rate zero; (2) make collateral yield lower than the hard minimum; (3) compare the helper result with the rate calculator's own result for the same inputs.

[Feynman: PriceWatcher.getCurrentWeight] This function converts the reUSD discount from an 18-decimal price into a six-decimal number that downstream modules treat as a fraction capped at one million.

[Socratic: src/protocol/PriceWatcher.sol:159 — why?] What enforces the implied `weight <= 1e6` once the independently configurable redemption fee allows an oracle floor below 99%?

[Inversion: PriceWatcher.getCurrentWeight] (1) configure a valid 10% redemption fee; (2) move the market price to or below the resulting 0.90 floor; (3) feed the resulting `10e6` weight into both consumers that divide by `1e6`.

[Feynman: Voter.createNewProposal] This function snapshots the total staked voting weight, discards token fractions, and stores the configured percentage of that whole-token total as the proposal's quorum.

[Feynman: Voter._voteForProposal] This function separately discards each voter's token fraction before adding that account's whole-token weight to the proposal result.

[Socratic: src/dao/Voter.sol:226 — why?] Why is rounding performed after aggregation for the quorum denominator but before aggregation for the votes that can satisfy it?

[Inversion: Voter._voteForProposal] (1) split stake into many `1e18 - 1` accounts; (2) let every fragment enter the aggregate total; (3) attempt to cast each fragment and observe that every individual voting weight is zero.

[Feynman: ResupplyPairCore._calculateInterest] This function computes elapsed borrower interest, adds it when the packed debt amount can hold it, and otherwise changes the computed interest to zero.

[Socratic: src/protocol/pair/ResupplyPairCore.sol:493 — why?] Why does exceeding the storage boundary erase the entire interval's interest rather than preserve, saturate, or reject it?

[Inversion: ResupplyPairCore._calculateInterest] (1) leave one unit of `uint128` headroom; (2) accrue one second whose interest exceeds that unit; (3) call any interest-updating entry point every second and verify that the timestamp advances while debt never grows.

## Results

FINDING | contract: SavingsReUSD | function: calculateRewardsToDistribute | bug_class: checkpoint-frequency-cap-bypass | group_key: SavingsReUSD | calculateRewardsToDistribute | checkpoint-frequency-cap-bypass
path: existing sreUSD holder → permissionless `syncRewardsAndDistribution()` at attacker-chosen intervals → each interval recomputes the cap from the previously increased `storedTotalAssets` → more rewards become withdrawable than the same cap permits over one interval
seam: precision×invariant
proof: Use the deployed/test rate `r = floor(0.2e18 / 365 days) = 6,341,958,396`, `storedTotalAssets = 100,000,000e18`, a seven-day cycle, and enough `rewardCycleAmount` that the cap binds. One checkpoint after 604,800 seconds releases `r * 604800 * 100,000,000e18 / 1e18 = 383,561.64379008e18`. Seven daily checkpoints apply `A[n+1] = A[n] + floor(r * 86400 * A[n] / 1e18)` and release `384,192.7322070942e18`, which is `631.0884170142e18` more for identical time, initial assets, and rewards. The excess comes from feeding each prior release back into line 95's cap base.
root_cause: The cap is integrated segment-by-segment against mutable `storedTotalAssets`, so `sum(r * dt_i * A_i)` compounds and is not equal to the monolithic cap callers assume for the cycle.
description: Permissionless checkpoint frequency changes the maximum reward release, allowing incumbent holders to accelerate capped rewards at the expense of later-cycle reward inventory.
minimal_fix: Snapshot the cap base at cycle start and enforce a cumulative cap from `lastSync` (subtracting rewards already released) instead of applying the rate independently to the current `storedTotalAssets` on every checkpoint.
fix: Make capped release a path-independent cumulative value for the cycle.

FINDING | contract: Utilities | function: getPairRsupRate,getInsurancePoolRewardRates | bug_class: reward-rate-scale-inflation | group_key: Utilities | getPairRsupRate/getInsurancePoolRewardRates | reward-rate-scale-inflation
path: UI/integrator → permissionless reward-rate helper → global stream is multiplied by `1e36`, then normalized per share with another `1e18` factor → returned incentive/APR input is `1e18` times the documented scale
seam: precision×invariant
proof: Let `rewardRate = 1e18` (one token/second), `pairWeight = totalWeight = 1e18` (100% allocation), and `pairShares = 1e18` (one whole debt token). A result with the documented extra `1e18` precision is `1e36`. Lines 261 and 266 instead calculate `(1e18 * 1e18 * 1e36 / 1e18) * 1e18 / 1e18 = 1e54`, exactly `1e18` too large. Lines 294/300 and 313/319 repeat the same math for both insurance reward streams.
root_cause: The weight-ratio step adds two precision paddings (`1e36`) even though the subsequent per-share step already supplies the second `1e18` normalization.
description: Pair and insurance reward-rate helpers overstate every nonzero per-share reward rate by `1e18`, producing unusable APR/incentive quotes for downstream consumers.
minimal_fix: Replace the `1e36` factors at the weight-allocation step with `1e18`, retaining the later `* 1e18 / shares` calculation.
fix: Apply exactly one ratio-preservation factor and one per-share factor.

LEAD | contract: Utilities | function: getPairInterestRate | bug_class: minimum-rate-quote-omission | group_key: Utilities | getPairInterestRate | minimum-rate-quote-omission
code_smells: In the V1 branch line 96 selects `max(minimumRate, riskFreeRate)`, but line 97 immediately overwrites it with `max(underlyingRate, riskFreeRate)`, deleting the minimum from the result.
seam: precision×invariant
proof: For scaled per-second inputs `minimumRate = 400`, post-ratio `riskFreeRate = 200`, and post-ratio `underlyingRate = 100`, the helper returns `200`; `InterestRateCalculator.getNewRate` computes `floorRate = max(200,400) = 400` and returns `max(100,400) = 400`. Thus `queryRate != executionRate` for identical values.
root_cause: A sequential assignment replaces the accumulated maximum instead of extending it to a third operand.
minimal_fix: Set the final value to `max(_ratePerSecond, underlyingRate)` or compute `max(minimumRate, riskFreeRate, underlyingRate)` once.
description: The V1 off-chain helper can quote a rate below the hard on-chain minimum; remaining impact depends on which production integrators consume this helper.

LEAD | contract: PriceWatcher | function: getCurrentWeight | bug_class: cross-module-weight-range-expansion | group_key: PriceWatcher | getCurrentWeight | cross-module-weight-range-expansion
code_smells: `getCurrentWeight` returns the whole redemption-fee-sized discount divided by `1e10`, while `InterestRateCalculatorV2` and `FeeDepositController` both divide the value by `1e6` as though it cannot exceed `1e6`; the redemption fee setter allows up to 100%.
seam: boundary×precision
proof: A valid `baseRedemptionFee = 0.10e18` makes the clamped price `0.90e18` during a matching depeg and produces `weight = 0.10e18 / 1e10 = 10,000,000`. With `rateRatioBase = 0.5e18` and `rateRatioAdditional = 0.2e18`, the setter validates only `0.5e18 + 0.1e18 < 1e18`, yet the consumer computes `0.5e18 + 0.1e18 * 10,000,000 / 1,000,000 = 1.5e18`. With `additionalFeeRatio = 200,000`, the fee consumer similarly turns the weight into `2,000,000`, routing `fees - fees/3 = 66.67%` of interest rather than the `16.67%` produced at the implied `1e6` maximum.
root_cause: The producer's permitted range is derived from an independently mutable price floor, but both consumers hard-code a smaller six-decimal fractional domain.
minimal_fix: Clamp the produced/consumed weight to `1e6`, or enforce `baseRedemptionFee <= 1e16` and assert the range in every consumer.
description: A governance-valid fee plus a market depeg can violate downstream multiplier bounds; a full finding needs the intended production range and a profitable depeg/fee-routing strategy confirmed.

LEAD | contract: Voter | function: createNewProposal,_voteForProposal | bug_class: fragmented-stake-quorum-gap | group_key: Voter | createNewProposal/_voteForProposal | fragmented-stake-quorum-gap
code_smells: Quorum truncates the aggregate stake once, while votes truncate every account before summing, so aggregate stake can contain an unbounded amount of voting weight that no account can cast.
seam: precision×invariant
proof: With the deployed `quorumPct = 3000`, honest stake of `1,000e18`, and 2,340 attacker-controlled accounts each staking `1e18 - 1`, aggregate raw stake is `3,340e18 - 2,340`, so proposal creation uses `totalWeight = 3,339` and `quorumWeight = floor(3,339 * 0.30) = 1,001`. Every fragmented account gets `floor((1e18 - 1)/1e18) = 0` and cannot vote, while all honest stake contributes at most 1,000 votes; quorum is unreachable.
root_cause: The denominator uses `floor(sum(rawWeight)/scale)`, but the achievable numerator is `sum(floor(rawWeight_i/scale))`; these expressions differ by almost one whole token per account.
minimal_fix: Snapshot and vote with raw 18-decimal weights in wider fields (for example `uint128`/`uint256`) and only scale presentation values, using checked casts.
description: Stake fragmentation can inject non-castable quorum weight and freeze proposals, but at the current 30% quorum a complete attacker freeze requires roughly 70% of aggregate stake, so incremental exploitability over simply voting “no” remains to be established.

LEAD | contract: ResupplyPairCore | function: _calculateInterest | bug_class: uint128-boundary-interest-forgiveness | group_key: ResupplyPairCore | _calculateInterest | uint128-boundary-interest-forgiveness
code_smells: When accrued interest would exceed the packed `uint128` debt boundary, the entire interval's interest becomes zero, but `_addInterest` still advances `lastTimestamp` and persists the unchanged debt.
seam: boundary×invariant
proof: Let `totalBorrow.amount = 2^128 - 2 = 340282366920938463463374607431768211454`, `newRate = 1e9`, and `deltaTime = 1`. The exact integer interest is `340282366920938463463374607431`, which exceeds the one-unit headroom, so lines 493-495 replace it with zero. Lines 534-541 nevertheless write the new timestamp/rate and unchanged debt. Repeating once per second keeps forgiving every interval because headroom remains one.
root_cause: Overflow avoidance is implemented as silent all-or-nothing interest cancellation rather than a checked state boundary.
minimal_fix: Revert explicitly when accrued debt cannot fit (without advancing time), widen debt amount storage, or apply and record only the remaining headroom under a documented saturation state.
description: Debt can stop accruing permanently near the `uint128` ceiling; a full finding needs a credible path to debt values close enough to that astronomical boundary.

## Counts

- FINDING: 2
- LEAD: 4
