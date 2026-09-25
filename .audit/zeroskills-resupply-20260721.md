# ZeroSkills Audit — resupply

## Audit metadata

- **Repository:** `resupply`
- **Audited commit:** `5f014fd5003bba32c0cf2049992f57a768728631`
- **Audit date:** 2026-07-21 (America/New_York)
- **Clean audit worktree:** `/private/tmp/zeroskills-resupply-20260721-5f014fd`
- **Methodologies used:** ZeroSkills `code-sleuth` and `symmetry-sniper` only
- **Production scope:** `src/**/*.sol` (repository-wide mechanical inventory; deep manual review of stateful and high-signal contracts)
- **Supporting scope:** relevant tests, deployment scripts/data, `foundry.toml`, `remappings.txt`, `package.json`, and pinned dependencies needed to validate observed behavior
- **Excluded as discovery evidence:** `audits/`, `disclosures/`, `.audit/`, prior findings, prior reports, synthesis files, and memory of prior reviews
- **Other frameworks:** Plamen, Codex Security, sc-auditor, SolidityGuard, solskill, and other audit frameworks were not run.

## Executive result

| Classification | Critical | High | Medium | Low | Informational |
|---|---:|---:|---:|---:|---:|
| Validated findings | 0 | 0 | 1 | 0 | 0 |
| Plausible leads needing more evidence | 0 | 0 | 0 | 0 | 0 |

The audit found one validated, deployment-conditional Medium-severity symmetry issue in `SavingsReUSD`: source-side OFT sends lock local ERC4626 shares, while destination-side receives release pre-existing destination shares. A fresh destination cannot receive its first transfer, and a liquid destination with a higher share price lets a sender exchange lower-value source shares for higher-value destination shares.

No reportable code-sleuth storage-safety issue was found. All high-signal memory copies that were mutated were either written back, intentionally returned as previews, or used only for local calculations. No production raw `sstore`/`sload`, attacker-directed unstructured slot write, diamond storage, or demonstrated proxy collision was present.

## Severity approach

- **Impact** measures the worst credible consequence under the stated assumptions.
- **Likelihood** considers attacker reachability, required configuration, and whether the relevant feature is active in the repository's deployment material.
- **Severity** is the conservative combination of impact and likelihood, not impact alone.

## Lane 1 — code-sleuth

### Scope reviewed

The lane first inventoried persistent state and writers across all Solidity production files. Deep review concentrated on:

- Pair accounting and user state: `ResupplyPairCore`, `ResupplyPair`, `RewardDistributorMultiEpoch`, and `VaultAccountingLibrary`.
- Vault/reward state: `InsurancePool`, `LinearRewardsErc4626`, `SavingsReUSD`, `GovStaker`, `MultiRewardsDistributor`, `RetentionIncentives`, `EmissionsController`, `FeeDepositController`, and `PriceWatcher`.
- Governance/registry state: `Core`, `Voter`, `ResupplyRegistry`, `ResupplyPairDeployer`, and `RedemptionHandler`.
- Upgradeable state: `KeeperV1`, `KeeperV2`, `BaseUpgradeableOperator`, `GuardianUpgradeable`, `TreasuryManagerUpgradeable`, and `RedemptionOperator`.
- Manual-slot and assembly signals throughout `src/`, including `BytesLib`, `RouterSwapper`, and deployment assembly.

The review traced external/public mutators to internal helpers, enumerated storage structs/mappings/arrays, inspected all high-signal storage-to-memory copies, searched for raw storage opcodes and manual slot constants, compared current UUPS layouts, and inspected deletion/auxiliary-accounting paths.

### Validated findings

None.

### Plausible leads needing more evidence

None.

### Informational notes

#### CS-I01 — Current Keeper layouts match, but upgrade validation is routinely bypassed

`KeeperV1.owner` and `KeeperV2.owner` are both the sole ordinary storage variable at slot 0 (`src/helpers/keepers/KeeperV1.sol:16`, `src/helpers/keepers/KeeperV2.sol:17`). `forge inspect KeeperV1 storage-layout` and `forge inspect KeeperV2 storage-layout` confirmed that layout. The integration upgrade/authentication tests also passed.

