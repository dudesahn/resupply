# Validation results

Target: `5f014fd5003bba32c0cf2049992f57a768728631`

The four highest-value candidates selected for executable validation passed as reproductions in the isolated worktree.

```text
env MAINNET_URL=https://ethereum.publicnode.com FOUNDRY_PROFILE=test forge test \
  --match-path test/codex-audit/ValidatedCandidates.t.sol \
  --match-test test_PoC -vv
```

Result: **4 passed, 0 failed**.

| Test | Validates |
|---|---|
| `test_PoC_availablePartialInsuranceCapacitySettlesNothing` | Partial insurance capacity is left unused and liquidation debt makes no progress. |
| `test_PoC_exitedAccountKeepsAccruingUntilCheckpoint` | An exited InsurancePool depositor continues accruing retention rewards at stale weight. |
| `test_PoC_replacementScheduleRetainsOldRateAndClock` | A replacement schedule retains the superseded active rate and update clock. |
| `test_PoC_checkpointFrequencyChangesDistributionCap` | Frequent checkpoints release more capped sreUSD rewards than one checkpoint over the same time. |

Baseline checks also passed:

- `test/e2e/protocol/LiquidationHandler.t.sol`: **8/8**.
- `test/integration/Retention.t.sol::test_balanceChange`: **1/1**.

The final test source is preserved as `ValidatedCandidates.t.sol`. Early harness iterations were corrected for snapshot-account selection and reward-period timing; the final consolidated run was clean. A full optimized build of all 431 compilation units was stopped because it was materially slower than the targeted closure, while each targeted test closure compiled successfully under `FOUNDRY_PROFILE=test`.

Foundry crashed inside the macOS sandbox during proxy initialization before executing tests. The final commands were therefore run through the approved unsandboxed execution path, using the public Ethereum RPC only for the existing fork-based Retention fixture.
