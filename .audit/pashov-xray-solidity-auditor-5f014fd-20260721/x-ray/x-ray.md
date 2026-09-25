# X-Ray Report

> Resupply Finance | **11,903 enumerated nSLOC**; audited protocol-authored production scope: **65 files / 8,109 nSLOC** | 5f014fd (`detached HEAD`) | Foundry | 21/07/26

---

## 1. Protocol Overview

**What it does:** Resupply is a CDP-based lending protocol that accepts yield-bearing stablecoin vault shares as collateral for reUSD debt and connects that debt system to reserves, redemptions, savings, governance, and emissions.

- **Users**: Borrowers supply ERC-4626 collateral, savers deposit reUSD, reserve LPs fund insurance, stakers govern and earn rewards, and searchers trigger liquidation or maintenance.
- **Core flow**: A `ResupplyPair` values vault-share collateral, records debt shares, and asks `ResupplyRegistry` to mint reUSD; repayment burns reUSD and collateral removal is solvency-checked.
- **Key mechanism**: Per-market debt/share accounting combines lazy interest accrual, mutable risk parameters, external price/vault integrations, and handler-routed liquidation/redemption.
- **Token model**: reUSD is the OFT stablecoin, RSUP is the OFT governance/emissions token, and sreUSD is an ERC-4626/OFT savings share backed by streamed reUSD assets.
- **Admin model**: Normal governance routes through `Voter` and `Core` with a one-week vote plus one-day execution delay, while pre-authorized operators and separately owned integration contracts act instantly within their grants.

For a visual overview of the protocol's architecture, see the [architecture diagram](architecture.svg).

### Contracts in Scope

The repository enumerator measured 11,903 nSLOC across the broader Solidity tree; the audited table below excludes interfaces, vendored Solmate code, test/mocks/harnesses, and `ExampleReceiver`, yielding exactly 65 protocol-authored production files and 8,109 nSLOC.

| Subsystem | Key Contracts | nSLOC | Role |
|-----------|---------------|------:|------|
| Authorization (3 files) | `CoreOwnable`, `DelegatedOps`, `EpochTracker` | 51 | Shared Core ownership, delegation, and epoch primitives |
| Automation (3 files) | `Keeper`, `KeeperV1`, `KeeperV2` | 233 | Permissionless/owner-configured maintenance sequencing |
| DAO core (8 files) | `Core`, `Voter`, `Treasury`, `GovToken`, `CurveLend*`, `RetentionIncentives`, `TreasuryStableDiversification` | 1,155 | Governance execution, treasury, token, retention, and external position control |
| Emissions (4 files) | `EmissionsController`, `RetentionReceiver`, `SimpleReceiver`, `SimpleReceiverFactory` | 408 | RSUP schedules, allocations, and receiver claims |
| Operators (10 files) | `Guardian*`, `TreasuryManager*`, `RedemptionOperator`, `BorrowLimitController`, `PairAdder`, `UpgradeOperator`, `VeCrvOperator` | 1,212 | Pre-authorized emergency, upgrade, redemption, treasury, and Curve operations |
| Staking (4 files) | `GovStaker`, `GovStakerEscrow`, `MultiRewardsDistributor`, `AutoStakeCallback` | 541 | RSUP staking, delegation/cooldown, escrow, and multi-token rewards |
| TGE (3 files) | `VestManager`, `VestManagerBase`, `PermaStaker` | 378 | Initial allocation, Merkle claims, legacy redemption, and vesting |
| Pair core (2 files) | `ResupplyPairCore`, `ResupplyPairConstants` | 690 | Collateral, debt shares, interest, solvency, redemption, and liquidation accounting |
| Protocol core (22 files) | `ResupplyPair`, registry/deployer, insurance, handlers, fees, rewards, rates, oracles, stablecoin, utilities | 2,997 | Market implementation and protocol-wide issuance, reserve, pricing, and routing services |
| Libraries (3 files) | `MathUtil`, `SafeERC20`, `VaultAccount` | 79 | Math, token safety, and amount/share conversions |
| Swappers (1 file) | `RouterSwapper` | 109 | Fixed-router payload execution and irreversible approval revocation |
| sreUSD (2 files) | `LinearRewardsErc4626`, `sreUSD` | 256 | Streamed ERC-4626 savings accounting and OFT share transport |
| **Audited production scope (65 files)** |  | **8,109** | **Protocol-authored production code** |

