# Run manifest

## Identity and isolation

- Repository: `resupply`
- Commit: `5f014fd5003bba32c0cf2049992f57a768728631`
- Worktree: `/private/tmp/resupply-xray-solidity-auditor-5f014fd-20260721`
- Worktree state at launch: detached at the exact target commit
- X-Ray workflow version: 2
- Solidity Auditor workflow version: 3
- Solidity Auditor mode: `ALL`
- Scope: 65 protocol-authored production Solidity files / 8,109 nSLOC
- Scope manifest SHA-256: `8963bd368726f5b4ca5887d39e8537029e9e5a538c1d42f362a4ac59b9f42151`

The existing resupply `.audit` directory and the separate ZeroSkills worktree were not read by any discovery lane. The ytranche repository was consulted only for workflow structure and packaging lessons, using its multi-tool synthesis report and run notes; its findings were not supplied to X-Ray or Solidity Auditor.

## Scope construction

The scope includes protocol-authored production contracts and excludes interfaces, vendored Solmate code, mocks, tests, constants-only/helper harness files, the example receiver, and the pair errors interface. The exact paths are preserved in `audit-scope.txt`.

The normalized shared source bundle contained 12,396 lines and had SHA-256:

```text
b2dd724091963415ed1508378af3a3c4bd9c5c7d782655d7b5e239f2a4881e3c
```

## X-Ray orientation

X-Ray completed before Solidity Auditor and produced `x-ray.md`, `entry-points.md`, `invariants.md`, and `architecture.svg`. Its verdict was **ADEQUATE**. The inventory identified 319 mutating entry points and 101 explicit invariant blocks (52 global, 33 interaction, 9 external-call, and 7 economic).

Only the three final text artifacts were supplied as orientation to the Solidity Auditor lanes. X-Ray working notes and candidate drafts were not supplied.

## Two-wave all-lane execution

All 12 lanes were fresh agents with no inherited conversation context. Each received an agent-specific bundle containing identical sources and orientation plus only that lane's specialty instructions. Each wrote one raw output and could not read other outputs.

| Wave | Lane | Bundle lines | Bundle SHA-256 | Raw SHA-256 |
|---:|---|---:|---|---|
| 1 | math-precision | 12,573 | `ae49ecd591df965689815e5c94556cded8f1b60d97de82fab8d89cd4e8d1f3bf` | `98113a90919b28a4c567960338b78582a7bfef5025773e7a6db37dea0bb98237` |
| 1 | access-control | 12,552 | `8a342948eb21ca11bda0ab9821bf8e32ebc24ace57afae13ba76395c03b69caf` | `d43cb48f4094f9e5baeb443309169aef832befa8dd45bf471b191b3c57f82fbf` |
| 1 | economic-security | 12,560 | `c978d5f0ff48a1003b25085870ed18846522724099411f32d378a27404bfc803` | `a8bbc70ec5a682d2c4045d56dc068490d615560d6647aa13453c675db88b16cd` |
| 1 | execution-trace | 12,558 | `a85d2431054ad7cbec466d1ad5e374efbed48dffd46267d2ea02f47fc1ec170e` | `4504dc85f5bf538697fd19f74f7bbdfcdaa685c04d293f92b46a13510537a1c1` |
| 1 | invariant | 12,569 | `b315339e5c601906183c04c98ea103a89dca2504e33e05a773f2d3a1d27bb2e7` | `7df76fe7a201253f75716ade83845d298e0fced6b213f23d50b1a01e23d1f723` |
| 1 | periphery | 12,552 | `827c0368d5f233ff3cda01f339718544fd3296b95288086800ff7f86e33f9d91` | `fdd221acc91eeccc4b8345d097738e186ad4aa4566106b3949148101d51dbddf` |
| 2 | first-principles | 12,561 | `6905166a7485536f05d06d445b4ebae44e36941fee22bda1ecbb8b8b49e231d4` | `072daaede05514996b0c962ef6d12ad11443c366776285cb56d6d94e4ea1799f` |
| 2 | asymmetry | 12,602 | `b99be2253ed3f0d23e05595b7a38b24cf4ea3725c32a6ed27d5d3a4fd0f881a1` | `2aa0f6dbde0818b35100a55ad2a0470e1c3e82db8f04626217961a24dcf29b6a` |
| 2 | boundary | 12,604 | `27b569740a7bf6558320d1dbf2aaf4a48bd820c2603ee8177de340027d8e859a` | `5f0692be60a29d4bd657132455a1e5b2a1dd1f07f361b5f5cd47177f66704f2c` |
| 2 | numerical-gap | 12,571 | `05c71cd287eff2c58deafe99f303f64a40319859cda1d213c65a5375a34563ac` | `afda704654cfc8c3a4426b9d03631ea10a26e2cc7f01cc4437e8e5fe23f2b58a` |
| 2 | trust-gap | 12,565 | `608f84696c37ebc024a93d300786192a6a426213f300aa203a70d14709220bc7` | `65d3e1f0768f77b7487b08db4896448988a04185dcc06f809e3c06a19dd12f7a` |
| 2 | flow-gap | 12,574 | `e3fde4b38049f56ac0342aed143c0d0139c005cd6cb7843642addeb8c9b3bb15` | `372e20df95555b10205d1dbecdb68256ee0e6f50be2b455d90ae7157b4b1419d` |

The raw inventory contained 33 `FINDING` blocks and 34 `LEAD` blocks. Semantic grouping yielded 37 unique raw `(Contract, function)` surfaces. The single-pass fixed-gate review dispositioned all 37: 31 surfaces map to 10 promoted findings and 22 retained leads; six surfaces were rejected and appear only in the validation ledger.

## Validation environment

- Declared npm dependencies were installed with lifecycle scripts disabled so the target test closures could compile.
- npm reported 43 dependency advisories (16 low, 2 moderate, 19 high, 6 critical). These are toolchain metadata and were not treated as Solidity findings.
- Targeted Foundry compilation and tests used `FOUNDRY_PROFILE=test`.
- Four audit PoCs passed, the LiquidationHandler baseline passed 8/8, and the existing Retention baseline passed 1/1.
- The public Ethereum RPC was used only by the existing fork-based Retention fixture.
- The production source files were not modified.

The transient source/bundle directory was hashed for this manifest and removed before delivery. Raw lane outputs, the validation ledger, PoC source/results, X-Ray outputs, standard report, and synthesis are preserved.
