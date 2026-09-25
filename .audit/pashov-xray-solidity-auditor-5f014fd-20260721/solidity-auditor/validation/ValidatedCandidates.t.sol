// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { EmissionsControllerTest } from "test/e2e/dao/emissions/EmissionsController.t.sol";
import { LiquidationHandlerTest } from "test/e2e/protocol/LiquidationHandler.t.sol";
import { SreUSDTest } from "test/e2e/protocol/sreUSD.t.sol";
import { RetentionTest } from "test/integration/Retention.t.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract CodexEmissionsSchedulePoC is EmissionsControllerTest {
    function test_PoC_replacementScheduleRetainsOldRateAndClock() public {
        vm.prank(address(core));
        emissionsController.registerReceiver(address(mockReceiver1));

        skipToFirstEmissionsEpoch();
        vm.prank(address(mockReceiver1));
        emissionsController.fetchEmissions();

        uint256 oldRate = emissionsController.emissionsRate();
        uint256 oldUpdate = emissionsController.lastEmissionsUpdate();
        uint256[] memory replacement = new uint256[](2);
        replacement[0] = 100;
        replacement[1] = 200;

        vm.prank(address(core));
        emissionsController.setEmissionsSchedule(replacement, 10, 50);

        assertEq(emissionsController.emissionsRate(), oldRate, "old active rate survives replacement");
        assertEq(emissionsController.lastEmissionsUpdate(), oldUpdate, "old schedule clock survives replacement");

        skip(epochLength);
        vm.prank(address(mockReceiver1));
        emissionsController.fetchEmissions();
        assertEq(emissionsController.emissionsRate(), oldRate, "replacement is not active next epoch");
    }
}

contract CodexLiquidationSettlementPoC is LiquidationHandlerTest {
    function test_PoC_availablePartialInsuranceCapacitySettlesNothing() public {
        uint256 debt = 1_000e18;
        uint256 shares = IERC4626(address(collateral)).convertToShares(debt);
        deal(address(collateral), address(liquidationHandler), shares);

        uint256 poolAssets = insurancePool.totalAssets();
        vm.prank(address(core));
        insurancePool.setMinimumHeldAssets(poolAssets - 500e18);
        assertEq(insurancePool.maxBurnableAssets(), 500e18);

        vm.prank(address(pair));
        liquidationHandler.processLiquidationDebt(address(collateral), shares, debt);

        assertEq(liquidationHandler.debtByCollateral(address(collateral)), debt, "debt did not decrease");
        assertGt(collateral.balanceOf(address(liquidationHandler)), 0, "collateral was not redeemed");
        assertEq(insurancePool.maxBurnableAssets(), 500e18, "available capacity was unused");
    }
}

contract CodexSreUSDCheckpointPoC is SreUSDTest {
    function test_PoC_checkpointFrequencyChangesDistributionCap() public {
        uint256 principal = 100_000_000e18;
        uint256 capRate = uint256(2e17) / 365 days;

        deposit(address(this), principal);
        vm.prank(address(core));
        vault.setMaxDistributionPerSecondPerAsset(capRate);

        advanceEpochs(checkIfOnEpochEdge() ? 2 : 1);
        skip(1);
        airdropAsset(address(vault), 10_000_000e18);
        vault.syncRewardsAndDistribution();

        uint256 startingAssets = vault.storedTotalAssets();
        uint256 snapshotId = vm.snapshotState();

        for (uint256 i = 0; i < 6; i++) {
            skip(1 days);
            vault.syncRewardsAndDistribution();
        }
        uint256 frequentDistribution = vault.storedTotalAssets() - startingAssets;

        assertTrue(vm.revertToState(snapshotId));
        skip(6 days);
        vault.syncRewardsAndDistribution();
        uint256 singleDistribution = vault.storedTotalAssets() - startingAssets;

        assertGt(frequentDistribution, singleDistribution, "cap must be path independent");
    }
}

contract CodexRetentionAccrualPoC is RetentionTest {
    function test_PoC_exitedAccountKeepsAccruingUntilCheckpoint() public {
        address account;
        uint256 shares;
        for (uint256 i = 0; i < retentionUsers.length; i++) {
            uint256 candidateShares = insurancePool.balanceOf(retentionUsers[i]);
            if (candidateShares != 0 && retention.balanceOf(retentionUsers[i]) != 0) {
                account = retentionUsers[i];
                shares = candidateShares;
                break;
            }
        }
        assertGt(shares, 0, "snapshot account has no insurance shares");

        retention.user_checkpoint(account);

        vm.startPrank(account);
        insurancePool.exit();
        skip(insurancePool.withdrawTime() + 1);
        insurancePool.redeem(shares, account, account);
        vm.stopPrank();
        assertEq(insurancePool.balanceOf(account), 0);

        uint256 rewardAmount = 1_000_000e18;
        deal(address(govToken), address(core), rewardAmount);
        vm.startPrank(address(core));
        govToken.approve(address(retention), rewardAmount);
        retention.queueNewRewards(rewardAmount);
        vm.stopPrank();

        uint256 earnedAtExit = retention.earned(account);
        skip(1 days);
        uint256 earnedAfterExit = retention.earned(account);
        assertGt(earnedAfterExit, earnedAtExit, "exited account still earns at stale weight");
    }
}
