// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {IAmpli} from "src/interfaces/IAmpli.sol";
import {V4MiniRouter} from "test/utils/V4MiniRouter.sol";
import {V4RouterHelper} from "test/utils/V4RouterHelper.sol";
import {ActionsRouter} from "test/utils/ActionsRouter.sol";
import {HubExecutor} from "test/mock/HubExecutor.sol";
import {TestERC20} from "test/mock/TestERC20.sol";
import {OracleMock} from "test/mock/OracleMock.sol";
import {IrmMock} from "test/mock/IrmMock.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IERC20} from "src/interfaces/IERC20.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {BorrowShare, BorrowShareLibrary} from "src/types/BorrowShare.sol";
import {Actions} from "test/utils/ActionsRouter.sol";
import {V4Actions} from "test/utils/V4MiniRouter.sol";
import {console} from "forge-std/console.sol";

contract RouterDeployScript is Script {
    IPoolManager public manager = IPoolManager(address(0x498581fF718922c3f8e6A244956aF099B2652b2b));
    IAmpli public ampli = IAmpli(address(0x00D6aFb06576DEA356cBa9F44Ba71aB4eb780Ac0));
    bytes32 public salt = hex"00";

    V4MiniRouter public v4MiniRouter;
    V4RouterHelper public v4RouterHelper;
    ActionsRouter public actionsRouter;
    HubExecutor public hubExecutor;
    TestERC20 public tokenMock;
    IERC20 public pegToken;
    IrmMock public irm;
    OracleMock public oracle;
    PoolKey public poolKey;
    address public deployer;

    function _supplyCollateral(address sender, uint256 positionId, uint256 amount) public {
        Actions[] memory actions = new Actions[](2);
        bytes[] memory params = new bytes[](2);

        actions[0] = Actions.SUPPLY_FUNGIBLE_COLLATERAL;
        params[0] = abi.encode(poolKey, positionId, 0, amount);

        actions[1] = Actions.SETTLE_ALL;
        params[1] = abi.encode(sender, poolKey.currency1);

        actionsRouter.executeActions(actions, params);
    }

    function _borrowPegToken(address receiver, uint256 amount) public {
        BorrowShare borrowed = BorrowShareLibrary.toSharesDown(amount, 0, BorrowShare.wrap(0));

        Actions[] memory actions = new Actions[](2);
        bytes[] memory params = new bytes[](2);

        actions[0] = Actions.BORROW;
        params[0] = abi.encode(poolKey, 1, borrowed);

        actions[1] = Actions.TAKE_ALL;
        params[1] = abi.encode(receiver, address(pegToken));

        actionsRouter.executeActions(actions, params);
    }

    function run() public {
        deployer = vm.envAddress("WALLET_ADDRESS");
        vm.createSelectFork("HubChain");
        vm.startBroadcast(vm.envUint("WALLET_PRIVATE_KEY"));

        v4MiniRouter = new V4MiniRouter{salt: salt}(address(manager));
        console.log("v4MiniRouter: ", address(v4MiniRouter));
        v4RouterHelper = new V4RouterHelper{salt: salt}(v4MiniRouter);
        console.log("v4RouterHelper: ", address(v4RouterHelper));
        actionsRouter = new ActionsRouter{salt: salt}(ampli, v4RouterHelper);
        console.log("actionsRouter: ", address(actionsRouter));
        hubExecutor = new HubExecutor{salt: salt}(ampli, v4RouterHelper);
        console.log("hubExecutor: ", address(hubExecutor));

        tokenMock = new TestERC20{salt: hex"0ff0"}("Test Token", "TST", 18);
        console.log("tokenMock: ", address(tokenMock));
        irm = new IrmMock();
        console.log("irm: ", address(irm));
        oracle = new OracleMock();
        console.log("oracle: ", address(oracle));

        irm.setBorrowRate(0.01 * 1e27);
        // assetId = 0, mock token price / peg token = 1
        oracle.setFungibleAssetPrice(0, 1e36);
        oracle.setFungibleAssetPrice(1, 1e36);

        address pegTokenAddr = ampli.initialize(address(tokenMock), deployer, irm, oracle, 2, 1, hex"ff");
        console.log("pegToken: ", pegTokenAddr);

        actionsRouter.approve(address(tokenMock));
        tokenMock.approve(address(ampli), type(uint256).max);
        tokenMock.approve(address(actionsRouter), type(uint256).max);
        tokenMock.approve(address(v4MiniRouter), type(uint256).max);

        pegToken = IERC20(pegTokenAddr);

        poolKey = PoolKey({
            currency0: Currency.wrap(address(pegToken)),
            currency1: Currency.wrap(address(tokenMock)),
            fee: 100, // 0.01%
            tickSpacing: 1,
            hooks: IHooks(address(ampli))
        });

        ampli.updateAuthorization(poolKey, 1, address(deployer), address(actionsRouter));

        tokenMock.mint(address(deployer), 1500 ether);
        _supplyCollateral(address(deployer), 1, 1000 ether);
        _borrowPegToken(address(deployer), 600 ether);

        actionsRouter.approve(address(pegToken));
        pegToken.approve(address(v4MiniRouter), type(uint256).max);

        v4RouterHelper.addLiquidity(deployer, poolKey);

        vm.stopBroadcast();
    }
}