### How It Fits Together

The core trick: yield-bearing stablecoin vault shares secure reUSD debt while shared registry, handler, reserve, and reward modules reconcile issuance and value across markets.

### Collateral and Borrowing

```text
Borrower
└─ ResupplyPair.addCollateral() / borrow()
   ├─ ERC4626 collateral vault.deposit()        *underlying becomes vault shares*
   ├─ ResupplyPairCore._updateExchangeRate()    *oracle value is snapshotted*
   ├─ ResupplyPairCore._borrow()                *debt amount/shares and mint fee increase*
   └─ ResupplyRegistry.mint()
      └─ Stablecoin.mint()                      *reUSD reaches the receiver*
```

### Repayment and Collateral Exit

```text
Payer / Borrower
├─ ResupplyPair.repay()
│  └─ ResupplyPairCore._repay()
│     └─ Stablecoin.burn()                      *reUSD is destroyed; debt shares decrease*
└─ ResupplyPair.removeCollateral*()
   ├─ ResupplyPairCore._removeCollateral()      *recorded collateral decreases*
   └─ ERC4626 collateral vault.redeem()         *optional underlying payout*
      └─ isSolvent modifier                     *post-operation health is enforced*
```

### Liquidation and Reserve Settlement

```text
Liquidation searcher
└─ LiquidationHandler.liquidate()
   └─ ResupplyPair.liquidate()
      ├─ ResupplyPairCore._repay()               *borrower debt/shares are removed*
      ├─ ResupplyPairCore._removeCollateral()    *seized shares go to handler*
      └─ LiquidationHandler.processLiquidationDebt()
         ├─ ERC4626 collateral vault.redeem()
         └─ InsurancePool.burnAssets()           *covered reUSD reserves are burned*
```

### Redemption and Savings

```text
Redeemer
└─ RedemptionHandler.redeemFromPair()
   ├─ ResupplyPair.redeemCollateral()            *pair debt falls; collateral/write-off state changes*
   ├─ Stablecoin.burn()                          *accepted reUSD input is destroyed*
   └─ ERC4626 collateral vault.redeem()          *optional underlying delivery*

Saver
└─ sreUSD.deposit() / mint()
   └─ LinearRewardsErc4626.syncRewardsAndDistribution()
      └─ FeeDepositController.distribute()       *new reUSD rewards enter a linear cycle*
```

### Governance and Emissions

```text
RSUP staker / delegate
└─ Voter.createNewProposal() → voteForProposal()
   └─ Voter.executeProposal()                    *after voting and execution windows*
      └─ Core.execute()                          *proposal actions reach protocol targets*

EmissionsController._mintEmissions()
└─ GovToken.mint() → receiver allocation
   └─ SimpleReceiver / RetentionReceiver.claimEmissions()
      └─ rewards, staking, retention, or treasury destination
```

---

## 2. Threat & Trust Model

### Protocol Threat Profile

> Protocol classified as: **Lending/Borrowing** with **Stablecoin, Yield Aggregator/Vault, Governance, and Bridge** characteristics

The dominant code signals are collateral/debt-share markets with LTV, interest, oracle, borrowing, repayment, redemption, and liquidation paths; reUSD/RSUP/sreUSD add issuance, vault-share, governance, emissions, and LayerZero boundaries.

### Actors & Adversary Model

