// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../base/chains/PolygonSetup.sol";
import "../base/UniversalTest.sol";
import "forge-std/console.sol";

contract GammaQuickSwapMerklFarmStrategyTest is PolygonSetup, UniversalTest {
    constructor() {
        vm.rollFork(53133804); // FAIL. Reason: revert: Improper ratio catched at this block with special amounts
    }

    function testGQMFDebugDeposit() public universalTest {
        specialDepositAmounts.push(11838);
        specialDepositAmounts.push(11971);

        _addStrategy(1);
        // _addStrategy(2);
        // _addStrategy(3);
        // _addStrategy(4);
        // _addStrategy(5);
        // _addStrategy(6);
        // _addStrategy(7);
        // _addStrategy(8);
        // _addStrategy(9);
        // _addStrategy(10);
        // _addStrategy(11);
        // _addStrategy(12);
        // _addStrategy(13);
        // _addStrategy(14);
        // _addStrategy(15);
        // _addStrategy(16);
    }

    function _addStrategy(uint farmId) internal {
        strategies.push(
            Strategy({
                id: StrategyIdLib.GAMMA_QUICKSWAP_MERKL_FARM,
                pool: address(0),
                farmId: farmId,
                underlying: address(0)
            })
        );
    }

    function _preHardWork() internal override {
        deal(PolygonLib.TOKEN_dQUICK, currentStrategy, 10e18);
    }
}
