# Lane 09 — Boundary and Integration Audit

## Reportable candidates

[Feynman: RouterSwapper]
This adapter gives one outside router permission to take every supported token it ever holds, then lets any caller hand that router an arbitrary instruction without checking what will be spent or who will be paid.

[Feynman: RouterSwapper.swap]
The function unwraps bytes hidden inside an address array and forwards them verbatim to the router; all of the ordinary swap arguments that should limit the operation are ignored.

[Feynman: RouterSwapper.decode]
The first and last path entries look like token endpoints, but decoding uses neither endpoint and reconstructs only the caller-controlled middle bytes.

[Socratic: src/protocol/swappers/RouterSwapper.sol:35 — why?]
Why are `account`, `amountIn`, the advertised sell and buy tokens, and `to` all unbound while the forwarded payload can spend tokens under unlimited allowances?

[Inversion: RouterSwapper.swap]
1. Wait for reUSD or a registered collateral to reach the adapter through a refund, residue, or direct transfer; 2. encode a valid fixed-router call that sells that token from `msg.sender` and names the attacker as output receiver; 3. call `swap` so the router pulls the adapter's entire selected amount under its unlimited allowance and pays the attacker.

FINDING | contract: RouterSwapper | function: swap | bug_class: unrestricted-custody-call | group_key: RouterSwapper | swap | unrestricted-custody-call
path: src/protocol/swappers/RouterSwapper.sol:25-39,42-50,71-110
boundary: An untrusted external caller supplies raw calldata to the immutable third-party router, while that router holds unlimited allowances for reUSD and every registered pair collateral.
assumption: The encoded path is assumed to represent the declared token route and amount, and the caller is assumed to invoke the adapter only after supplying its own input.
actual: The function ignores all three semantic controls (`account`, `amountIn`, and `to`), `decode` ignores `path[0]` and the final token entry, and the low-level call forwards arbitrary caller-selected bytes from the adapter itself.
proof: With 100e18 reUSD on the adapter, an attacker encodes the fixed router's ordinary swap entry point with reUSD as input, 100e18 as input amount, and the attacker as receiver; `decode` returns those exact bytes, `router.call` sees `msg.sender == RouterSwapper`, and the constructor's `type(uint256).max` allowance lets the router pull the full 100e18, changing the adapter's reUSD balance from 100e18 to 0 while increasing the attacker's output-token balance, with no check binding any payload field to the outer call.
description: Any account can make the approved router execute arbitrary calldata from `RouterSwapper`, allowing it to steal any approved token balance held by the adapter.
fix: Restrict calls to registered pairs and decode and validate the exact sell token, amount, buy token, and receiver against the outer arguments while using per-call exact approvals that are revoked after execution.

[Feynman: Swapper]
This adapter stores approved conversion routes but does not keep each user's input separate from the rest of its balance.

[Feynman: Swapper.swap]
For every route step, the function spends every input token currently sitting in the adapter and sends the last output to an address chosen by the caller, even though the caller-provided amount is never used.

[Socratic: src/protocol/Swapper.sol:55 — why?]
Why does a public call spend `balanceOf(address(this))` rather than the supplied `amountIn`, and why is caller authentication applied only when a route is first created rather than whenever custody is spent?

[Inversion: Swapper.swap]
1. Observe a positive balance of a token for which an owner-configured route already exists; 2. call `swap(attacker, 1, [tokenIn, tokenOut], attacker)` without transferring any input; 3. let the approved pool spend the adapter's complete token balance and deliver the converted output to the attacker.

FINDING | contract: Swapper | function: swap | bug_class: entire-balance-public-swap | group_key: Swapper | swap | entire-balance-public-swap
path: src/protocol/Swapper.sol:40-60,62-72,99-109
boundary: Any external caller can invoke an existing owner-configured Curve or ERC-4626 route, and each route target has approval to spend the adapter's input token.
assumption: A caller is assumed to have just supplied `amountIn`, so the adapter's balance is treated as that caller's input.
actual: `account` and `amountIn` are unused, authentication runs only for an undefined route, each step reads the adapter's full balance, and the final output is sent to caller-controlled `to`.
proof: If the adapter holds 10e18 token A and `swapPools[A][B]` is already configured, an attacker calls `swap(attacker, 1, [A,B], attacker)`; line 64 sets `balanceIn` to 10e18, the undefined-route authentication is skipped, and lines 99-108 spend 10e18 through the approved target and credit B to the attacker, leaving the adapter with 0 A despite the attacker contributing nothing in this transaction.
description: Any account can convert and receive the adapter's complete balance along an existing route because `swap` ignores `amountIn` and does not authenticate callers for configured routes.
fix: Permit only registered pairs to call `swap`, consume exactly the supplied and balance-delta-verified `amountIn`, and reject any caller-selected receiver that is not the authenticated operation beneficiary.

## Leads requiring deployment or token-specific conditions

[Feynman: RetentionIncentives]
The contract gives rewards according to a one-time imported list of balances, but the first account to submit any list gets to make it permanent.