| Actor | Trust Level | Capabilities |
|-------|-------------|--------------|
| RSUP staker or delegate | Bounded (snapshot weight and proposal rules) | Creates/votes proposals; approved actions wait one week plus a one-day execution delay before permissionless execution. |
| `Voter` / `Core` | Trusted protocol authority | `Voter` may execute arbitrary target calldata through `Core`; `Core` self-calls change voter and operator permissions. |
| Core-authorized operator | Bounded (selector/target grant and optional hooks) | Acts instantly after authorization; zero-target grants cover one selector across all targets and are not globally pausable. |
| Guardian | Bounded emergency role | Instantly pauses pair borrowing, cancels/edits proposals, pauses InsurancePool withdrawal windows, cancels ramps, updates guards, and revokes swapper approvals. |
| Upgrade manager | Trusted within granted targets | Instantly calls `upgradeToAndCall` on targets carrying the exact Core permission; market pauses do not gate upgrades. |
| Treasury manager | Trusted asset operator | Instantly retrieves/approves assets and performs arbitrary treasury calls; no treasury-wide pause or per-action delay is present. |
| Redemption manager / approved caller | Bounded (fixed callback and profitability checks) | Configures callers or starts flash-funded redemptions with lender/token/fee/min-output/profit checks; no global pause applies. |
| Keeper owner / configured operator | Bounded maintenance role | Owner changes operators/minimum profit; public or configured work calls synchronize fees, savings, pairs, retention, and Curve operators. |
| Diversification owner / operator | Trusted local ownership domain | Owner instantly changes targets/routes/guards and retrieves tokens; swap is open unless operator gating is enabled. |
| CurveLend factory owner | Trusted local ownership domain | Instantly changes implementation, fee receiver, and market operators; each operator resolves admin dynamically from the factory. |

**Adversary Ranking** (ordered by protocol relevance and adjusted by history signals):

1. **Flash-capital borrower / composability actor** — Can combine borrowing, leverage, collateral repayment, redemption, vault conversion, and external liquidity within one transaction.
2. **Oracle and share-price actor** — Can trade or donate around Curve, Chainlink, and ERC-4626 values consumed by solvency, fees, rates, and redemptions.
3. **Compromised governance or operations keyholder** — May control voting influence, installed Core permissions, an operator manager, or a separately owned integration contract.
4. **Liquidation and redemption MEV searcher** — Can observe stressed accounts and order public liquidation, redemption, exchange-rate, and maintenance calls around volatility.
5. **Vault-share / reserve-run actor** — Can time share entry/exit, reward synchronization, queued InsurancePool withdrawals, and stablecoin redemptions around external liquidity.

See [entry-points.md](entry-points.md) for the full grep-verified map: **319 total / 84 permissionless / 110 role-gated / 118 admin-only / 7 initializers** after excluding `ExampleReceiver`.

### Trust Boundaries

- **User ↔ lending pair** — Reentrancy guards, lazy interest/price updates, borrow limits, and post-call solvency protect collateral/debt mutations, while external vault conversions remain part of the boundary (`ResupplyPairCore.sol:398-1239`).

- **Pair ↔ registry / stablecoin** — Registered-pair identity gates `ResupplyRegistry.mint`, while `Stablecoin` separately maintains its owner-controlled operator set (`ResupplyRegistry.sol:229-231`, `Stablecoin.sol:31-41`).

- **Pair ↔ oracle / vault** — Core-configured oracles and ERC-4626 conversions drive collateral value; validation differs across `BasicVaultOracle`, `UnderlyingOracle`, `ReusdOracle`, and pair logic.

- **Pair ↔ swapper** — Approved adapters receive newly minted reUSD or borrower collateral; pair-side balance deltas, minimum output, and final solvency are the local controls (`ResupplyPairCore.sol:1087-1261`).

- **Pair ↔ liquidation handler ↔ InsurancePool** — Handler-only pair entry and active-handler/reserve checks bind seized collateral, recorded liquidation debt, and reserve burns (`ResupplyPairCore.sol:994-1057`, `LiquidationHandler.sol:116-180`).

- **Voter ↔ Core ↔ target** — Proposal actions are delayed, but installed operator selector/target permissions execute instantly and optional hooks are themselves trust dependencies (`Voter.sol:287-301`, `Core.sol:52-71`).

- **Treasury / integrations ↔ external systems** — Core-owned treasury paths and separately owned diversification/CurveLend paths have distinct authorities, delays, output checks, and pause coverage.

