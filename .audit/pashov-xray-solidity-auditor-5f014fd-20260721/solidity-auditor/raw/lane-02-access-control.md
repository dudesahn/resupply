# Access-control lane raw output

## Mental-tool trace

[Feynman: Core.execute]
This is the protocol's central dispatcher: the voter may make any call, while every other caller needs a stored permission for the destination and requested action. A permission for the zero destination deliberately applies that action to every destination, and an optional checker may approve both before and after the call.

[Inversion: Core.execute]
1. Call with a three-byte payload so action extraction fails before a permission lookup. 2. Use an action identifier shared by two destinations and try the zero-destination permission against the unintended one. 3. Reenter through a permission checker or destination while the first dispatch is still active.

[Feynman: RetentionIncentives.setAddressBalances]
This is the one-time ceremony that chooses every participant's starting reward weight, totals those weights, and permanently closes setup. Whoever wins the first call chooses the reward population and prevents every later correction through this function.

[Socratic: src/dao/RetentionIncentives.sol:109 — why?]
Why may any address perform the only irreversible write of the reward population when the adjacent handler setter requires the protocol owner? The hidden assumption is that deployment and setup will always be indivisible.

[Inversion: RetentionIncentives.setAddressBalances]
1. Call first with `[attacker]` and `[1e18]` to become the sole initial weight. 2. Call first with two duplicate attacker entries to corrupt the aggregate while retaining one address balance. 3. Call first with empty arrays merely to set `isFinalized=true` and permanently block the intended snapshot.

[Feynman: RetentionIncentives._updateReward]
This first credits all rewards earned using the account's old recorded weight, then compares that weight with the account's current insurance-pool shares and only afterward reduces it. A bogus starting weight therefore still earns everything accumulated before its first checkpoint.

[Socratic: src/dao/RetentionIncentives.sol:157 — why?]
Why is reward credit performed before the insurance-pool balance can remove an illegitimate initial weight? The design assumes the one-time snapshot itself was authorized and truthful.

[Inversion: RetentionIncentives._updateReward]
1. Wait until the full seven-day stream accrues before the attacker's first checkpoint. 2. Claim once immediately before a legitimate keeper checkpoints the attacker. 3. Hold zero insurance shares and rely on the credit-before-clamp ordering to preserve the already accrued payout.

[Feynman: SimpleReceiver.initialize]
This gives a newly copied receiver its name and its initial claimers exactly once. In the provided factory flow the copy is created and configured in the same call, so an outside caller has no transaction boundary in which to take the first call.

[Inversion: SimpleReceiver.initialize]
1. Try to configure the standalone implementation, but its constructor already closes setup. 2. Predict the copy address and call it before creation, which reaches no code. 3. Race after creation, but factory creation and configuration are atomic.

[Feynman: CurveLendOperator.initialize]
This binds a fresh market operator to one factory and one vault, grants the vault spending power over its stablecoin, pulls its initial budget, and then permanently fixes that binding. The factory creates and configures the copy within one transaction, while direct initialization of the standalone implementation does not make it a registered market operator.

[Inversion: CurveLendOperator.initialize]
1. Initialize the standalone implementation with an attacker factory. 2. Predict and call a future clone before it exists. 3. Reenter during clone initialization and attempt a second initialization after `market` has been written.

[Feynman: GuardianUpgradeable.initialize]
This assigns the emergency key on a new proxy. The body does not identify who may make the first call, but the supplied deployment helper places this call in the proxy constructor, leaving no observable uninitialized proxy in that path.

[Feynman: TreasuryManagerUpgradeable.initialize]
This assigns the treasury operations key on a new proxy. As with the guardian, the body trusts whoever calls first, while the supplied proxy deployment sends the initialization data during creation.

[Socratic: src/dao/operators/TreasuryManagerUpgradeable.sol:31 — why?]
Why does the initializer itself accept any first caller? The deployment system, rather than the contract, is assumed to guarantee an atomic first call.

[Inversion: TreasuryManagerUpgradeable.initialize]
1. Search for a proxy deployment with empty initialization data. 2. Call the standalone implementation and test whether it owns any Core permissions. 3. Race a separately deployed proxy before its setup transaction; the provided deployment path defeats this by initializing during creation.

[Feynman: Swapper.swap]
This converts every unit of the adapter's current first-token balance along a stored route and sends the final output to the caller-selected destination. For existing routes it does not check that a registered pair called, and it does not use the supplied account or amount.

[Socratic: src/protocol/Swapper.sol:64 — why?]
Why is the adapter's entire balance used instead of the requested amount? The hidden belief is that the adapter can only ever hold the exact balance just delivered by a pair in the same transaction.

[Inversion: Swapper.swap]
1. Call an existing route directly with `to=attacker` after any input residue appears. 2. Supply `amountIn=0`, which is ignored, while the adapter converts its full balance. 3. Choose a multi-hop stored path that ends in an attacker-controlled recipient.

