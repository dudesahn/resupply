# Lane 04 — Execution Trace

[Feynman: LiquidationHandler.processLiquidationDebt] A liquidation hands the handler some newly seized collateral, records the unpaid loan, and pays the person who triggered the liquidation before attempting to use the remaining collateral to cover debt.

[Socratic: src/protocol/LiquidationHandler.sol:126 — why?] Why is the fixed incentive gated by the handler's entire withdrawable balance when only `_collateralAmount` belongs to this liquidation, especially when the alternate branch explicitly caps the payout to `_collateralAmount`?

[Inversion: processLiquidationDebt] 1) Leave 100 shares from earlier liquidations in the handler; 2) liquidate a borrower who contributes only 1 new share; 3) receive the fixed 25-asset incentive from the pooled 101-share balance, thereby consuming 24 shares that belong to earlier recoveries.

FINDING | contract: LiquidationHandler | function: processLiquidationDebt | bug_class: cross-liquidation-collateral-drain | group_key: LiquidationHandler | processLiquidationDebt | cross-liquidation-collateral-drain
path: attacker calls `liquidate(pair, borrower)` -> pair transfers the borrower's `_collateralAmount` -> `processLiquidationDebt` reads the handler-wide `maxWithdraw` -> fixed `liquidateIncentive` is withdrawn to the transient liquidation caller -> collateral accumulated from earlier liquidations funds the shortfall
input: a liquidatable borrower whose seizure contributes 1e18 collateral share while the handler already holds 100e18 shares and `liquidateIncentive` is 25e18
assumption: the incentive paid for one liquidation is bounded by the collateral seized in that liquidation
proof: at a 1:1 share price the handler's post-transfer balance and `maxWithdraw` are 101e18, so the `withdrawable >= liquidateIncentive` branch withdraws 25e18 assets even though `_collateralAmount` is only 1e18; the caller receives 24e18 of prior liquidation collateral, and four such 1-share liquidations can remove the full pre-existing 100e18 balance while contributing only 4e18
description: The liquid branch pays a fixed incentive against the handler's pooled collateral rather than the current liquidation's collateral, allowing small subsequent liquidations to divert recoveries seized from earlier borrowers.
fix: Compute the incentive from the assets represented by the current `_collateralAmount` and apply that same per-liquidation cap in both payout branches.

[Feynman: LiquidationHandler.processCollateral] The handler should spend whatever insurance capacity is currently available to reduce recorded bad debt, even when that capacity covers only part of the collateral ready to be sold.

[Socratic: src/protocol/LiquidationHandler.sol:156 — why?] Why does a request larger than `maxBurnable` skip all recovery when lines 171-173 already contain logic intended to clamp the actual burn to that limit?

[Inversion: processCollateral] 1) Record 1,000 assets of collateral debt; 2) make 600 assets withdrawable while the insurance pool can burn 500; 3) observe `toBurn <= maxBurnable` fail and leave all 1,000 debt untouched despite 500 immediately usable capacity.

FINDING | contract: LiquidationHandler | function: processCollateral | bug_class: partial-settlement-skipped | group_key: LiquidationHandler | processCollateral | partial-settlement-skipped
path: liquidation records collateral debt -> `processCollateral` computes `toBurn = min(maxWithdraw, collateralDebt)` -> `toBurn > maxBurnable` fails the outer guard -> no collateral is redeemed, no reUSD is burned, and no debt is reduced
input: attacker triggers a liquidation that leaves `debtByCollateral = 1000e18`, with `maxWithdraw = 600e18` and insurance-pool `maxBurnable = 500e18`
assumption: available insurance capacity is consumed up to its limit instead of requiring capacity for the entire withdrawable amount
proof: `toBurn` becomes 600e18, so the `toBurn <= maxBurnable` condition is false and the whole processing block is skipped; consequently 500e18 of usable burn capacity settles zero debt, and repeating sufficiently large liquidations can keep `toBurn` above capacity indefinitely
description: An all-or-nothing capacity guard prevents any bad-debt settlement whenever withdrawable collateral exceeds the insurance pool's current burn capacity.
fix: Cap the amount to process to `min(maxWithdraw, collateralDebt, maxBurnable)` and execute recovery whenever that capped amount is nonzero.

[Feynman: SavingsReUSD._debit] Sending savings tokens to another chain locks a number of local ownership tickets in this contract instead of destroying them.