### Key Attack Surfaces

- **Oracle normalization and consumer scaling** &nbsp;&#91;[X-3](invariants.md#x-3), [X-4](invariants.md#x-4)&#93; — Trace `ResupplyPairCore._updateExchangeRate`, oracle adapters, `PriceWatcher`, rate calculators, and fee weighting for denomination, bounds, freshness, and scale consistency.

- **Debt, collateral, and redemption write-off bookkeeping** &nbsp;&#91;[G-33](invariants.md#g-33), [G-35](invariants.md#g-35), [I-30](invariants.md#i-30), [I-31](invariants.md#i-31)&#93; — Follow shares, amounts, fee receivables, write-off checkpoints, and precision refactors across borrow, repay, transfer, liquidation, and repeated redemption.

- **Liquidation split accounting** &nbsp;&#91;[X-5](invariants.md#x-5), [X-6](invariants.md#x-6), [E-3](invariants.md#e-3)&#93; — Reconcile pair debt removal, transient caller state, collateral redemption, incentives, partial reserve coverage, and `debtByCollateral` in the complete handler sequence.

- **Leveraged and collateral-repayment swapper boundary** &nbsp;&#91;[G-38](invariants.md#g-38), [G-39](invariants.md#g-39), [I-17](invariants.md#i-17)&#93; — Trace allowlists, approval lifecycles, caller/route restrictions, balance snapshots, min-out propagation, dust, and final health checks for every adapter.

- **Instant administrative operations** — Distinguish delayed proposals from selector-wide Core grants, auth hooks, registry endpoint changes, guardian controls, treasury arbitrary calls, upgrades, and separately owned integrations.

- **Savings synchronization and cross-chain shares** &nbsp;&#91;[I-27](invariants.md#i-27), [I-28](invariants.md#i-28), [X-9](invariants.md#x-9), [E-7](invariants.md#e-7)&#93; — Check actual-balance synchronization, cycle transitions, previews, unsolicited assets, OFT escrowed shares, and fee-operator compatibility across call orderings.

- **InsurancePool shares and withdrawal lifecycle** &nbsp;&#91;[G-29](invariants.md#g-29), [G-30](invariants.md#g-30), [G-31](invariants.md#g-31), [I-23](invariants.md#i-23), [X-5](invariants.md#x-5)&#93; — Trace seed shares, reward precision epochs, queues/windows, minimum assets, liquidation burns, and partial-liquidity states.

- **Fee, reward, and emission epoch coupling** &nbsp;&#91;[I-5](invariants.md#i-5), [I-6](invariants.md#i-6), [I-20](invariants.md#i-20), [I-25](invariants.md#i-25), [X-7](invariants.md#x-7), [X-8](invariants.md#x-8)&#93; — Follow keeper ordering and failed downstream calls across fee deposit/controller, logger, reward handler, pairs, savings, staking, and emission receivers.

- **Treasury stable diversification** &nbsp;&#91;[G-47](invariants.md#g-47), [G-48](invariants.md#g-48), [I-29](invariants.md#i-29)&#93; — Review excess-over-minimum sizing, target chains, price/PPS guards, residual allocation, approvals, optional operator gating, and retrieval powers end to end.

- **Proxy initialization and storage evolution** — Compare implementation locking, initializers, UUPS authorization, manager ownership, call data, and storage layout across guardian, treasury-manager, redemption-operator, and keeper generations.

- **Pair deployment and registration provenance** — Trace SSTORE2 creation code, configuration selectors, CREATE2 salt/name uniqueness, seed-share burns, registry admission, default swappers, and Core ownership in deployment order.

### Upgrade Architecture Concerns

- **Core-authorized UUPS operators** — `BaseUpgradeableOperator._authorizeUpgrade` fixes authorization to `CORE`, while `UpgradeOperator` gives its manager instant execution on targets already carrying the exact Core permission.
- **Initializer coverage differs by implementation** — `RedemptionOperator` disables implementation initializers in its constructor; guardian, treasury-manager, and keeper generations rely on their own constructor/initializer deployment sequences.
- **Generational storage compatibility** — `GuardianUpgradeable`, `TreasuryManagerUpgradeable`, `RedemptionOperator`, `KeeperV1`, and `KeeperV2` combine inherited upgradeable storage with generation-specific fields that should be compared across implementation changes.