The process is weaker than the code state: `KeeperV2` declares `@custom:oz-upgrades-from Keeper` rather than `KeeperV1` (`src/helpers/keepers/KeeperV2.sol:12`), the Keeper upgrade test sets `unsafeSkipAllChecks = true` (`test/integration/Keeper.t.sol:18`), and the deployment helper does the same for Keeper deployment (`script/actions/DeployUpgradeableProxies.s.sol:64-70`). This is not an actual collision at this commit, so it is informational rather than a finding. Future upgrades should name the exact reference implementation and run storage validation without `unsafeSkipAllChecks`.

### False positives and suppressed leads

- **`GovStaker._checkpointAccount` returns a modified memory struct without always writing it internally.** This initially resembled a lost write at `src/dao/staking/GovStaker.sol:205-253`. Every state-changing caller that needs the returned changes persists them: `_stake` writes at line 103, `_cooldown` writes at line 140, the public checkpoint functions write at lines 183 and 202, and `migrateStake` passes the value into `_cooldown` at line 422. The no-pending branch updates `lastUpdateEpoch` directly at line 229. Suppressed.
- **`RedemptionHandler._getRedemptionFee` modifies memory rating data.** The execution path writes both returned values at `src/protocol/RedemptionHandler.sol:254-261`; `previewRedeem` intentionally discards them at lines 287-289. Suppressed.
- **`EmissionsController._fetchEmissions` modifies a memory allocation.** Both inactive and active branches write it back at `src/dao/emissions/EmissionsController.sol:248-255`. Suppressed.
- **Pair accounting caches structs in memory.** Interest, exchange-rate, borrow, repay, redemption, and liquidation paths write their modified structs back, including `currentRateInfo`/`totalBorrow` at `src/protocol/pair/ResupplyPairCore.sol:538-541`, `exchangeRateInfo` at lines 583-586, borrow totals at lines 659-665, repayment totals at lines 848-863, and redemption totals at lines 945-955. Suppressed.
- **`RetentionIncentives.setAddressBalances` can double-count duplicate accounts in `_totalSupply`.** The loop overwrites `_balances[account]` but adds every list entry to the total at `src/dao/RetentionIncentives.sol:108-129`. The reviewed production path deploys and initializes it in one Safe batch (`script/actions/DeployRetentionProgram.s.sol:24-45`), verifies the final total, and the checked snapshot contained no case-insensitive duplicate addresses. A non-atomic or differently sourced deployment would need a duplicate check and access-controlled initializer, but the reviewed deployment did not establish a reachable issue. Suppressed/deferred.
- **Array deletion in `TreasuryStableDiversification.setTargets`.** `delete _targets` is followed by full reconstruction and a replacement `totalWeight` write in the same reverting transaction (`src/dao/TreasuryStableDiversification.sol:124-162`). No stale auxiliary state remains. Suppressed.

### Non-applicable checks

- No production inline assembly uses `sstore` or `sload`.
- No attacker-influenced raw storage slot arithmetic was found.
- No diamond/facet storage architecture was present.
- UUPS implementation slots are inherited from the pinned OpenZeppelin implementation; no custom conflicting slot constants were present.
- Assembly found in production source handled memory, byte decoding, calls, or contract creation rather than arbitrary storage selection.

## Lane 2 — symmetry-sniper

### Scope reviewed

The lane mapped and compared these operation pairs and variants:

- `SavingsReUSD`: OFT `_debit`/`_credit`; ERC4626 `deposit`/`mint`/`withdraw`/`redeem`; signature deposit versus normal deposit.
- `InsurancePool`: `deposit`/`mint` versus `withdraw`/`redeem`; `exit`/`cancelExit`; share/asset rounding.
- `ResupplyPairCore`: borrow/repay, collateral add/remove in vault-share and underlying forms, stake/unstake hooks, and `repayWithCollateral`.
- `GovStaker`: stake/cooldown/unstake, stake-for versus delegated exits, and `exit` convenience behavior.
- `Stablecoin` and token contracts: mint/burn authorization and value direction.
- `EmissionsController`: activate/deactivate and batch receiver weight updates.
- `CurveLendMinterFactory`/`CurveLendOperator`: add/remove operators and increase/reduce supplied amounts.
- `RewardDistributorMultiEpoch`, `MultiRewardsDistributor`, `RetentionIncentives`, and `SimpleRewardStreamer`: single/forwarded/batch reward and checkpoint variants.
- `Voter`: single-action policy versus multi-action proposal validation and cancellation.
- Swappers: ERC4626 deposit/withdraw route symmetry and router approval/revocation behavior.

