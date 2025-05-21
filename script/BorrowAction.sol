// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAmpli} from "src/interfaces/IAmpli.sol";
import {Script} from "forge-std/Script.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {BorrowShare, BorrowShareLibrary} from "src/types/BorrowShare.sol";
import {Actions, ActionsRouter} from "test/utils/ActionsRouter.sol";
import {StateLibrary} from "src/libraries/StateLibrary.sol";
import {IERC20} from "src/interfaces/IERC20.sol";
import {TestERC20} from "test/mock/TestERC20.sol";

contract BorrowActionScript is Script {
    using StateLibrary for IAmpli;

    address public deployer;
    IPoolManager public manager = IPoolManager(address(0x498581fF718922c3f8e6A244956aF099B2652b2b));
    IAmpli public ampli = IAmpli(address(0x00D6aFb06576DEA356cBa9F44Ba71aB4eb780Ac0));
    TestERC20 public tokenMock = TestERC20(address(0xb42Cfe81B72A2a3be27BA2f7D3D3eBD4Cc157661));
    address public pegToken = address(0x0b8d08b76eFEF943FE32dCf4d7d0c58C7Fcbb33e);
    ActionsRouter public actionsRouter = ActionsRouter(address(0xEB0c4B14123D190Fe62A7BA34690fc6735901253));
    PoolKey public poolKey;

    function setUp() public {
        deployer = vm.envAddress("WALLET_ADDRESS");

        vm.label(address(actionsRouter), "ActionsRouter");
        vm.label(address(ampli), "Ampli");
        vm.label(address(tokenMock), "TestToken");
        vm.label(pegToken, "PegToken");

        poolKey = PoolKey({
            currency0: Currency.wrap(pegToken),
            currency1: Currency.wrap(address(tokenMock)),
            fee: 100, // 0.01%
            tickSpacing: 1,
            hooks: IHooks(address(ampli))
        });
    }

    function _supplyCollateral(address sender, uint256 positionId, uint256 amount) public {
        Actions[] memory actions = new Actions[](2);
        bytes[] memory params = new bytes[](2);

        actions[0] = Actions.SUPPLY_FUNGIBLE_COLLATERAL;
        params[0] = abi.encode(poolKey, positionId, 0, amount);

        actions[1] = Actions.SETTLE_ALL;
        params[1] = abi.encode(sender, poolKey.currency1);

        actionsRouter.executeActions(actions, params);
    }

    function run() public {
        vm.createSelectFork("HubChain");
        (uint256 totalBorrow, BorrowShare totalShare) = IAmpli(address(ampli)).getPoolBorrow(poolKey.toId());

        BorrowShare borrowed = BorrowShareLibrary.toSharesDown(10 ether, totalBorrow, totalShare);

        vm.startBroadcast(vm.envUint("WALLET_PRIVATE_KEY"));

        ampli.updateAuthorization(poolKey, 2, deployer, address(actionsRouter));

        tokenMock.mint(deployer, 20 ether);
        tokenMock.approve(address(ampli), type(uint256).max);

        // ampli.supplyFungibleCollateral(poolKey, 2, 0, 20 ether);
        _supplyCollateral(deployer, 2, 10 ether);

        Actions[] memory actions = new Actions[](5);
        bytes[] memory params = new bytes[](5);

        actions[0] = Actions.BORROW;
        params[0] = abi.encode(poolKey, 2, borrowed);

        actions[1] = Actions.TAKE_ALL;
        params[1] = abi.encode(address(actionsRouter), address(pegToken));

        actions[2] = Actions.V4_SWAP;
        params[2] = abi.encode(poolKey, -20 ether);

        actions[3] = Actions.SUPPLY_FUNGIBLE_COLLATERAL;
        params[3] = abi.encode(poolKey, 2, 0, 0);

        actions[4] = Actions.SETTLE_ALL;
        params[4] = abi.encode(address(actionsRouter), poolKey.currency1);

        actionsRouter.executeActions(actions, params);

        vm.stopBroadcast();
    }
}