### Protocol-Type Concerns

**As a Lending/Borrowing protocol:**

- `VaultAccount.toAmount/toShares` applies optional upward rounding while `ResupplyPairCore` refactors debt precision by `1e12`; inspect boundary amounts around minimum borrow, repay, and redemption thresholds.
- `ResupplyPairCore._addInterest:466-541` updates at most once per block and conditionally accepts accrued interest only within `uint128`; exercise long inactivity and maximum-rate/amount boundaries.
- `ResupplyPairDeployer` derives token selectors, configuration, a human-readable name, and CREATE2 salt before registration; compare all supported protocol adapters and deployment defaults.

**As a Stablecoin / Vault / Bridge protocol:**

- `Stablecoin.mint/burn` locally changes reUSD supply while inherited OFT code governs cross-chain movement; reconcile configured operators, peers, and local/remote supply semantics.
- `CurveLendOperator.reduceAmount/withdraw_profit` depend on external ERC-4626 liquidity and factory destinations; check partial withdrawals and accounting when vault assets are temporarily unavailable.

### Temporal Risk Profile

**Deployment & Initialization:**

- `CurveLendOperator.initialize`, receiver clones, UUPS operators, keeper generations, pair seed shares, registry registration, default swappers, and OFT peers establish one-time assumptions before ordinary flows begin.

**Migration or Deprecation:**

- Keeper generations, one-shot `RewardHandler.migrateState`, staker migration, handler replacement, router approval revocation, and pair/deployer evolution should be traced for old permissions, allowances, pending rewards, and callable legacy paths.

### Composability & Dependency Risks

**Dependency Risk Map:**

> **ERC-4626 collateral vaults** — via `ResupplyPairCore` and `CurveLendOperator`
> - Assumes: Coherent `asset`, 18-decimal market assets, executable conversion/deposit/redeem behavior, and external liquidity.
> - Validates: Pair balance deltas/solvency and selected oracle bounds; diversification validates configured vault assets.
> - Mutability: Pair oracle/risk configuration is Core-controlled; external vault governance is out of scope.
> - On failure: The enclosing borrow, exit, liquidation, redemption, or operator transaction generally reverts.

> **Curve / Chainlink price sources** — via oracle adapters, `PriceWatcher`, and diversification
> - Assumes: Correct denomination, decimals, liveness, manipulation resistance, and pool coin orientation.
> - Validates: Adapter-specific scaling/bounds plus local spot/EMA and max-price guards where configured.
> - Mutability: Local oracle endpoints are administratively mutable; external governance is out of scope.
> - On failure: Calls revert or consumers receive the adapter-defined value/zero behavior.

> **Curve pools and router/swappers** — via `Swapper`, `RouterSwapper`, `RedemptionOperator`, and diversification
> - Assumes: Exact ABI/order, executable liquidity, allowance semantics, and output-token behavior.
> - Validates: Route/caller authorization and path-specific balance/min-output/fee/profit checks.
> - Mutability: Routes and allowances are locally configurable; external pools/router are outside scope.
> - On failure: The enclosing atomic route reverts unless its caller explicitly handles failure.

> **LayerZero endpoint and remote OFT peers** — via `Stablecoin`, `GovToken`, and `sreUSD`
> - Assumes: Endpoint authentication, peer mapping, message delivery, and remote supply/escrow compatibility.
> - Validates: Inherited OApp/OFT endpoint and peer authorization.
> - Mutability: Local inherited ownership configures peers; endpoint/remote contracts are out of scope.
> - On failure: Behavior follows the external messaging lifecycle and inherited OFT handling.

