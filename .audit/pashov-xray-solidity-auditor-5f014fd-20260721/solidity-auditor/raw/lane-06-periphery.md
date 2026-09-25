# Lane 06 — Periphery

## Mental-tool trace

[Feynman: RetentionIncentives._updateReward] This function first pays an account on the basis of the weight remembered from its last checkpoint, and only afterward asks the insurance pool whether that weight should be smaller. The missing fact is when the insurance balance actually fell.

[Socratic: src/dao/RetentionIncentives.sol:158 — why?] Why is all elapsed reward credited from the old weight before the current insurance-pool balance is read, when no insurance-pool withdrawal hook records the time the user stopped qualifying?

[Inversion: RetentionIncentives._updateReward] (1) Withdraw every insurance-pool share immediately after a retention checkpoint and wait most of a reward epoch; (2) avoid both `user_checkpoint` and permissionless `checkpoint_multiple` until the desired claim time; (3) call `getReward` only after the stale weight has accumulated rewards, causing the function to bank those rewards before reducing the weight to zero.

[Feynman: RetentionIncentives.setAddressBalances] This one-time function copies a supplied snapshot into reward weights and permanently closes initialization. Anyone can be the first caller, so deployment atomicity rather than the contract decides who controls the snapshot.

[Socratic: src/dao/RetentionIncentives.sol:109 — why?] Why can an arbitrary address finalize the only reward-weight snapshot, and why can the same address appear more than once in the total even though the mapping keeps only its last balance?

[Inversion: RetentionIncentives.setAddressBalances] (1) Call the setter first with an attacker-only snapshot; (2) call it first with empty arrays to brick all rewards at zero weight; (3) repeat one address many times so `_totalSupply` exceeds the sum of reachable mapping balances and dilutes every distribution.

[Feynman: TreasuryStableDiversification.swap] The helper first takes the requested default stablecoin from the treasury, then processes each target from either that default coin or a separately named input coin. If every target names a separate input coin, nothing in the loop spends or returns the default coin that was just taken.

[Socratic: src/dao/TreasuryStableDiversification.sol:172 — why?] Why is the treasury asset pulled before confirming that at least one configured target consumes the default asset?

[Inversion: TreasuryStableDiversification.swap] (1) Configure the expressly permitted custom-input-only target set and call the permissionless function with the maximum amount; (2) call it when none of the custom input tokens is present so every target continues at zero while the default asset remains; (3) repeat after the owner retrieves or replenishes funds to strand the newly available treasury excess again.

[Feynman: Utilities.getPairInterestRate] This helper estimates the pair rate from three floors: the configured minimum, a risk-free benchmark, and the underlying yield. The V1 branch computes the minimum once and then accidentally replaces that result with a comparison that no longer includes it.

[Socratic: src/protocol/Utilities.sol:97 — why?] Why does the second assignment compare only `underlyingRate` and `riskFreeRate` instead of comparing their maximum against the already-computed minimum rate?

[Inversion: Utilities.getPairInterestRate] (1) Choose a V1 pair whose minimum rate is above both half-scaled benchmarks; (2) lower the underlying supply rate below the risk-free benchmark; (3) consume the utility quote in an off-chain keeper or UI and observe a value below the calculator's enforceable floor.

[Feynman: Swapper.swap] This contract takes whatever balance it happens to hold for each token in a route and sends the final result to an address selected by the caller. The named account and input amount do not limit the operation.

[Socratic: src/protocol/Swapper.sol:64 — why?] Why is `balanceOf(address(this))` used instead of the supplied amount, and why can any caller select the final recipient for an already configured route?

[Inversion: Swapper.swap] (1) Wait for a transfer mistake or rounding residue in a token with a configured route; (2) call `swap` directly with an arbitrary `amountIn`; (3) set `to` to the attacker so the entire residual balance is exchanged and delivered there.

[Feynman: RouterSwapper.swap] This adapter turns addresses into arbitrary router calldata and gives the fixed router unlimited approvals over supported assets. It never checks that the caller is a registered pair or that the payload spends only the requested amount for the requested recipient.

[Socratic: src/protocol/swappers/RouterSwapper.sol:35 — why?] Why are the account, amount, and destination parameters discarded when the encoded router payload can independently choose spend amount and recipient?

[Inversion: RouterSwapper.swap] (1) Encode router calldata that spends an approved collateral balance held by the adapter; (2) name the attacker as the router output recipient; (3) call the public adapter directly after any residual or accidental transfer reaches it.

[Feynman: UnderlyingOracle.getPrices] This function returns one stablecoin's Curve price and another stablecoin's latest Chainlink answer. It treats any signed Chainlink answer as a valid unsigned price and does not ask when it was updated.

[Socratic: src/protocol/UnderlyingOracle.sol:31 — why?] Why is a signed answer cast directly to `uint256` without checking positivity, round completion, or staleness before the result is added to redemption fees?