### Validated findings

### ZS-SS-01 — OFT share locking cannot safely bridge independent yield-bearing vault instances

- **Status:** Validated at code level; activation depends on configuring remote OFT peers.
- **Impact:** High
- **Likelihood:** Low
- **Severity:** Medium
- **Affected functions:** `SavingsReUSD._debit`, `SavingsReUSD._credit`
- **Evidence:** `src/protocol/sreusd/sreUSD.sol:136-160`, `src/protocol/sreusd/sreUSD.sol:169-191`

#### Invariant

A cross-chain send/receive pair must conserve the economic claim transferred. It must also ensure that a successful source-side debit can be satisfied on the destination.

#### Evidence and root cause

`_debit` does not burn shares. It subtracts shares from the sender and adds them to the **source vault's own balance** (`src/protocol/sreusd/sreUSD.sol:150-159`). `_credit` does not mint corresponding destination shares. It subtracts shares from the **destination vault's existing self-balance** and credits the receiver (`src/protocol/sreusd/sreUSD.sol:176-188`).

These two balances belong to independent ERC4626 instances and are neither automatically synchronized nor economically equivalent. The contract is built on pinned `@layerzerolabs/oft-evm` 3.1.0 (`package.json:45-50`), exposing the OFT send/receive flow around these overrides.

The repository's deployment script seeds the anti-inflation share at `address(0)`, not at the vault itself (`script/actions/DeploySreUsd.s.sol:54-66`), so that step does not provide inbound OFT liquidity. The existing OFT test only checks local metadata and that the vault initially has zero self-balance (`test/e2e/protocol/sreUSD.t.sol:157-163`); it does not exercise debit/credit.

#### Exploit or failure paths

**Failure path A — first inbound transfer locks at the destination:**

1. A user holds `N` source-chain sreUSD shares and calls the inherited OFT send after peers are configured.
2. `_debit` moves `N` shares into the source vault's self-balance.
3. A fresh destination vault has a zero self-balance.
4. `_credit` executes `balanceOf[address(this)] -= N` and reverts on underflow.
5. The source shares remain unavailable until destination share liquidity is introduced and the message can be retried; the contracts provide no explicit capacity quote or self-balance rebalancing mechanism.

**Failure path B — share-price divergence permits value extraction:**

1. Source sreUSD has a 1.0 asset/share exchange rate; destination sreUSD has a 2.0 asset/share exchange rate and `N` self-held shares available for OFT credits.
2. The user sends `N` source shares worth `N` assets.
3. `_credit` releases `N` destination shares worth `2N` assets.
4. The user redeems those destination shares for `2N` assets, while the source vault merely holds the user's locked source shares worth `N` assets.
5. The attacker gains `N` assets at the expense of the destination-side share liquidity. The extraction is limited by destination self-held shares but can be repeated as liquidity is replenished.

Yield-bearing ERC4626 exchange rates are expected to diverge across independent deployments because deposits, withdrawals, rewards, and timing differ. One-for-one **share count** is therefore not a conserved cross-chain unit.

#### Verification

A temporary Foundry harness exposed the internal functions on two fresh `SavingsReUSD` instances and ran two tests:

```text
forge test --match-path test/ZeroSkillsSavingsBridge.t.sol -vv

[PASS] testDifferentSharePricesCreateCrossChainValueExtraction()
[PASS] testFreshDestinationCannotCreditFirstInboundTransfer()
2 passed; 0 failed
```

The first test configured 100 source shares backed by 100 assets and 100 destination self-held shares backed by 200 assets. After `_debit(100)`, `_credit(100)`, and destination redemption, the sender held 200 assets while the source retained only the 100-asset backing. The second test proved that `_credit` on a destination with zero self-held shares reverts with arithmetic underflow.

The PoC file was removed after execution; the clean audit worktree was restored. Live remote peer configuration was not verified because no remote sreUSD deployment or peer configuration was present in the reviewed repository material.

#### Recommendation

Do not connect independent yield-bearing vault share contracts as a one-for-one OFT mesh. Prefer one of:

1. A canonical share token/vault on one chain with a rigorously backed adapter representation elsewhere.
2. Bridging the underlying asset and depositing on arrival, with user-supplied minimum destination shares and explicit exchange-rate/slippage handling.
3. A protocol-level cross-chain accounting design whose transferred unit represents a common asset value, not a local vault share count.