> **Convex / Prisma / Curve governance systems** — via pair rewards, `VeCrvOperator`, and CurveLend factory/operators
> - Assumes: Booster, reward, escrow, voting, boost, and fee-distributor semantics.
> - Validates: Local roles, configuration, return/revert behavior, and selected recovered-balance checks.
> - Mutability: External governance is out of scope; local manager/factory ownership is mutable.
> - On failure: The enclosing reward or operator action reverts or retains locally accounted assets.

> **crvUSD / frxUSD flash lenders** — via `RedemptionOperator`
> - Assumes: ERC-3156/Frax callback, fee, liquidity, and repayment behavior.
> - Validates: Fixed lender/token/initiator/data, fee cap, amount, min-output, repayment, and minimum-profit predicates.
> - Mutability: External lender/venue code is outside scope; approved callers and local allowances are mutable.
> - On failure: The flash-funded redemption transaction reverts atomically.

**Token Assumptions** *(unvalidated or operationally enforced)*:

- Pair admission assumes 18-decimal collateral vault shares/underlyings and token behavior without unmodeled fees, rebases, or silent balance changes.
- Third-party tokens may introduce pausing, blacklisting, nonstandard returns, permit/callbacks, or upgrade behavior not uniformly modeled by local accounting.

**Shared State Exposure**:

- Curve pools, ERC-4626 vaults, oracle feeds, LayerZero peers, Convex reward systems, and flash lenders are shared external state whose liquidity, pricing, governance, or availability may change independently.

---

## 3. Invariants

> ### 📋 Full invariant map: **[invariants.md](invariants.md)**
>
> A dedicated reference file contains the complete invariant analysis — do not look here for the catalog.
>
> - **52 Enforced Guards** (`G-1` … `G-52`) — per-call preconditions with `Check` / `Location` / `Purpose`
> - **33 Single-Contract Invariants** (`I-1` … `I-33`) — Conservation, Bound, Ratio, StateMachine, Temporal
> - **9 Cross-Contract Invariants** (`X-1` … `X-9`) — caller/callee pairs that cross scope boundaries
> - **7 Economic Invariants** (`E-1` … `E-7`) — higher-order properties deriving from `I-N` + `X-N`
> - **Structural enforcement:** 44 candidates are On-chain=**Yes** and 5 are On-chain=**No**
>
> Every inferred block cites a concrete delta pair, guard lift, state edge, temporal predicate, or cross-contract code pair; attack-surface bullets above link directly to relevant blocks.

---

## 4. Documentation Quality

| Aspect | Status | Notes |
|--------|--------|-------|
| README | Present | `README.md` gives the protocol summary, Foundry setup, environment variables, audit names, and an external documentation link. |
| NatSpec | ~794 doc-comment starts | Broad coverage across governance, lending, rewards, and operator entry points; low-level and wrapper coverage is uneven. |
| Spec/Whitepaper | Missing locally | No in-repository security specification or whitepaper was detected; the README links external docs that were not part of the local source corpus. |
| Inline Comments | Adequate | Accounting, reward epochs, deployment, and integration assumptions are often explained, but no single document consolidates them into a protocol invariant specification. |

---

## 5. Test Analysis

| Metric | Value | Source |
|--------|-------|--------|
| Test files | 95 | File scan (reliable independent of compilation) |
| Test functions | 470 | File scan (reliable independent of compilation) |
| Line coverage | Unavailable — fresh worktree lacks npm-installed imports | Foundry coverage requires successful compilation |
| Branch coverage | Unavailable — fresh worktree lacks npm-installed imports | Foundry coverage requires successful compilation |

The test corpus exists independently of the coverage failure; missing imports prevented coverage measurement, not test discovery.

### Test Depth

| Category | Count | Contracts Covered |
|----------|------:|-------------------|
| Unit / integration | 470 total functions | Broad; the file scan does not separately classify unit and integration tests |
| Fork | 3 signals | Mainnet/external-integration paths detected by scan |
| Stateless Fuzz | 1 | One fuzz test detected |
| Stateful Fuzz (Foundry) | 0 | None detected |
| Formal Verification | 0 | No Certora, Halmos, or HEVM specifications detected |

### Gaps