[Inversion: UnderlyingOracle.getPrices] (1) Exercise the redemption quote while the feed reports a non-positive answer; (2) exercise it after the feed has stopped updating; (3) submit a redemption with a normal maximum fee and observe that an invalid huge cast or stale premium can deny execution.

[Feynman: VaultAccount arithmetic] The share/amount helpers preserve proportional ownership while storing compact totals. For protocol-sized stored totals the products stay within 256 bits, and arbitrary oversized view inputs can only make that caller's own query revert.

[Inversion: VaultAccount arithmetic] (1) Try zero assets with nonzero shares; (2) try totals at their `uint128` storage bounds; (3) try an arbitrary maximum-sized preview input. The first two remain defined, while the third only reverts an untrusted view calculation and does not mutate protocol accounting.

[Feynman: SafeERC20 metadata helpers] These helpers tolerate missing and bytes32-style token metadata, but a successful malformed dynamic return can still make ABI decoding revert. No production state-changing path in scope calls the name or symbol helpers.

[Inversion: SafeERC20.safeName/safeSymbol] (1) Return fewer than 32 bytes; (2) return a malformed dynamic offset with at least 64 bytes; (3) return an oversized claimed string length. Only callers that opt into these unused metadata helpers are affected, so no asset-moving exploit path was established.

## Findings

FINDING | contract: RetentionIncentives | function: _updateReward | bug_class: stale-eligibility-reward-accrual | group_key: RetentionIncentives | _updateReward | stale-eligibility-reward-accrual
path: `src/dao/RetentionIncentives.sol:150-170`, reached through `getReward` at `src/dao/RetentionIncentives.sol:216-233`; the eligibility-changing burns occur in `InsurancePool.redeem`/`withdraw` at `src/protocol/InsurancePool.sol:314-347` without a retention checkpoint.
proof: At a checkpoint, let Alice have all 100e18 retention weight and 100e18 insurance-pool shares. Start a 700-token, seven-day reward period, then immediately let Alice complete the insurance-pool exit and redeem all shares. The redemption burns her insurance shares but does not call RetentionIncentives, so `_balances[Alice]` and `_totalSupply` both remain 100e18. Six days later Alice calls `getReward`. `_updateReward` first updates the global reward-per-token and executes `rewards[Alice] = earned(Alice)` at lines 152-159 using the stale 100e18 weight, banking approximately 600 tokens. Only at lines 162-169 does it observe `ipShares == 0` and reduce Alice's weight; `getReward` then transfers the already-banked reward. The repository's `test_balanceChange` independently records this exact state transition at `test/integration/Retention.t.sol:114-128` with the message `redeem all - earned grows until checkpoint`.
description: Insurance-pool balance decreases are not checkpointed when they occur, and `_updateReward` credits all elapsed rewards using the old weight before reducing it to the current insurance balance, so a snapshot holder can withdraw and continue collecting retention emissions until somebody voluntarily checkpoints them.
fix: Add a synchronous hook from every InsurancePool share-decrease path that checkpoints the retention account before the burn (or maintain timestamped balance checkpoints consumed by RetentionIncentives), so accrual is split at the actual eligibility-change time; in the reward contract, do not treat a newly observed lower balance as if it applied only after all elapsed rewards were credited.

FINDING | contract: TreasuryStableDiversification | function: swap | bug_class: unconsumed-treasury-asset-pull | group_key: TreasuryStableDiversification | swap | unconsumed-treasury-asset-pull
path: `src/dao/TreasuryStableDiversification.sol:124-162` permits a nonempty target set with `totalWeight == 0`, while `swap` at `src/dao/TreasuryStableDiversification.sol:165-225` always pulls the default asset before processing only the targets' custom input tokens.
proof: Configure the single target `{token: USDC, weight: 0, swapPool: address(0), vault: address(0), inputToken: USDC, stakedAsset: address(0), maxPrice: 0, maxSpotEmaDeviationBps: 0, executionBufferBps: 0}`. It passes every `setTargets` check and sets `totalWeight` to zero; `test_setTargetsAllowsInputTokenWithoutEarlierOutput` at `test/e2e/dao/TreasuryStableDiversification.t.sol:305-326` confirms custom-input-only target sets are accepted. With 1,000,000 default-asset units in the treasury, a 100,000-unit reserve, zero USDC in the helper, and `useOperators == false`, any caller can invoke `swap(type(uint256).max)`. Lines 171-177 pull 900,000 default-asset units, making the line-181 asset check pass. The sole loop iteration reads the helper's zero USDC balance at lines 188-197 and continues at line 206, and the function successfully exits without ever consuming or returning the 900,000 default-asset units. They remain stranded in the helper until an owner recovery transaction.
description: `swap` does not couple its treasury pull to the presence of a default-asset target, allowing a permissionless caller to move all treasury excess into the helper under a valid custom-input-only configuration even though no target can process that asset.
fix: Before pulling from the treasury, require a default-asset target when `amount != 0` (for example `totalWeight != 0` and a valid last-default-target index), or skip the pull entirely for custom-input-only executions and validate the relevant custom balance instead.