Destination capacity checks and liquidity rebalancing can prevent the immediate underflow/lock, but they do not solve exchange-rate arbitrage between independent ERC4626 share prices.

#### Open assumptions

- The inherited OFT send path will be enabled by configuring at least one remote peer.
- Remote instances would be independent yield-bearing vaults rather than a single canonical share ledger.
- If cross-chain functionality is intentionally dormant and peers will never be configured, likelihood is effectively none; the vulnerable code remains exposed for future activation.

### Plausible leads needing more evidence

None.

### Informational notes

- ERC4626 rounding was symmetric and conservative: deposit/redeem round down; mint/withdraw round up (`src/libraries/solmate/ERC4626.sol:46-115`, `src/libraries/solmate/ERC4626.sol:136-153`). sreUSD wraps all four paths with the same reward synchronization (`src/protocol/sreusd/LinearRewardsErc4626.sol:201-239`).
- InsurancePool applies the same withdrawal queue and ownership checks to withdraw/redeem, and its round-trip regressions passed (`src/protocol/InsurancePool.sol:215-348`, `src/protocol/InsurancePool.sol:379-445`).
- Pair borrow/repay share conversions round against the user and write both global and user ledgers; collateral add/remove paths update the same collateral balance and passed targeted regressions (`src/protocol/pair/ResupplyPairCore.sol:632-890`, `src/protocol/pair/ResupplyPairCore.sol:713-822`).

### False positives and suppressed leads

- **Voter batch validator short-circuit.** `_containsProposalCancelerPayload` returns `false` when it encounters a Core `setOperatorPermissions` selector with fewer than 164 bytes (`src/dao/Voter.sol:257-275`). A temporary PoC proved that putting such a malformed action first lets a later canceler action evade the single-action creation check at lines 154-163 and lets the resulting two-action proposal be canceled under lines 249-253. This is a syntactic policy bypass, but the malformed first Core action necessarily reverts during `executeProposal`, so the later permission action cannot execute atomically. Normal quorum/delay rules also remain. It therefore fails symmetry-sniper's security-impact gate and was suppressed.
- **Permissionless stake-for versus delegated cooldown/unstake.** Anyone may fund another account, but only the account/delegate can exit it (`src/dao/staking/GovStaker.sol:84-119`, `src/dao/staking/GovStaker.sol:158-170`). This is documented and cannot transfer the beneficiary's stake to the funder. Suppressed.
- **Stablecoin mint/burn authorization differs.** Operators/owner can mint, while holders or approved spenders can burn (`src/protocol/Stablecoin.sol:33-50`). This is normal token authority rather than a missing inverse guard. Suppressed.
- **Swapper deposit/withdraw route setup differs in approvals.** ERC4626 deposits require underlying approval; redemptions of owned shares do not (`src/protocol/Swapper.sol:68-105`). Both directions write their exact route mapping and the difference is required by token flow. Suppressed.
- **SimpleRewardStreamer batch length mismatch.** `setWeights` omits an explicit equal-length check (`src/protocol/SimpleRewardStreamer.sol:141-169`), but a shorter amount array reverts atomically and extra amount entries are ignored without bypassing per-account logic. Both single and batch use `_setWeight`. Suppressed.
- **`Voter.cancelProposal` only rechecks canceler payloads for single-action proposals.** Given the creation rule, this is consistent with the intended state. The only reproduced creation bypass requires an unexecutable malformed action as described above. Suppressed.

### Non-applicable checks

- No general multicall entry point was present.
- No paired open/close derivatives or order-book state machine was present.
- No non-atomic batch path intentionally continued after per-item failures in the reviewed critical state paths.
- Router/wrapper variants that merely forward to the same internal helper were treated as the same operation unless they changed authorization, accounting, or value movement.

## Verification summary

### Passing targeted checks