- No Foundry invariant/stateful-fuzz suite was detected for the multi-contract lending, liquidation, reserve, reward, and cross-chain state machines.
- Only one stateless fuzz test was detected across 470 test functions, leaving most financial boundary arithmetic covered by example-based tests.
- No formal-verification tooling or specifications were detected for share/debt conservation, solvency, issuance, or lifecycle properties.

---

## 6. Developer & Git History

> Repo shape: **normal_dev** — 703 of 1,174 commits touch source across 677 days (2024-09-10 through 2026-07-19); analyzed branch: `detached HEAD` at `5f014fd`.

### Contributors

| Author identities | Commits touching `src` | Source Lines (+/-) | % of Source Additions |
|-------------------|-----------------------:|--------------------|----------------------:|
| wavey0x / wavey | 432 | +15,542 / -8,429 | 48.2% |
| C2tP / c2tp / C2tP-C2tP | 282 | +16,473 / -6,220 | 51.2% |
| dudesahn | 4 | +199 / -140 | 0.6% |
| Thomas Clement | 5 | +11 / -6 | <0.1% |

Aliases are consolidated for readability; addition shares come from the supplied history analysis and deletion/commit counts from the current-HEAD Git log.

### Review & Process Signals

| Signal | Value | Assessment |
|--------|-------|------------|
| Unique contributor identities | 6 in analyzer output | Two primary author groups dominate source additions |
| Merge commits | 150 of 1,174 (12.8%) | Integration history is visible; merge count alone does not establish review depth |
| Repo age | 2024-09-10 → 2026-07-19 | 677-day development history |
| Recent source activity (30d) | 6 commits | All six co-changed tests; four touched the new diversification subsystem |
| Test co-change rate | 50.1% | Share of source-changing commits also modifying test files; not coverage |
| Fix candidates without tests | 30.0% | Three of ten scored candidates lacked test-file co-changes |
| Average commit size | 66.3 lines | No large-commit warning emitted by the analyzer |

### File Hotspots

| File | Modifications | Note |
|------|-------------:|------|
| `src/protocol/pair/ResupplyPairCore.sol` | 92 | Highest in-scope churn; central debt/collateral accounting |
| `src/protocol/RewardHandler.sol` | 44 | Reward routing and pair weighting |
| `src/protocol/ResupplyPair.sol` | 43 | Concrete pair configuration and fee paths |
| `src/protocol/InsurancePool.sol` | 43 | Reserve shares, rewards, and withdrawal queues |
| `src/protocol/RedemptionHandler.sol` | 42 | Stablecoin redemption and fee controls |
| `src/protocol/ResupplyPairDeployer.sol` | 40 | Pair provenance and default configuration |
| `src/protocol/LiquidationHandler.sol` | 39 | Collateral processing and reserve settlement |
| `src/dao/Voter.sol` | 33 | Proposal lifecycle and arbitrary action execution |
| `src/dao/emissions/EmissionsController.sol` | 31 | Mint schedule and allocation state |
| `src/protocol/Utilities.sol` | 26 | Solvency/rate helpers with stateful downstream reads |

### Security-Relevant Commits

**Score** is the analyzer's weighted combination of security language, guard/access/accounting diffs, affected domains, change shape, and test co-change; 10+ warrants manual diff review.

| SHA | Date | Subject | Score | Key Signal |
|-----|------|---------|------:|------------|
| `d1c5fb3` | 2024-12-11 | fix: `sweepUnclaimed()` overflow / locked tokens | 24 | Transfer/accounting and guard change with tests |
| `3611c31` | 2025-08-11 | split security and operator proposals | 19 | Guard/access changes across five domains; no test co-change |
| `ce3c87e` | 2024-12-29 | adjust migration workflow from audit comments | 19 | Staker migration access/accounting change with tests |
| `7ff7ba4` | 2024-10-03 | fix rewards modifier and formatting | 18 | Broad reward/access/accounting rewrite with tests |
| `93028ab` | 2025-07-03 | start creating retention program | 17 | New transfer/access/accounting surface with tests |
| `2be14ec` | 2024-12-11 | fix initial supply split in `VestManager` | 17 | Vesting supply/accounting change with tests |
| `99e5590` | 2026-06-25 | fix PairAdder registry execution | 16 | Registry guard/access change with tests |
| `d34e0f6` | 2024-12-11 | add reentrancy protection to `GovStaker.exit()` | 16 | Reentrancy/access change; no test co-change |
| `29744e3` | 2024-11-20 | fix redemption math again | 16 | Redemption guard/transfer math change with tests |
| `8b64924` | 2024-11-11 | add maximum redemption fee for ordering protection | 16 | New redemption guard; no test co-change |