## Leads

LEAD | contract: RetentionIncentives | function: setAddressBalances | bug_class: unauthenticated-one-shot-initialization | group_key: RetentionIncentives | setAddressBalances | unauthenticated-one-shot-initialization
path: `src/dao/RetentionIncentives.sol:108-129`; deployment batching appears at `script/actions/DeployRetentionProgram.s.sol:29-44,47-68`.
code_smells: permissionless initializer, irreversible finalize flag, unchecked parallel arrays, duplicate-key total-supply inflation
description: The first arbitrary caller can set every initial reward weight and permanently finalize the contract; unequal array lengths revert incidentally, while duplicate addresses overwrite mapping balances but are all added to `_totalSupply`. The current deployment script appears to batch CREATE3 deployment and initialization atomically, so no live takeover window was proven; any non-atomic deployment or replacement would make the issue immediately exploitable. Enforce `onlyOwner`, validate equal lengths and unique nonzero accounts, and preferably initialize atomically in the constructor/factory.

LEAD | contract: Utilities | function: getPairInterestRate | bug_class: minimum-rate-overwrite | group_key: Utilities | getPairInterestRate | minimum-rate-overwrite
path: `src/protocol/Utilities.sol:80-102`.
code_smells: overwritten assignment, omitted previously computed bound, off-chain quote divergence
description: In the V1 branch line 96 computes `max(minimumRate, riskFreeRate)`, but line 97 immediately replaces it with `max(underlyingRate, riskFreeRate)`. For `minimumRate=100`, half-scaled underlying rate 30, and half-scaled risk-free rate 40, the utility returns 40 even though the calculator floor is 100. The contract describes itself as mainly for off-chain calculations and no in-scope state-changing consumer was found, so the demonstrated consequence is a bad integration/UI quote rather than direct asset loss. Return `max(minimumRate, max(underlyingRate, riskFreeRate))`.

LEAD | contract: Swapper | function: swap | bug_class: permissionless-residual-balance-sweep | group_key: Swapper | swap | permissionless-residual-balance-sweep
path: `src/protocol/Swapper.sol:55-112`.
code_smells: ignored account, ignored amount, full-contract-balance input, arbitrary recipient, no caller check for configured routes
description: For an already configured route, any caller can make the adapter exchange its entire `path[0]` balance and send the result to arbitrary `to`; `account` and `amountIn` are unused, and pair authentication occurs only when a route is undefined. Normal pair execution transfers and consumes funds atomically and `nonReentrant` blocks an in-flight callback theft, so only residual, donated, or mistakenly transferred balances were proven exposed. Authenticate registered pair callers, consume exactly `amountIn`, and bind the recipient to the requesting pair/account.

LEAD | contract: RouterSwapper | function: swap | bug_class: unbound-router-calldata | group_key: RouterSwapper | swap | unbound-router-calldata
path: `src/protocol/swappers/RouterSwapper.sol:25-40,42-50,71-125`.
code_smells: ignored semantic parameters, arbitrary low-level router call, unlimited approvals, permissionless execution
description: Any caller can encode arbitrary calldata into `_path` and make the adapter call the fixed router, while the nominal account, amount, and destination arguments are discarded. Because the adapter grants the router unlimited reUSD and registered-collateral allowances, router calldata can spend any such balance held by the adapter and choose an attacker recipient. No persistent non-dust adapter balance was established under normal atomic pair flow, so this remains a residual-balance exposure. Restrict callers to registered pairs and validate payload sell token, exact input amount, and recipient against explicit swap arguments (or replace opaque calldata with a typed router call).

LEAD | contract: UnderlyingOracle | function: getPrices | bug_class: unvalidated-chainlink-answer | group_key: UnderlyingOracle | getPrices | unvalidated-chainlink-answer
path: `src/protocol/UnderlyingOracle.sol:25-33`, consumed when redemption fees are computed at `src/protocol/RedemptionHandler.sol:223-229`.
code_smells: deprecated latestAnswer, signed-to-unsigned cast, no positivity check, no timestamp or completed-round check
description: A negative frxUSD answer is cast to a near-maximum `uint256`, while a stale positive answer is accepted indefinitely; RedemptionHandler then treats prices above 1e18 as an additive fee, potentially reverting or denying redemptions during invalid feed states. No unprivileged means to manipulate the fixed Chainlink feed was established, so the issue is an oracle-failure availability risk rather than a demonstrated attacker path. Use `latestRoundData`, require `answer > 0`, `updatedAt` within a configured heartbeat, and `answeredInRound >= roundId`, and define a fail-safe redemption policy.