- Temporary Savings bridge PoC: 2/2 passed.
- Temporary Voter malformed-first-action PoCs: creation/cancellation bypass reproduced, and a second test confirmed that even a quorum-approved version reverts before the hidden action and leaves the proposal unprocessed; used to suppress rather than report the lead.
- `InsurancePool`: `test_Mint`, `test_WithdrawAndRedeem`, `test_CancelExit` — 3/3 passed.
- sreUSD: `test_Deposit(uint256)`, `test_Withdraw(uint256)` — 256 fuzz runs each, passed.
- `GovStaker`: `test_StakeAndUnstake` — passed.
- Pair accounting: `test_fuzz_repay(uint128)` — 256 fuzz runs, passed.
- Pair collateral: add/remove in both vault-share and underlying forms — 4/4 passed.
- Keeper: upgrade, authorization, and reinitialization regressions — passed.
- `forge inspect` confirmed current Keeper V1/V2 slot parity and recorded layouts for the three upgradeable operators.
- Targeted compilation compiled up to 228 files with Solidity 0.8.28 successfully.

### Blockers and non-blocking issues

- Initial submodule initialization was denied by the workspace metadata sandbox. The same scoped command was rerun with approval and succeeded.
- Node dependencies were absent from the clean worktree. The pinned dependencies were installed under ignored `node_modules/` with scripts, lockfile generation, audit, and funding output disabled. NPM emitted deprecation warnings but installation succeeded.
- Fork tests emitted non-blocking Foundry cache-file warnings and then passed.
- An initial set of Forge filters ending in `$` matched no tests; corrected filters were rerun and passed.
- A broad `forge build` compiled 147 via-IR units without emitting an error but did not finish after an extended wait; it was interrupted with exit code 130. This is a verification-time blocker only. Targeted production/test compilations and all PoCs completed successfully.
- A read-only `ps` diagnostic was blocked by the sandbox and was not escalated.

## Commands run

Primary setup and verification commands are reproduced exactly below. Numerous source reads used `rg -n ...` and `nl -ba <file> | sed -n '<range>p'`; they did not mutate the target.

```text
rg --files /Users/dudesahn/Documents/GitHub/codex/skill-research/ZeroSkills /Users/dudesahn/Documents/GitHub/dudesahn/other/resupply | sed -n '1,240p'
wc -l /Users/dudesahn/Documents/GitHub/codex/skill-research/ZeroSkills/code-sleuth/SKILL.md /Users/dudesahn/Documents/GitHub/codex/skill-research/ZeroSkills/symmetry-sniper/SKILL.md /Users/dudesahn/Documents/GitHub/codex/skill-research/ZeroSkills/README.md
git cat-file -t 5f014fd5003bba32c0cf2049992f57a768728631
git status --short
git worktree list --porcelain
git worktree add --detach /private/tmp/zeroskills-resupply-20260721-5f014fd 5f014fd5003bba32c0cf2049992f57a768728631
git rev-parse HEAD
git status --porcelain=v1 --untracked-files=all
git submodule status
git submodule update --init --recursive
npm install --ignore-scripts --no-package-lock --no-audit --no-fund

rg -n '\b(assembly|sstore|sload|delegatecall|StorageSlot|IMPLEMENTATION_SLOT|_SLOT|bytes32 (public |private |internal )?(constant|immutable))\b' src -g '*.sol'
rg -n '\b[A-Za-z_][A-Za-z0-9_]*\s+memory\s+[A-Za-z_][A-Za-z0-9_]*\s*=' src -g '*.sol' -g '!src/interfaces/**'
rg -n '\b(UUPSUpgradeable|Initializable|initializer|reinitializer|upgradeTo|upgradeToAndCall|_authorizeUpgrade|ERC1967|TransparentUpgradeableProxy|ProxyAdmin|delegatecall)\b' src script test -g '*.sol'
rg -n '\bdelete\s+' src -g '*.sol' -g '!src/interfaces/**'
rg -n '^\s*function\s+[^({]*(deposit|withdraw|redeem|mint|burn|stake|unstake|cooldown|borrow|repay|add|remove|register|unregister|activate|deactivate|queue|cancel|claim|lock|unlock|open|close|enter|exit|single|batch|many|multi)[A-Za-z0-9_]*\s*\(' src -g '*.sol' -g '!src/interfaces/**'

forge inspect KeeperV1 storage-layout
forge inspect KeeperV2 storage-layout
forge inspect RedemptionOperator storage-layout
forge inspect TreasuryManagerUpgradeable storage-layout
forge inspect GuardianUpgradeable storage-layout
forge test --match-path test/ZeroSkillsSavingsBridge.t.sol -vv
env MAINNET_URL=https://ethereum.publicnode.com forge test --match-path test/ZeroSkillsVoterBatch.t.sol -vv
env MAINNET_URL=https://ethereum.publicnode.com forge test --match-path test/ZeroSkillsVoterBatch.t.sol --match-test testHiddenCancelerProposalCannotExecute -vv
env MAINNET_URL=https://ethereum.publicnode.com forge test --match-path test/e2e/protocol/InsurancePool.t.sol --match-test 'test_Mint|test_WithdrawAndRedeem|test_CancelExit' -vv
env MAINNET_URL=https://ethereum.publicnode.com forge test --match-path test/e2e/protocol/sreUSD.t.sol --match-test 'test_Deposit|test_Withdraw' -vv
env MAINNET_URL=https://ethereum.publicnode.com forge test --match-path test/e2e/dao/GovStaker.staking.t.sol --match-test test_StakeAndUnstake -vv
env MAINNET_URL=https://ethereum.publicnode.com forge test --match-path test/e2e/Resupply.t.sol --match-test test_fuzz_repay -vv
env MAINNET_URL=https://ethereum.publicnode.com forge test --match-path test/e2e/protocol/PairTest.t.sol --match-test 'test_AddCollateral|test_RemoveCollateral' -vv
env MAINNET_URL=https://ethereum.publicnode.com forge test --match-path test/integration/Keeper.t.sol -vv
jq -r 'keys[] | ascii_downcase' deployment/data/ip_retention_snapshot.json | sort | uniq -d
forge build
```