[Feynman: SavingsReUSD._credit] Receiving on another chain releases the same number of that chain's ownership tickets from this contract, without checking whether those tickets represent the same amount of underlying money.

[Socratic: src/protocol/sreusd/sreUSD.sol:179 — why?] Why is the destination cache debited by the raw source share count when local reward accrual can make a share redeem for a different asset amount on each chain?

[Inversion: SavingsReUSD._credit] 1) Give chain A a 1.0 asset-per-share price and chain B a 1.2 price; 2) bridge 10 A shares while B has 10 cached self-held shares; 3) receive and redeem 10 B shares for 12 assets after supplying only 10 assets of value on A.

FINDING | contract: SavingsReUSD | function: _debit/_credit | bug_class: cross-chain-share-value-mismatch | group_key: SavingsReUSD | _debit/_credit | cross-chain-share-value-mismatch
path: attacker acquires shares on the lower-price chain -> OFT send calls `_debit` and escrows the raw share count -> remote message calls `_credit` -> destination releases the same raw count of independently valued local shares -> attacker redeems on the higher-price chain
input: bridge 10e18 shares from a chain with 1.0 reUSD per share to an enabled peer chain with 1.2 reUSD per share and at least 10e18 self-held destination shares
assumption: an sReUSD share has identical redeemable value and sufficient escrow inventory on every peer chain
proof: the source locks 10 shares worth 10 reUSD while the destination subtracts and transfers exactly 10 local shares worth 12 reUSD, yielding 2 reUSD of value at the expense of destination holders or prior bridge liquidity; independently, a fresh destination with zero self-held shares underflows on its first `_credit`, so one-way flow is limited to inventory created by reverse sends
description: Raw 1:1 transport of independently accruing ERC4626 shares lets users arbitrage cross-chain price-per-share divergence and makes inbound transfers dependent on reverse-flow escrow inventory.
fix: Bridge a canonical asset value or canonical share representation with explicit liquidity and price conversion rather than treating independently accruing local vault shares as fungible by count.

[Feynman: RetentionIncentives.setAddressBalances] This one-time setup call decides everyone's reward weight and permanently locks the list after the first successful caller.

[Socratic: src/dao/RetentionIncentives.sol:109 — why?] Why can any address finalize the initial allocation when a premature caller can choose both the recipients and their weights?

[Inversion: setAddressBalances] 1) Watch for a newly deployed but unfinalized contract; 2) call the public initializer first with only the attacker's address and a positive weight; 3) permanently finalize the attacker as the entire initialized reward supply before governance's intended call.

LEAD | contract: RetentionIncentives | function: setAddressBalances | bug_class: permissionless-one-shot-initializer | group_key: RetentionIncentives | setAddressBalances | permissionless-one-shot-initializer
code_smells: the one-shot external initializer has no caller restriction, accepts caller-selected addresses and balances, writes them unchecked, and sets `isFinalized = true`
description: A deployment that does not atomically execute `setAddressBalances` lets a frontrunner choose and permanently finalize the retention snapshot; the supplied production deployment script appears to batch deployment and initialization atomically, so current live exploitability was not established and this remains a deployment-sensitive lead.

[Feynman: ResupplyPairCore._calculateInterest] If newly accumulated interest would push the debt counter past its storage ceiling, the calculation throws away that entire interval's interest but still moves the calculation clock forward.

[Socratic: src/protocol/pair/ResupplyPairCore.sol:493 — why?] Why does the overflow-avoidance branch erase accrued interest while `_addInterest` still commits the new timestamp at line 536, making the skipped interval unrecoverable?

[Inversion: _calculateInterest] 1) Bring `totalBorrow.amount` close to the uint128 ceiling; 2) wait until the next interest increment would cross that ceiling; 3) call any interest-accruing entry point so `interestEarned` becomes zero and `lastTimestamp` advances, permanently forgiving that elapsed interest.

LEAD | contract: ResupplyPairCore | function: _calculateInterest | bug_class: overflow-boundary-interest-forgiveness | group_key: ResupplyPairCore | _calculateInterest | overflow-boundary-interest-forgiveness
code_smells: lines 486-496 zero the complete interest increment when `totalBorrow.amount + interestEarned` exceeds uint128, while `_addInterest` lines 519-541 still commits the new rate and timestamp
description: A near-uint128 debt state can permanently skip an accrued interest interval instead of saturating or reverting, but reaching that boundary under economic and protocol limits was not established.