[Feynman: RetentionIncentives.setAddressBalances]
There is no owner check on the one-time setup function, so safety depends entirely on deployment and setup happening atomically.

[Socratic: src/dao/RetentionIncentives.sol:109 — why?]
Why can an arbitrary first caller permanently choose the reward weights, and where does the contract enforce that the deployment transaction also performs this initialization?

[Inversion: RetentionIncentives.setAddressBalances]
1. Monitor for a newly deployed but unfinalized instance; 2. front-run the intended setup with `[attacker]` and `[1e18]` or with empty arrays; 3. retain the forged reward weight or permanently prevent the intended snapshot because every later call reverts as finalized.

LEAD | contract: RetentionIncentives | function: setAddressBalances | bug_class: permissionless-one-shot-initializer | group_key: RetentionIncentives | setAddressBalances | permissionless-one-shot-initializer
path: src/dao/RetentionIncentives.sol:108-129; script/actions/DeployRetentionProgram.s.sol:24-44
boundary: An arbitrary caller supplies the permanent address and balance snapshot before `isFinalized` is set.
assumption: Deployment operations are expected to ensure that only the intended snapshot can be the first call.
actual: The contract itself has no caller check, but the production deployment script queues deployment and `setAddressBalances` in one Safe batch, and the configured deployed instance is already finalized with a nonzero intended supply.
proof: On a fresh instance, `setAddressBalances([attacker],[1e18])` succeeds, sets both attacker balance maps and total supply to 1e18, and sets `isFinalized=true`, after which the intended call reverts; present exploitability was not established because the live configured instance returns `true` for `isFinalized()` and the deployment script places initialization in the deployment batch.
code_smells: Public one-shot initialization, no owner/deployer authorization, no address/balance length equality check, and duplicate addresses can be accumulated into total supply while map entries are overwritten.
description: A split or non-atomic future deployment would let the first public caller forge or brick the permanent reward snapshot, although the reviewed live deployment appears already safely finalized.

[Feynman: GovStakerEscrow]
The escrow is supposed to release governance tokens when the staking contract says a cooldown is complete, but it never verifies that the token actually reports a successful transfer.

[Feynman: GovStaker._unstake]
The staking contract erases the user's claim before asking the escrow to pay, so a token that quietly returns false can make the claim disappear without payment.

[Socratic: src/dao/staking/GovStakerEscrow.sol:20 — why?]
Why is the ERC-20 boolean return value ignored after `GovStaker` has already deleted the user's cooldown record?

[Inversion: GovStaker._unstake]
1. Reach an instance whose configured stake token returns `false` rather than reverting on transfer failure; 2. wait until a user's cooldown matures or transfers become selectively blocked; 3. invoke unstake so the cooldown is deleted while the escrow's false-returning transfer delivers no tokens.

LEAD | contract: GovStakerEscrow | function: withdraw | bug_class: unchecked-erc20-return | group_key: GovStakerEscrow | withdraw | unchecked-erc20-return
path: src/dao/staking/GovStakerEscrow.sol:20-22; src/dao/staking/GovStaker.sol:158-170
boundary: The escrow calls an external ERC-20 and discards its boolean return after the staker has already deleted the withdrawal entitlement.
assumption: The immutable stake token is assumed either to revert on transfer failure or always return true.
actual: A standards-permitted false return is accepted as success, causing `_unstake` to emit success and permanently clear the cooldown without delivering assets.
proof: For a token whose `transfer(receiver, 5e18)` returns false without moving balances, `_unstake` reads 5e18, deletes `cooldowns[account]`, calls `withdraw`, and returns 5e18 while receiver balance changes by 0; the current deployment's fixed governance token was not shown to have this behavior, so this remains token/configuration-dependent.
code_smells: Raw `IERC20.transfer` with discarded return value on a state-clearing withdrawal path.
description: A false-returning configured stake token would let an unstake clear the user's claim without paying them, but the reviewed fixed governance token does not establish current exploitability.

## Other boundary surfaces reviewed

[Feynman: Core.execute]
Authorized operators can make external calls, but permissions are checked before execution and failed calls are bubbled rather than silently accepted.

[Feynman: RedemptionHandler.redeemFromPair]
The handler crosses into a pair and later settles tokens, but failures revert the whole transaction and the pair is validated through the registry.

[Feynman: LiquidationHandler]
The handler temporarily records who initiated a liquidation across a callback; approved vault and oracle boundaries remain trusted governance configuration rather than user-selected destinations.

[Feynman: VestManager.redeem]
The vesting adapter also uses a raw token return value, but the three configured production assets tested as reverting rather than returning false when an unauthorized transfer was attempted, so no concrete live failure was established.

[Feynman: LinearRewardsErc4626._distributeFees]
Fee assets pass through a configured vault and distributor; zero minimum output is a governance-configured price-protection choice rather than an untrusted boundary bypass in the reviewed flow.
