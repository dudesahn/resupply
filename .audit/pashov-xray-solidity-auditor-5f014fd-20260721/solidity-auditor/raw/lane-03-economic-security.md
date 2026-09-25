# Lane 03 — Economic Security

## Mental-tool trace

[Feynman: BasicVaultOracle.getPrices] The oracle asks a vault how many underlying tokens one share represents, but never asks what those underlying tokens are worth; a one-dollar token and a fifty-cent token therefore look identical.

[Socratic: src/protocol/BasicVaultOracle.sol:23 — why?] Why is one unit of an arbitrary stablecoin underlying treated as one unit of reUSD collateral value even though the protocol already deploys an underlying-price oracle for redemption economics?

[Inversion: ResupplyPairCore._isSolvent] An attacker can (1) buy a supported underlying after a downside depeg, (2) deposit that cheap underlying into its ERC4626 collateral vault, and (3) borrow reUSD against the nominal share-to-underlying ratio before abandoning the position.

[Feynman: UnderlyingOracle.getPrices] A price without a timestamp is not a current price; the handler cannot distinguish a live $1.00 answer from a week-old $1.00 answer during a $1.10 dislocation.

[Socratic: src/protocol/UnderlyingOracle.sol:31 — why?] Why does the frxUSD branch use `latestAnswer()` without proving that the answer is positive, fresh, or from a completed round before it sets the redemption fee?

[Inversion: RedemptionHandler.redeemFromPair] An attacker can (1) wait for reUSD to trade below the permissionless-redemption threshold, (2) acquire discounted reUSD while frxUSD trades above par but its feed is stale, and (3) redeem into overpriced frxUSD while paying only the stale low fee.

[Feynman: RewardDistributorMultiEpoch._checkpoint] Every debt or insurance bookkeeping operation first tries to harvest optional rewards, so an optional reward source can become the master switch for repayments, liquidations, and saver exits.

[Socratic: src/protocol/RewardDistributorMultiEpoch.sol:225 — why?] Why must a liquidation successfully call Convex, both emissions receivers, and PriceWatcher before it may update a borrower's debt?

[Inversion: RewardDistributorMultiEpoch._checkpoint] A hostile or failed dependency can (1) revert from Convex `getReward`, (2) revert from a registered reward token's `balanceOf` or `transfer`, or (3) revert from PriceWatcher/oracle maintenance, causing every checkpointed safety action to roll back.

[Feynman: LiquidationHandler.processCollateral] The handler refuses to pay ten dollars of debt when insurance can burn only nine dollars, even though paying nine immediately is strictly better than paying zero.

[Socratic: src/protocol/LiquidationHandler.sol:156 — why?] Why is the entire collateral batch gated on `toBurn <= maxBurnable` when the code later explicitly clamps `toBurn` to `maxBurnable`?

[Inversion: LiquidationHandler.processCollateral] An adverse sequence can (1) leave insurance burn capacity one wei below a collateral batch's debt, (2) repeatedly call processing while the all-or-nothing condition remains false, and (3) let the stranded collateral lose value while no debt is settled.

[Feynman: LinearRewardsErc4626.syncRewardsAndDistribution] A saver asking to leave the vault is forced to run the protocol's whole weekly fee-distribution job first; if any unrelated module in that job is down, the saver cannot leave.

[Socratic: src/protocol/sreusd/LinearRewardsErc4626.sol:225 — why?] Why is an external fee-controller call a prerequisite to burning savings shares and returning already-owned reUSD?

[Inversion: LinearRewardsErc4626._syncRewards] An external failure can (1) make the fee-deposit operator incompatible, (2) make the price oracle revert after the six-hour update interval, or (3) make a downstream reward queue revert, thereby rolling back every deposit, mint, withdraw, and redeem after cycle end.

[Feynman: InsurancePool max functions] A max function is a promise that the quoted operation can execute now; quoting a user's full balance while the cooldown forbids all withdrawals breaks that promise.

[Socratic: src/protocol/InsurancePool.sol:435 — why?] Why do `maxWithdraw` and `maxRedeem` ignore both the mandatory cooldown and the finite withdrawal window that the execution functions enforce?

[Inversion: InsurancePool ERC4626 limits] An integrator can (1) query a positive maximum before `exit`, (2) submit the quoted withdrawal and revert because no queue exists, or (3) query the same positive maximum after the queue window expired and revert again.

