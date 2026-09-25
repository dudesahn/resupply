# Resupply proposal 29 payload review

The three encoded actions match the proposal description, and the exact stored proposal executes successfully on an isolated Ethereum fork. I found no incorrect target, amount, decimal scaling, execution order, or currently missing Core permission in the payload. There is an operational configuration gap: the new incentives claimer has no authorized callers at the reviewed block. Governance approval alone does not make it usable.

The material security decision is allowing the claimer owner's delegates to redirect the receiver's entire available RSUP allocation. This is intentional capability in the verified code, not a public access-control bypass. The owner is a 3-of-5 Safe that already has direct claiming permission on the receiver.

Review snapshot: Ethereum block **25,939,943**, September 9, 2026 at **12:54:11 UTC**. Transaction and state were obtained through JSON-RPC; verified source, ABI descriptions, deployment metadata and permission events through Etherscan API V2. No mainnet transaction was signed or broadcast. Brownie and its deployment cache were not used.

## Proposal identity and timing

- [Creation transaction](https://etherscan.io/tx/0x7e20940953b04fc5cf19d9bbcc3298ed37729be97ae8effe0f62bb02d88f3bf5): successful creation of proposal ID **29**, not execution of its payload.
- Created September 2, 2026 at 12:42:47 UTC, block 25,889,679.
- [Voter](https://etherscan.io/address/0x11111111063874ce8dc6232cb5c1c849359476e6#code): `0x11111111063874ce8dc6232cb5c1c849359476e6`.
- Description: “Migrate sfrxUSD debt limits from V1 to V2 and approve new liquidity incentives claimer contract”. The payload returned by `getProposalData(29)` agrees with the transaction input.
- At the snapshot, unprocessed; yes weight **9,121,882**, no weight **0**, quorum **8,798,678**. Quorum and a yes majority are satisfied, but `canExecute(29)` is false because the delay has not elapsed.
- Live settings: seven-day voting period, one-day execution delay, 21-day total execution deadline.
- Earliest execution: **September 10, 2026, 12:42:47 UTC** (08:42:47 EDT).
- Last permitted timestamp: **September 23, 2026, 12:42:47 UTC** (08:42:47 EDT), subject to the proposal remaining unprocessed and governance configuration remaining unchanged.

## Exact actions

| Order | Target | Decoded call | Effect |
|---|---|---|---|
| 1 | `0xC5184cccf85b81EDdc661330acB3E41bd89F34A1` | `setBorrowLimit(1)` | Reduces the old pair's cap from 50 million reUSD to **one base unit**, or 0.000000000000000001 reUSD. |
| 2 | `0x0950000465476F4470e74AeD93E7dd414012BB7D` | `setPairBorrowLimitRamp(0x0837E20D15585B4cA5c1a3fCedCCF8f72855Cb56, 40000000000000000000000000, 1790812800)` | Replaces the new pair's existing ramp with a ramp from its actual stored cap at execution to **40 million reUSD**, ending **October 1, 2026, 00:00:00 UTC**. |
| 3 | `0xC9a9C21F8740684129d271Ad1007E87E24858c59` | `setApprovedClaimer(0x1d9E146501CDCfad72Afa90C1144181036Ca5379, true)` | Authorizes the new `IncentivesMultiClaimer` to claim the liquidity incentives receiver's emissions. |

Selectors are respectively `0xe7a33174`, `0xbb8dd199`, and `0xfaf1e091`. The first argument is a uint256 value of 1, not a boolean. There is no ETH transfer, direct token transfer, mint, proxy upgrade, oracle change, ownership transfer, or LTV change in these three actions. Existing positions are not moved between markets.

## Pair and permission configuration

| Check | Old pair | New pair |
|---|---|---|
| Name | Resupply Pair (CurveLend: crvUSD/sfrxUSD) - 1 | Resupply Pair (CurveLendV2: crvUSD/sfrxUSD) - 1 |
| Resupply implementation version | 3.0.0 | 3.0.4 |
| Borrow limit at snapshot | 50,000,000 reUSD | 17,619,300 reUSD |
| Recorded debt at snapshot | Approximately 6,378,536.24 reUSD | Approximately 11,535,859.64 reUSD |
| Collateral vault | `0x8E3009b59200668e1efda0a2F2Ac42b24baa2982` | `0x3Da0F110079012387F47C6Fc6e878F10262E300a` |
| Vault asset / borrowed token | crvUSD | crvUSD |
| Vault's borrower collateral | sfrxUSD | sfrxUSD |
| Convex pool ID | 438 | 571 |
| Maximum LTV | 95% | 95% |
| Liquidation fee | 5% | 5% |
| Mint fee | 0 | 0 |
| Protocol share of redemption fee | 5% | 5% |
| Minimum borrowing amount | 1,000 reUSD | 1,000 reUSD |

Debt figures are stored accounting values; interest accrues with time. The “V1 to V2” description refers to the Curve lending markets, while the Resupply pair versions are 3.0.0 and 3.0.4.

Both pairs are owned by the correct [Core](https://etherscan.io/address/0xc07e000044f95655c11fda4cd37f70a94d7e0a7d#code) and point to registry `0x10101010E0C3171D894B71B3400668aF311e7D94`. The new pair is already registered under its actual name, allowing registry minting. Core points to the proposal's Voter. The BorrowLimitController has an existing global `setBorrowLimit(uint256)` permission with no hook; its empty pair-specific permission is therefore not a problem.

Convex pool 571's LP token matches the new collateral vault and its shutdown flag is false. The new Curve vault reports crvUSD as its asset, sfrxUSD as its collateral token, and the Curve ownership agent `0x40907540d8a6C65c637785e8f8B742ae6b0b9968` as admin.

Both pairs use oracle `0xa346BA5E838D6Ee40204A69549c81AB982644150` and rate calculator `0xD3d5C6fc52f3bc29C3aB017d57D9A94A036Ca90f`. The [oracle](https://etherscan.io/address/0xa346ba5e838d6ee40204a69549c81ab982644150#code) returns `convertToAssets(1e18)`. For the new vault, both calls return **1,002,770,290,630,644** base units at the snapshot. This approximately 1e15 scale is compatible with Curve vault shares and the pair's inverse-price calculation. The new pair's PriceWatcher lookup succeeds. These checks establish configuration compatibility; they do not establish that crvUSD or the underlying lending market is free of economic risk.

The verified 3.0.4 pair source also contains interest-initialization/preview changes and refreshes the oracle on each exchange-rate update instead of reusing a same-block value. The proposal uses this already deployed pair; it does not upgrade the old pair. Deployed source differs from the local checkout, so local constants alone were not treated as authoritative.

## Risks and operational requirements

### 1. The new incentives claimer is not yet configured for use

The [new claimer](https://etherscan.io/address/0x1d9e146501cdcfad72afa90c1144181036ca5379#code) was deployed September 2, 2026. Its constructor sets an owner but does not authorize any callers. Etherscan's event history through the snapshot contains no `ClaimerSet` events. Direct checks of the owner and deployer show `claimers(address) == false`.

The owner is Safe `0xFE11a5009f2121622271e7dd0FD470264e076af6`, configured with **three required signatures and five owners**, with no enabled modules returned by module enumeration. The owner is not exempt from `onlyClaimer`: even the Safe cannot call `claim()` successfully until explicitly allowlisted.

**Required operational step:** the Safe must configure the intended automation or operator addresses through `setClaimer`. That is not an action in this proposal. This does not block proposal execution and does not disable the existing claim paths, but the new path is unusable until configured. I cannot confirm the intended delegated addresses because none have been configured onchain.

### 2. Each delegated claimer can redirect all available liquidity emissions

`claimTo(recipient)` permits any nonzero recipient other than the claimer itself. It calls the [receiver's](https://etherscan.io/address/0xc9a9c21f8740684129d271ad1007e87e24858c59#code) `claimEmissions(recipient)`, which fetches emissions and transfers its entire available allocation. There is no recipient allowlist, amount cap, allocation split, or per-caller spending limit. Receiver ID 2 is active with weight 5,000, representing 50% of scheduled emissions under the checked configuration.

A compromised delegated key can take whatever allocation is available when it claims, and can repeat this while authorized. Multiple delegated callers compete for the same allocation. The fork confirmed this behavior: after a simulated owner-approved delegation, the delegated account sent approximately **191,692.41 RSUP** to an arbitrary test recipient at the simulated execution time. This is a counterfactual fork result, not a live balance or theft.

The Safe already has direct approved-claimer permission, so this does not newly give the Safe access to emissions. It lets the Safe give other addresses equivalent claiming power without a new governance vote. Existing approvals for the Safe and TreasuryManager `0x09500006956d172973138a5b38cfcd2277552bb9` remain active. If recipient-restricted automation is intended, the current contract does not implement that requirement. Governance can revoke the receiver's approval of the wrapper; the Safe can remove individual delegates.

### 3. The cap reduction stops new V1 borrowing; existing debt and risk remain

The one-wei cap is smaller than the 1,000-reUSD minimum borrowing amount. The pair's saturating available-debt calculation returns zero, including while its existing debt exceeds the cap. The payload neither calls liquidation nor changes any borrower's solvency parameters. Repayment, adding collateral, solvent withdrawals, redemptions and liquidation retain their existing code paths. Interest continues accruing.

Approximately 6.38 million reUSD of old-market debt remains at the snapshot. Users must repay or arrange a separate migration. Old-market sfrxUSD, crvUSD and Curve risks remain until positions unwind. With unchanged old debt and a fully utilized 40-million new cap, combined outstanding debt could be approximately **46.38 million reUSD**, plus subsequent interest.

As an integration detail, `currentUtilization()` becomes an extremely large debt-to-one-wei ratio. It does not overflow for the current values. The reviewed rate calculation does not use this utilization metric, but interfaces and monitoring should handle a wind-down market rather than interpreting the number as ordinary utilization.

### 4. The ramp needs transactions and starts from execution-time state

The [controller](https://etherscan.io/address/0x0950000465476f4470e74aed93e7dd414012bb7d#code) currently has a ramp from 1 million to 20 million for the new pair. Proposal execution overwrites that schedule, using the stored `borrowLimit()` at the time of execution. It does not first bring the old ramp up to its current preview. At the snapshot, the stored cap is 17,619,300 versus a preview of 17,742,800; that difference is compatible with periodic keeper updates.

Setting the ramp does not immediately change the pair's cap. Anyone may subsequently call `updatePairBorrowLimit(newPair)`, and that transaction is what applies progress. If updates stop, the stored cap stays at its last applied value. A final update at or after October 1 applies 40 million. Operations should ensure the existing updater continues to cover this pair.

The endpoint is an absolute timestamp, so later execution makes the ramp steeper. It still satisfies the controller's minimum seven-day duration throughout the current governance execution window: the proposal expires September 23 at 12:42:47 UTC, before the ramp's latest permitted starting time of September 24 at 00:00 UTC.

Execution would revert atomically if the new pair's cap were raised to 40 million or higher beforehand. Pausing or moving the cap outside the recorded ramp interval later can block ramp updates. No partial old-pair cap change persists if another proposal action reverts.

### 5. Larger exposure to the new external market

The new target doubles the previous ramp endpoint from 20 million to 40 million. A cap is borrowing capacity, not immediate debt issuance. The proposed cap exceeds the new vault's approximately 14.89 million crvUSD of assets at the snapshot; reaching it requires additional deposits and sufficient collateral under the 95% LTV rule.

The new pair already represents approximately 85% of the new Curve vault's shares at the snapshot. Risk is therefore concentrated in that external lending market. The oracle values vault shares in crvUSD and does not independently price a crvUSD dollar depeg. Underlying borrower losses, liquidation performance, withdrawal liquidity, Curve administration and sfrxUSD risk remain material. Address and oracle compatibility checks are not a stress test establishing that 40 million is an optimal cap.

## Local fork verification

The fork was pinned to the stated mainnet block. Governance execution tests only advanced the local timestamp; they did not alter proposal votes or permissions. Separate delegation tests impersonated the owner only on the local fork to characterize the intended trusted-owner capability.

- Exact `Voter.executeProposal(29)` succeeds at the earliest eligible timestamp, using approximately **156,455 gas**, emitting the three expected action events and `ProposalExecuted`.
- All three expected postconditions hold: V1 cap equals 1, V2 ramp targets 40 million at timestamp 1790812800, wrapper approval equals true.
- Execution leaves existing V1 recorded debt and V2's immediately stored cap unchanged.
- V1 available borrowing becomes zero, a new borrowing attempt reverts, and interest accrual still succeeds.
- Unapproved callers and the unallowlisted owner cannot claim through the wrapper.
- A simulated owner-authorized delegate can claim to an arbitrary recipient, confirming the unrestricted-recipient trust model.
- Permissionless midpoint and endpoint updates succeed; the endpoint cap is exactly 40,000,000e18.
- Execution near the governance deadline succeeds; execution before eligibility and after the deadline reverts.

The scripts, decoded payload, pinned state and simulation results are included alongside this report. Local simulation hashes in `simulation.json` are not mainnet transactions. This is a focused payload, configuration and integration review, not an exhaustive audit of every external Curve/Frax/Convex dependency, borrower exit scenario or future governance action.

**Assessment:** the encoded changes are mechanically correct and executable against the checked state once the delay expires. The new claimer requires allowlist setup, and its unrestricted delegated claiming authority should be accepted explicitly as part of the operational design. Keep the ramp updater active and continue tracking the old debt until it is repaid or migrated.