[Feynman: RouterSwapper.swap]
This reconstructs arbitrary instructions from the supplied path and makes the fixed router execute them as the adapter. It does not authenticate a pair or bind the instructions to the nominal amount, account, path endpoints, or recipient.

[Inversion: RouterSwapper.swap]
1. Encode router instructions that spend an approved token balance and pay the attacker. 2. Call directly rather than through a pair because no caller check exists. 3. Target any collateral for which the public approval updater has already granted the router unlimited spending power.

[Feynman: RouterSwapper.updateApprovals]
This lets anyone extend the fixed router's unlimited spending permission to collateral from newly registered pairs. It cannot restore permissions after the owner's one-way emergency revocation.

[Inversion: RouterSwapper.updateApprovals]
1. Call immediately after a new pair is registered to maximize the router's approved token set. 2. Attempt to call after revocation, but the one-way flag makes it return. 3. Combine an already granted approval with the unrestricted router payload entry point.

[Feynman: ResupplyRegistry.mint]
This lets only the exact contract registered under its own market name issue stablecoins. Merely copying a registered name does not pass because the stored address must also equal the caller.

[Inversion: ResupplyRegistry.mint]
1. Deploy a contract that reports the same name but has a different address. 2. Reenter while a pair is being registered before its name write completes. 3. Make a legitimate pair call the registry outside its ordinary borrow path; no such caller-controlled forwarding path was found.

[Feynman: VestManagerBase.claimWithCallback]
This lets an account or its chosen delegate move newly vested tokens into an arbitrary callback and asks that callback to handle them for the resolved recipient. Choosing a dishonest callback is therefore an authority the account explicitly grants, not an untrusted-caller escalation.

[Inversion: VestManagerBase.claimWithCallback]
1. Call for another account without its delegate approval. 2. Use a callback that retains the tokens, which requires the account or its approved delegate to select it. 3. Reenter before claimed state is recorded, but claimed state is advanced before the callback.

## Candidate output

FINDING | contract: RetentionIncentives | function: setAddressBalances | bug_class: unprotected-initialization | group_key: RetentionIncentives | setAddressBalances | unprotected-initialization
file: src/dao/RetentionIncentives.sol:109
path: arbitrary caller → `setAddressBalances([attacker],[1e18])` before setup → attacker becomes the sole initial reward weight and `isFinalized` permanently closes setup → legitimate reward funding accrues to attacker → permissionless `getReward(attacker)` transfers the stream to attacker
guard_gap: `setAddressBalances` performs the irreversible authority-defining snapshot with only `!isFinalized`, whereas the adjacent configuration function `setRewardHandler` is protected by `onlyOwner`.
proof: Starting from a fresh deployment (`isFinalized=false`, `_totalSupply=0`), attacker calls `setAddressBalances([attacker],[1e18])`; lines 118-127 write both attacker weight mappings to `1e18`, `_totalSupply=1e18`, and `isFinalized=true`, so the intended snapshot now reverts. If the legitimate reward manager then queues `604800e18` tokens for the seven-day (`604800` second) duration, `rewardRate=1e18` token-wei per second and after seven days `earned(attacker)=604800e18`; on the attacker's first claim, `_updateReward` credits that amount at line 158 before lines 162-169 can clamp the attacker's weight to a zero insurance-pool balance, so the entire stream is transferred to attacker.
description: The one-time retention snapshot lacks authentication, allowing the first external caller to seize all initial reward weight, permanently block the intended allocation, and claim a fully funded reward cycle.
fix: Restrict `setAddressBalances` to `onlyOwner` and execute deployment plus initialization atomically (while also validating equal lengths and unique nonzero accounts).

LEAD | contract: Swapper | function: swap | bug_class: permissionless-adapter-balance-drain | group_key: Swapper | swap | permissionless-adapter-balance-drain
code_smells: For every preconfigured route, any caller may invoke `swap`, the `account` and `amountIn` arguments are ignored, line 64 selects the adapter's entire token balance, and line 66 sends the final output to arbitrary `to`; only creation of a previously undefined vault route authenticates a registered pair.
description: Any persistent input-token balance on the adapter is directly drainable through an existing route, but a production path that leaves such a balance after the normal full-balance ERC4626/Curve operations remains unverified.

LEAD | contract: RouterSwapper | function: swap | bug_class: unrestricted-confused-deputy | group_key: RouterSwapper | swap | unrestricted-confused-deputy
code_smells: The adapter grants the fixed router unlimited reUSD and registered-collateral allowances, yet any caller can supply arbitrary reconstructed router calldata and `swap` does not bind that payload to a registered pair, expected sell token, amount, buy token, or recipient.
description: A direct caller can potentially make the adapter act as an approved token-spending deputy and drain any retained approved-token balance, but the fixed router's exact callable ABI and a nonzero production balance source remain to be proven outside scope.