### Dangerous Area Evolution

| Security Area | Commits | Key Files |
|--------------|--------:|-----------|
| Fund flows | 480 | `ResupplyPairCore`, `InsurancePool`, `LiquidationHandler` |
| Access control | 451 | `Core`, operators, registry, pair setters |
| Oracle / price | 352 | `ResupplyPairCore`, `PriceWatcher`, oracle adapters |
| Liquidation | 324 | `ResupplyPairCore`, `LiquidationHandler`, `InsurancePool` |
| Signatures / auth-shaped code | 71 | `Stablecoin`, `ResupplyPairDeployer`, reward streamers |
| State machines | 27 | `Guardian*`, `BorrowLimitController` |

### Forked Dependencies

No internalized forked libraries were detected. History records removal of `lib/openzeppelin-contracts-upgradeable` (`adc73ee`) and `lib/forge-safe` (`0b1f482`); current dependency provenance should be read from the present submodule/import configuration.

### Security Observations

- **Two-author concentration** — wavey0x/wavey and C2tP/c2tp aliases account for 99.4% of supplied source additions.
- **Review signal** — 150 merge commits exist, while the supplied analyzer does not establish approvals or reviewer identities.
- **Test co-change** — 50.1% of source-changing commits also modified tests; this measures co-modification, not execution or coverage.
- **Late subsystem activity** — four test-co-changed commits on 2026-07-16/17 introduced and refined `TreasuryStableDiversification` pricing, PPS, donation, and price-guard logic.
- **Dangerous-area concentration** — fund flows, access control, oracle pricing, and liquidation have 480, 451, 352, and 324 source-touching commits respectively.
- **Technical-debt scan** — no TODO/FIXME/HACK/XXX markers were reported by the supplied analysis.

### Cross-Reference Synthesis

- **`ResupplyPairCore` leads churn and accounting density** — 92 modifications plus [I-30](invariants.md#i-30), [I-31](invariants.md#i-31), and [X-6](invariants.md#x-6) make its borrow/redemption/liquidation transitions the highest-leverage trace.
- **Diversification is both late and structurally linked** — four recent test-co-changed commits intersect [G-47](invariants.md#g-47), [G-48](invariants.md#g-48), and [I-29](invariants.md#i-29).
- **PriceWatcher connects two high-churn domains** — 352 oracle/price commits intersect the consumer-scaling assumption in [X-4](invariants.md#x-4).
- **Operational authority spans distinct timing domains** — 451 access-control commits cross delayed governance, instant Core permissions, and separately owned integration contracts.

---

## X-Ray Verdict

**ADEQUATE** — The codebase has extensive example-based tests, one stateless fuzz test, broad NatSpec, and clearly identifiable role boundaries, but no Foundry stateful-invariant suite, formal verification, locally versioned specification, or measured coverage in this worktree.

**Structural facts:**

1. The enumerator measured 11,903 nSLOC; the audited protocol-authored production scope is 65 files and 8,109 nSLOC across 12 subsystems.
2. The final entry-point map contains 319 mutating entry points: 84 permissionless, 110 role-gated, 118 admin-only, and 7 initializers.
3. The invariant map contains 52 guards plus 49 structural candidates; 44 structural candidates are enforced on-chain and 5 are not.
4. The file scan found 95 test files, 470 test functions, one stateless fuzz test, zero Foundry invariants, three fork signals, and no formal-verification tooling.
5. The analyzed detached HEAD has 1,174 commits over 677 days; two consolidated author groups account for 99.4% of supplied source additions.