## New findings, deferred leads, and files written

### New finding

- `ZS-SS-01` (Medium): OFT share locking cannot safely bridge independent yield-bearing vault instances.

### Suppressed or deferred leads

- Voter malformed-first-action batch bypass: reproduced but unexecutable, so no security impact established.
- Retention snapshot duplicate/permissionless initialization risk: production setup is atomic and the reviewed input is unique; defer hardening for reuse/non-atomic deployments.
- Keeper upgrade annotation/check-skipping process: current layout is safe; improve before future upgrades.
- All memory-copy lost-write candidates were traced to writebacks, preview-only use, or direct field persistence.

### Authored files

- **Retained:** `.audit/zeroskills-resupply-20260721.md`
- **Temporary, then deleted:** `/private/tmp/zeroskills-resupply-20260721-5f014fd/test/ZeroSkillsSavingsBridge.t.sol`
- **Temporary, then deleted:** `/private/tmp/zeroskills-resupply-20260721-5f014fd/test/ZeroSkillsVoterBatch.t.sol`

Tool-generated dependencies and build artifacts were written only under ignored `node_modules/`, `out/`, and `cache/` directories in the temporary audit worktree. No tracked file in the audit worktree was changed; final `git status --porcelain=v1 --untracked-files=all` was empty.

## Prompting and environment improvements

1. **Provide the ZeroSkills checkout path explicitly.** The phrase `GitHub/codex/skill-research/ZeroSkills` resolved locally this time, but an absolute path or pinned ZeroSkills commit would remove ambiguity and make methodology provenance reproducible.
2. **Pre-create the detached worktree with initialized submodules and pinned npm dependencies.** This would avoid two approval/setup steps and preserve more audit time for verification.
3. **Supply a dedicated read-only Ethereum RPC environment variable.** The repository expects `MAINNET_URL`; making it available in the audit environment avoids embedding a public endpoint in commands and reduces rate-limit/cache noise.
4. **Add first-class cross-chain OFT mocks.** The current sreUSD tests do not execute `_debit`/`_credit`. A two-endpoint test fixture with peer setup, failed-message retry, capacity accounting, and divergent ERC4626 prices would make this class of issue much easier to catch continuously.
5. **Add a fast non-via-IR audit build profile.** The default full build remained active for an extended period. A documented profile that compiles production contracts without scripts and with bounded optimizer settings would make whole-repo sanity checks predictable.
6. **Ask for desired deployment assumptions up front.** For example: “treat dormant cross-chain code as in-scope if it can be enabled by governance” versus “only report currently configured mainnet paths.” This audit treated enableable OFT behavior as in-scope but discounted likelihood because no peer configuration was present.
7. **Optionally request retained PoCs.** The prompt asked for one report file, so temporary tests were removed. Asking for `.audit/pocs/` artifacts would preserve executable evidence for engineering follow-up.