FINDING | contract: BasicVaultOracle | function: getPrices | bug_class: unpriced-underlying-depeg | group_key: BasicVaultOracle | getPrices | unpriced-underlying-depeg
path: attacker buys downside-depegged frxUSD/crvUSD → deposits it through ResupplyPairCore.borrow into the supported ERC4626 collateral vault → BasicVaultOracle.getPrices returns only `convertToAssets(1e18)` in underlying-token units → ResupplyPairCore._updateExchangeRate and _isSolvent treat those units as par-value reUSD collateral → attacker mints reUSD and abandons undercollateralized debt
proof: With the deployed default `maxLTV = 95_000`, suppose frxUSD trades at $0.50 while its vault still converts 1 share to 1 frxUSD. The attacker spends $500,000 for 1,000,000 frxUSD, receives approximately 1,000,000 vault shares, and BasicVaultOracle returns `1e18`; the pair therefore permits 950,000 reUSD of debt. The position is exactly 95% LTV to the contract but has only $500,000 of market-value collateral, leaving approximately $450,000 of immediately extractable value and $450,000 of unrecognized bad debt within the default 1,000,000 reUSD borrow limit.
description: Collateral solvency prices only the ERC4626 share-to-underlying conversion and implicitly hard-pegs every supported underlying at one reUSD, so a downside depeg lets cheap collateral mint near-par debt without ever becoming liquidatable on chain.
fix: Compose the ERC4626 share conversion with a downside-aware, freshness-checked underlying/reUSD price (and conservative source bounds), and use that composed price consistently for borrowing, redemption, and liquidation.

FINDING | contract: UnderlyingOracle | function: getPrices | bug_class: stale-oracle-over-redemption | group_key: UnderlyingOracle | getPrices | stale-oracle-over-redemption
path: frxUSD Chainlink feed stops updating at $1.00 → frxUSD appreciates while reUSD falls below the permissionless-redemption threshold → attacker buys discounted reUSD and calls RedemptionHandler.redeemFromPair → _getRedemptionFee accepts the stale `latestAnswer()` and omits the upward-depeg surcharge → pair collateral is redeemed below its current market value
proof: Let reUSD trade at $0.98, frxUSD trade at $1.10, and the stale feed still return $1.00. The default 1% base fee lets 1,000 reUSD redeem approximately 990 frxUSD worth $1,089, yielding about $109 against a $980 reUSD acquisition cost. A fresh $1.10 answer would add 10 percentage points, charge about 11%, and return only 890 frxUSD worth $979, removing the arbitrage. `latestAnswer()` supplies no timestamp, `answeredInRound`, or round-completeness evidence to distinguish these cases.
description: The frxUSD oracle branch accepts an unvalidated legacy Chainlink answer, so a stale low answer can suppress the exact fee surcharge intended to prevent value leakage when the redemption underlying trades above par.
fix: Use `latestRoundData()`, require a positive answer, completed/current round, nonzero timestamp, and a governance-set maximum age, with a conservative fallback or redemption pause when validation fails.

FINDING | contract: RewardDistributorMultiEpoch | function: _checkpoint | bug_class: optional-reward-dependency-freezes-safety-actions | group_key: RewardDistributorMultiEpoch | _checkpoint | optional-reward-dependency-freezes-safety-actions
path: external incentive or reward-token call reverts → RewardDistributorMultiEpoch._checkpoint reverts before integral bookkeeping → ResupplyPairCore._syncUserRedemptions/_repay and InsurancePool exit/redeem cannot complete → borrower liquidation, voluntary debt repayment, and insurance withdrawals are frozen
proof: Pair checkpoints call Registry.claimRewards, which calls Convex `poolInfo/getReward`, pair-emissions `getReward`, and PriceWatcher.updatePriceData without failure isolation; integral calculation also calls every registered reward token's `balanceOf`/`transfer`. If a borrower has $10,000,000 nominal collateral and $9,000,000 debt, then collateral falls to $8,000,000 while Convex `getReward` reverts, LiquidationHandler → pair.liquidate → `_isSolventSync` → `_checkpoint` reverts before any debt or collateral state change, leaving the full $1,000,000 deficit unresolved. The same `_checkpoint` path also prevents an insurance depositor with 1,000,000 reUSD of shares from starting or completing an exit.
description: Core solvency and withdrawal state transitions synchronously harvest optional external rewards, allowing any one reward dependency to disable liquidation, repayment, collateral removal, borrowing, and InsurancePool exits.
fix: Remove incentive harvesting from mandatory checkpoints and expose it as best-effort maintenance, or wrap each external reward source independently so accounting and safety actions always proceed when a reward source fails.

FINDING | contract: LiquidationHandler | function: processCollateral | bug_class: all-or-nothing-capacity-starvation | group_key: LiquidationHandler | processCollateral | all-or-nothing-capacity-starvation
path: liquidated collateral and debt accumulate in LiquidationHandler → insurance burn capacity is slightly smaller than `min(withdrawable, collateralDebt)` → outer `toBurn <= maxBurnable` check skips the entire redeem-and-burn block → collateral remains stranded and debt remains outstanding despite substantial usable insurance capacity
proof: If InsurancePool holds 20,000 reUSD with `minimumHeldAssets = 10,000`, `maxBurnableAssets()` is 10,000. For collateral with 10,500 withdrawable underlying and 10,001 debt, `toBurn = 10,001`, so the one-unit shortfall makes line 156 false: zero collateral is redeemed and zero debt is burned although 10,000 can be settled immediately. The later lines 171-173 already clamp a post-redeem amount to `maxBurnable`, demonstrating that partial settlement is supported after the gate but unreachable before it.
description: Liquidation settlement is unnecessarily all-or-nothing against current insurance capacity, so a minimal capacity shortfall can block nearly the entire debt repayment and strand collateral while its value deteriorates.
fix: Process `min(withdrawable, collateralDebt, maxBurnable)` on every call and redeem or withdraw only the collateral amount corresponding to that partial settlement.

