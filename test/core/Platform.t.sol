// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {Platform} from "../../src/core/Platform.sol";
import "../../src/core/proxy/Proxy.sol";
import "../../src/core/vaults/CVault.sol";
import "../../src/test/MockVaultUpgrade.sol";
import "../../src/core/Factory.sol";
import "../../src/core/StrategyLogic.sol";

contract PlatformTest is Test  {
    Platform public platform;
    StrategyLogic public strategyLogic;

    function setUp() public {
        Proxy proxy = new Proxy();
        proxy.initProxy(address(new Platform()));
        platform = Platform(address(proxy));
    }

    function testSetup() public {
        vm.expectRevert("Zero multisig");
        platform.initialize(address(0), '23.11.0-dev');
        platform.initialize(address(this), '23.11.0-dev');
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        platform.initialize(address(this), '23.11.0-dev');
        assertEq(platform.governance(), address(0));
        assertEq(platform.multisig(), address(this));
        Proxy proxy = new Proxy();
        proxy.initProxy(address(new Platform()));
        Platform platform2 = Platform(address(proxy));
        platform2.initialize(address(this),  '23.11.0-dev');
        platform.setup(
            IPlatform.SetupAddresses({
                factory: address(1),
                priceReader: address(2),
                swapper: address(3),
                buildingPermitToken: address(4),
                buildingPayPerVaultToken: address(5),
                vaultManager: address(6),
                strategyLogic: address(strategyLogic),
                aprOracle: address(8),
                targetExchangeAsset: address(9),
                hardWorker: address(10),
                zap: address(0)
            }),
            IPlatform.PlatformSettings({
                networkName: 'Localhost Ethereum',
                networkExtra: CommonLib.bytesToBytes32(abi.encodePacked(bytes3(0x7746d7), bytes3(0x040206))),
                fee: 6_000,
                feeShareVaultManager: 30_000,
                feeShareStrategyLogic: 30_000,
                feeShareEcosystem: 0,
                minInitialBoostPerDay: 30e18, // $30
                minInitialBoostDuration: 30 * 86400 // 30 days
            })
        );
        vm.expectRevert("Platform: already set");
        platform.setup(
            IPlatform.SetupAddresses({
                factory: address(1),
                priceReader: address(2),
                swapper: address(3),
                buildingPermitToken: address(4),
                buildingPayPerVaultToken: address(5),
                vaultManager: address(6),
                strategyLogic: address(strategyLogic),
                aprOracle: address(8),
                targetExchangeAsset: address(9),
                hardWorker: address(10),
                zap: address(0)
            }),
            IPlatform.PlatformSettings({
                networkName: 'Localhost Ethereum',
                networkExtra: bytes32(0),
                fee: 6_000,
                feeShareVaultManager: 30_000,
                feeShareStrategyLogic: 30_000,
                feeShareEcosystem: 0,
                minInitialBoostPerDay: 30e18, // $30
                minInitialBoostDuration: 30 * 86400 // 30 days
            })
        );
    }

    function testAddRemoveOperator(address operator) public {
        platform.initialize(address(this), '23.11.0-dev');
        if (operator == address(this)) {
            vm.expectRevert("Platform: EXIST");
        } else {
            assertEq(platform.isOperator(operator), false);
        }

        platform.addOperator(operator);
        vm.expectRevert("Platform: EXIST");
        platform.addOperator(operator);
        
        assertEq(platform.isOperator(operator), true);
        address[] memory operatorsList = platform.operatorsList();

        if (operator == address(this)) {
            assertEq(operatorsList.length, 1);
        } else {
            assertEq(operatorsList.length, 2);
        }

        platform.removeOperator(operator);
        assertEq(platform.isOperator(operator), false);
        vm.expectRevert("Platform: NOT_EXIST");
        platform.removeOperator(operator);

        if (operator != address(0) && operator != address(this)) {
            vm.startPrank(operator);
            vm.expectRevert(bytes("Controllable: not governance and not multisig"));
            platform.addOperator(operator);
            vm.stopPrank();
        }
    }

    function testProxyUpgrade(address multisig) public {
        if (multisig != address(0)) {
            platform.initialize(multisig, '23.11.0-dev');

            // its not fabric vault
            CVault vaultImplementation = new CVault();

            MockVaultUpgrade vaultImplementationUpgrade = new MockVaultUpgrade();

            Proxy proxy = new Proxy();
            proxy.initProxy(address(vaultImplementation));
            CVault vault = CVault(payable(address(proxy)));
            vault.initialize(address(platform), address(0), 'V', 'V', 0, new address[](0), new uint[](0));

            address[] memory proxies = new address[](1);
            proxies[0] = address(proxy);
            address[] memory implementations = new address[](1);
            implementations[0] = address(vaultImplementationUpgrade);

            if (multisig != address(this)) {
                vm.expectRevert(bytes("Controllable: not governance and not multisig"));
                platform.announcePlatformUpgrade(
                    '2025.01.0-beta',
                    proxies,
                    implementations
                );
            }

            vm.startPrank(multisig);
            platform.announcePlatformUpgrade(
                '2025.01.0-beta',
                proxies,
                implementations
            );
            
            vm.expectRevert("Platform: ANNOUNCED");
            platform.announcePlatformUpgrade(
                '2025.01.0-beta',
                proxies,
                implementations
            );
 
            vm.stopPrank();
            platform.cancelUpgrade();
            vm.startPrank(multisig);

            address[] memory _implementations = new address[](2);
            _implementations[0] = address(vaultImplementationUpgrade);
            _implementations[1] = address(vaultImplementationUpgrade);

            vm.expectRevert("Platform: WRONG_INPUT");
            platform.announcePlatformUpgrade(
                '2025.01.0-beta',
                proxies,
                _implementations
            );
 
            address[] memory _proxies = new address[](1);
            _proxies[0] = address(0);
            vm.expectRevert("Platform: zero proxy address");
            platform.announcePlatformUpgrade(
                '2025.01.0-beta',
                _proxies,
                implementations
            ); 

            address[] memory __implementations = new address[](1);
            __implementations[0] = address(0);

           vm.expectRevert("Platform: zero implementation address");
            platform.announcePlatformUpgrade(
                '2025.01.0-beta',
                proxies,
                __implementations
            ); 

            _proxies[0] = address(vaultImplementationUpgrade);
            __implementations[0] = address(vaultImplementationUpgrade);
            vm.expectRevert("Platform: same version");
            platform.announcePlatformUpgrade(
                '2025.01.0-beta',
                _proxies,
                __implementations
            );

            string memory oldVersion = platform.PLATFORM_VERSION();
            vm.expectRevert("Platform: same platform version");
            platform.announcePlatformUpgrade(
                oldVersion,
                proxies,
                implementations
            );
          
            platform.announcePlatformUpgrade(
                '2025.01.0-beta',
                proxies,
                implementations
            );
            vm.stopPrank();

            assertEq(platform.pendingPlatformUpgrade().proxies[0], address(proxy));
            assertEq(platform.pendingPlatformUpgrade().newImplementations[0], address(vaultImplementationUpgrade));

            platform.cancelUpgrade();
            assertEq(platform.pendingPlatformUpgrade().proxies.length, 0);
            vm.expectRevert("Platform: no upgrade");
            platform.cancelUpgrade();
            vm.expectRevert("Platform: no upgrade");
            platform.upgrade();

            vm.prank(multisig);
            platform.announcePlatformUpgrade(
                '2025.01.0-beta',
                proxies,
                implementations
            );

            skip(30 minutes);

            vm.expectRevert(bytes("Platform: wait till platformUpgradeTimelock"));
            platform.upgrade();

            skip(30 days);

            platform.upgrade();

            assertEq(proxy.implementation(), address(vaultImplementationUpgrade));
            assertEq(CVault(payable(address(proxy))).VERSION(), "10.99.99");
            assertEq(platform.PLATFORM_VERSION(), '2025.01.0-beta');
        } else {
            vm.expectRevert(bytes("Zero multisig"));
            platform.initialize(multisig, '23.11.0-dev');
        }

    }

    function testSetFees() public {
        platform.initialize(address(this), '23.11.0-dev');
        address govAddr = platform.governance();

        vm.prank(address(1));
        vm.expectRevert("Controllable: not governance");
        platform.setFees(1,1,1,1); 

        vm.startPrank(govAddr);
        platform.setFees(6_000, 30_000, 30_000, 0); 
        (uint fee, uint feeShareVaultManager, uint feeShareStrategyLogic, uint feeShareEcosystem) = platform.getFees();
        assertEq(fee, 6_000);
        assertEq(feeShareVaultManager, 30_000);
        assertEq(feeShareStrategyLogic, 30_000);
        assertEq(feeShareEcosystem, 0);

        vm.expectRevert("Platform: zero ecosystemFeeReceiver");
        platform.setFees(6_000, 30_000, 30_000, 5); 

        vm.expectRevert("Platform: incorrect fee");
        platform.setFees(3_000, 30_000, 30_000, 0); 
        vm.expectRevert("Platform: incorrect fee");
        platform.setFees(13_000, 30_000, 30_000, 0); 

        vm.expectRevert("Platform: incorrect feeShareVaultManager");
        platform.setFees(6_000, 3_000, 30_000, 0); 

        vm.expectRevert("Platform: incorrect feeShareStrategyLogic");
        platform.setFees(6_000, 30_000, 3_000, 0); 

        vm.expectRevert("Platform: incorrect fee shares");
        platform.setFees(10_000, 60_000, 50_000, 0); 

        vm.stopPrank();
    }

    function testAddRemoveUseAllowedBBToken() public {
        platform.initialize(address(this), '23.11.0-dev');
        platform.setAllowedBBTokenVaults(address(1), 5);
        platform.setAllowedBBTokenVaults(address(2), 5);
        platform.setAllowedBBTokenVaults(address(3), 1);

        vm.startPrank(address(platform.factory()));
        platform.useAllowedBBTokenVault(address(3));
        vm.expectRevert("Platform: building for bbToken is not allowed");
        platform.useAllowedBBTokenVault(address(3));
        vm.stopPrank();

        (address[] memory bbToken, ) = platform.allowedBBTokenVaults();
        assertEq(bbToken[0], address(1));
        assertEq(bbToken[1], address(2));
 
        vm.expectRevert("Platform: BB-token not found");
        platform.removeAllowedBBToken(address(5));

        platform.removeAllowedBBToken(bbToken[0]);
        
        (bbToken, ) = platform.allowedBBTokenVaults();
        //EnumerableSet.remove change positions inside array
        assertEq(bbToken[0], address(3));
        assertEq(bbToken[1], address(2));

        platform.removeAllowedBBToken(bbToken[0]);
        (bbToken, ) = platform.allowedBBTokenVaults();
        assertEq(bbToken.length, 1); 
        platform.removeAllowedBBToken(bbToken[0]);
        (bbToken, ) = platform.allowedBBTokenVaults();
        assertEq(bbToken.length, 0); 
    }

    function testAddRemoveAllowedBoostRewardToken() public {
        platform.initialize(address(this), '23.11.0-dev');
        platform.addAllowedBoostRewardToken(address(1));
        platform.addAllowedBoostRewardToken(address(2));

        vm.expectRevert("Platform: EXIST");
        platform.addAllowedBoostRewardToken(address(2));
        vm.expectRevert("Platform: EXIST");
        platform.removeAllowedBoostRewardToken(address(789));

        address[] memory allowedTokens = platform.allowedBoostRewardTokens();
        assertEq(allowedTokens[0], address(1));
        assertEq(allowedTokens[1], address(2));

        platform.removeAllowedBoostRewardToken(address(1));
        allowedTokens = platform.allowedBoostRewardTokens();
        assertEq(allowedTokens[0], address(2));

        platform.removeAllowedBoostRewardToken(address(2));
        allowedTokens = platform.allowedBoostRewardTokens();
        assertEq(allowedTokens.length, 0);
    }

    function testAddRemoveDefaultBoostRewardToken() public {
        platform.initialize(address(this), '23.11.0-dev');
        platform.addDefaultBoostRewardToken(address(1));
        platform.addDefaultBoostRewardToken(address(2));

        vm.expectRevert("Platform: EXIST");
        platform.addDefaultBoostRewardToken(address(2));
        vm.expectRevert("Platform: EXIST");
        platform.removeDefaultBoostRewardToken(address(789));

        address[] memory defaultTokens = platform.defaultBoostRewardTokens();
        assertEq(defaultTokens[0], address(1));
        assertEq(defaultTokens[1], address(2));

        platform.removeDefaultBoostRewardToken(address(1));
        defaultTokens = platform.defaultBoostRewardTokens();
        assertEq(defaultTokens[0], address(2));

        platform.removeDefaultBoostRewardToken(address(2));
        defaultTokens = platform.defaultBoostRewardTokens();
        assertEq(defaultTokens.length, 0);

    }

    function testAddBoostTokens() public {
        address[] memory allowedBoostRewardTokens = new address[](2);
        allowedBoostRewardTokens[0] = address(101);
        allowedBoostRewardTokens[1] = address(105);
        address[] memory defaultBoostRewardTokens = new address[](1);
        defaultBoostRewardTokens[0] = address(208);

        platform.initialize(address(this), '23.11.0-dev');
        platform.addBoostTokens(allowedBoostRewardTokens, defaultBoostRewardTokens);

        address[] memory alreadyAddedAllowedBoostRewardToken = new address[](1);
        alreadyAddedAllowedBoostRewardToken[0] = address(101);
        address[] memory newDefaultBoostRewardTokens = new address[](1);
        newDefaultBoostRewardTokens[0] = address(386);
        vm.expectRevert(
            abi.encodeWithSelector(IPlatform.TokenAlreadyExistsInSet.selector, address(101))
        );
        platform.addBoostTokens(alreadyAddedAllowedBoostRewardToken, newDefaultBoostRewardTokens);

        address[] memory defaultTokens = platform.defaultBoostRewardTokens();
        assertEq(defaultTokens.length, 1);
        assertEq(defaultTokens[0], address(208));

        address[] memory allowedTokens = platform.allowedBoostRewardTokens();
        assertEq(allowedTokens.length, 2);
        assertEq(allowedTokens[0], address(101));
        assertEq(allowedTokens[1], address(105));

    }

    function testGetAmmAdapters() public {
        platform.initialize(address(this), '23.11.0-dev');
        platform.addAmmAdapter("myId", address(1));
        platform.addAmmAdapter("myId2", address(2));
        vm.expectRevert("Platform: AMM adapter already exist");
        platform.addAmmAdapter("myId2", address(2));

        (string[] memory ids, address[] memory proxies) = platform.getAmmAdapters();
        assertEq(ids[0], "myId");
        assertEq(ids[1], "myId2");
        assertEq(proxies[0], address(1));
        assertEq(proxies[1], address(2));

    }

    function testGetData() public {
        platform.initialize(address(this), '23.11.0-dev');
        vm.expectRevert("Platform: need setup");
        {   
            (address[] memory _platformAddresses,,,,,,,) = platform.getData();
            delete _platformAddresses;
        } 

        Proxy proxy = new Proxy();
        proxy.initProxy(address(new StrategyLogic()));
        strategyLogic = StrategyLogic(address(proxy));
        strategyLogic.init(address(platform)); 

        proxy = new Proxy();
        proxy.initProxy(address(new Factory()));
        Factory factory = Factory(address(proxy));
        factory.initialize(address(platform));
        platform.setup(
            IPlatform.SetupAddresses({
                factory: address(factory),
                priceReader: address(2),
                swapper: address(3),
                buildingPermitToken: address(4),
                buildingPayPerVaultToken: address(5),
                vaultManager: address(6),
                strategyLogic: address(strategyLogic),
                aprOracle: address(8),
                targetExchangeAsset: address(9),
                hardWorker: address(10),
                zap: address(0)
            }),
            IPlatform.PlatformSettings({
                networkName: 'Localhost Ethereum',
                networkExtra: CommonLib.bytesToBytes32(abi.encodePacked(bytes3(0x7746d7), bytes3(0x040206))),
                fee: 6_000,
                feeShareVaultManager: 30_000,
                feeShareStrategyLogic: 30_000,
                feeShareEcosystem: 0,
                minInitialBoostPerDay: 30e18, // $30
                minInitialBoostDuration: 30 * 86400 // 30 days
            })
        ); 

        (
            address[] memory platformAddresses,
            string[] memory vaultType,
            bytes32[] memory vaultExtra,
            uint[] memory vaultBuildingPrice,
            string[] memory strategyId,
            bool[] memory isFarmingStrategy,
            string[] memory strategyTokenURI,
            bytes32[] memory strategyExtra
        ) = platform.getData();


        assertEq(platformAddresses[0], platform.factory());
        assertEq(platformAddresses[1], platform.vaultManager());
        assertEq(platformAddresses[2], platform.strategyLogic());
        assertEq(platformAddresses[3], platform.buildingPermitToken());
        assertEq(platformAddresses[4], platform.buildingPayPerVaultToken()); 
        assertEq(vaultType.length, 0); 
        assertEq(vaultExtra.length, 0); 
        assertEq(vaultBuildingPrice.length, 0); 
        assertEq(strategyId.length, 0); 
        assertEq(isFarmingStrategy.length, 0); 
        assertEq(strategyTokenURI.length, 0); 
        assertEq(strategyExtra.length, 0);  


        address _logic = platform.strategyLogic();
        vm.expectRevert("StrategyLogic: not owner");
        IStrategyLogic(_logic).setRevenueReceiver(1, address(1));
        vm.prank(address(0));
        IStrategyLogic(_logic).setRevenueReceiver(1, address(1));
        address _receiver = IStrategyLogic(_logic).getRevenueReceiver(1);
        assertEq(address(1), _receiver);
    }

    function testEcosystemRevenueReceiver() public {
        platform.initialize(address(this), '23.11.0-dev');
        vm.expectRevert("Platform: ZERO_ADDRESS");
        platform.setEcosystemRevenueReceiver(address(0));
        platform.setEcosystemRevenueReceiver(address(1));
    }

    function testDexAggregators() public {
        platform.initialize(address(this), '23.11.0-dev');

        address[] memory dexAggRouter = new address[](2);
        dexAggRouter[0] = address(1);
        dexAggRouter[1] = address(2);
        platform.addDexAggregators(dexAggRouter);

        dexAggRouter[0] = address(8);
        dexAggRouter[1] = address(9);
        platform.addDexAggregators(dexAggRouter);
        
        address[] memory dexAggs = platform.dexAggregators();
        assertEq(dexAggs.length, 4);
        assertEq(dexAggs[3], address(9));

        assertEq(platform.isAllowedDexAggregatorRouter(address(10)), false);
        assertEq(platform.isAllowedDexAggregatorRouter(address(9)), true);

        dexAggRouter = new address[](1);
        dexAggRouter[0] = address(3);
        platform.addDexAggregators(dexAggRouter);

        dexAggRouter[0] = address(0);
        vm.expectRevert(
            abi.encodeWithSelector(IPlatform.ZeroAddress.selector)
        );
        platform.addDexAggregators(dexAggRouter);

        vm.expectRevert(
            abi.encodeWithSelector(IPlatform.AggregatorNotExists.selector, address(5))
        );
        platform.removeDexAggregator(address(5));

        platform.removeDexAggregator(address(1));
        dexAggRouter[0] = address(1);
        platform.addDexAggregators(dexAggRouter);

    }
}