FINDING | contract: LinearRewardsErc4626 | function: syncRewardsAndDistribution | bug_class: fee-maintenance-freezes-vault-exits | group_key: LinearRewardsErc4626 | syncRewardsAndDistribution | fee-maintenance-freezes-vault-exits
path: rewards cycle ends while fee epoch is undistributed → SavingsReUSD.withdraw/redeem calls syncRewardsAndDistribution → _syncRewards calls the mutable FeeDeposit operator's distribute() → FeeDepositController synchronously calls fee logging, PriceWatcher/oracle, token transfers, and reward queues → any dependency revert rolls back the user's share burn and asset transfer
proof: A saver owning 1,000,000 sreUSD shares redeemable for 1,000,000 reUSD cannot redeem any amount after cycle end if, for example, PriceWatcher is due for its six-hour update and its oracle reverts: `redeem` reaches `_distributeFees` → `FeeDepositController.distribute` → `PriceWatcher.updatePriceData` → oracle revert before `super.redeem`, so both the 1-share and 1,000,000-share exits revert. Setting FeeDeposit.operator to an incompatible address produces the same indefinite failure until governance repair.
description: SavingsReUSD makes all user entry and exit operations execute an unrelated multi-contract fee-distribution pipeline, turning an oracle, reward queue, or operator failure into a vault-wide withdrawal freeze.
fix: Decouple fee distribution from ERC4626 user operations and make cycle synchronization tolerate undistributed fees, with fee collection performed by a separate permissionless and failure-isolated maintenance call.

FINDING | contract: InsurancePool | function: maxDeposit/maxMint/maxWithdraw/maxRedeem | bug_class: erc4626-max-limit-mismatch | group_key: InsurancePool | maxDeposit/maxMint/maxWithdraw/maxRedeem | erc4626-max-limit-mismatch
path: integrator queries an InsurancePool ERC4626 max function → max function ignores `withdrawQueue`, cooldown readiness, and expired window → integrator submits the quoted standard deposit/withdraw/redeem operation → execution reverts on a lifecycle guard that the maximum did not report
proof: An owner with 100 shares worth 100 reUSD who has not called `exit()` receives `maxWithdraw(owner) = 100` and `maxRedeem(owner) = 100`, yet both `withdraw(100, ..., owner)` and `redeem(100, ..., owner)` revert on `exitTime > 0`. After the withdrawal window expires, the maxima remain 100 although execution reverts on `block.timestamp <= exitTime + withdrawTimeLimit`. Conversely, a queued receiver gets `maxDeposit(receiver) = 2^256-1` and `maxMint(receiver) = 2^256-1`, but depositing or minting even one unit reverts with `withdraw queued`.
description: InsurancePool's ERC4626 maximums report capacities that cannot execute under the pool's cooldown state, breaking composability and causing deterministic reverts for routers that rely on the standard limit contract.
fix: Return zero from deposit maxima for queued receivers and from withdrawal maxima unless the owner's queue is inside the live withdrawal window, while returning the actual executable balance only when ready.

LEAD | contract: BasicVaultOracle | function: getPrices | bug_class: zero-price-liquidation-freeze | group_key: BasicVaultOracle | getPrices | zero-price-liquidation-freeze
code_smells: The oracle rejects only prices at or above `1e22` and accepts zero, while ResupplyPairCore immediately evaluates `1e36 / priceFromOracle` before its explicit zero-exchange-rate check.
description: If catastrophic vault loss or integer rounding makes `convertToAssets(1e18)` return zero, every exchange-rate update, including liquidation, divides by zero and freezes bad-debt processing exactly at the loss boundary; confirm whether every deployed collateral vault mathematically guarantees a nonzero conversion under total-loss states.

LEAD | contract: RetentionIncentives | function: setAddressBalances | bug_class: unprotected-one-time-initializer | group_key: RetentionIncentives | setAddressBalances | unprotected-one-time-initializer
code_smells: The one-time function has no caller authorization, does not check equal array lengths explicitly, and does not reject duplicate addresses even though every entry is added to `_totalSupply` while duplicate mappings overwrite.
description: A non-atomic or ad-hoc deployment could be permanently hijacked by the first caller or initialized with duplicate-inflated supply; the supplied production deployment script appears to batch deployment and initialization atomically, so validate the actual on-chain creation transaction before promoting this deployment-contingent lead.
