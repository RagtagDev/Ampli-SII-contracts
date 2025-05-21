// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAmpli} from "src/interfaces/IAmpli.sol";
import {Script} from "forge-std/Script.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Agent} from "src/Agent.sol";
import {TestERC20} from "test/mock/TestERC20.sol";
import {Actions, HubExecutor} from "test/mock/HubExecutor.sol";
import {CurrencyData, CurrencyDataLibrary} from "src/types/CurrencyData.sol";

contract AgentSupplyScript is Script {
    address public owner = vm.envAddress("WALLET_ADDRESS");
    address public authorizedOperator = address(0x934F58ADbda47765F81727894803D497fb7d68F3);
    address public pegToken = address(0x9E357a7ee75914452f06DdFb9622f924276024a3);
    TestERC20 public tokenMock = TestERC20(address(0xb42Cfe81B72A2a3be27BA2f7D3D3eBD4Cc157661));

    IAmpli public ampli = IAmpli(address(0x00D6aFb06576DEA356cBa9F44Ba71aB4eb780Ac0));
    Agent public agent = Agent(address(0x31842da3bc6eB9fe0Ba9F2b332B7965d75309041));

    PoolKey public poolKey;

    function setUp() public {
        poolKey = PoolKey({
            currency0: Currency.wrap(pegToken),
            currency1: Currency.wrap(address(tokenMock)),
            fee: 100, // 0.01%
            tickSpacing: 1,
            hooks: IHooks(address(ampli))
        });
    }

    function _supplyCollateralCalldata(uint256 positionId, uint256 amount) internal view returns (bytes memory data) {
        Actions[] memory actions = new Actions[](1);
        bytes[] memory params = new bytes[](1);

        actions[0] = Actions.SUPPLY_FUNGIBLE_COLLATERAL;
        params[0] = abi.encode(poolKey, positionId, 0, amount);

        // actionsRouter.executeActions(actions, params);
        data = abi.encodeCall(HubExecutor.executeActions, abi.encode(actions, params));
    }

    function run() public {
        vm.createSelectFork("HubChain");
        vm.startBroadcast(vm.envUint("WALLET_PRIVATE_KEY"));
        ampli.updateAuthorization(poolKey, 3, owner, authorizedOperator);
        vm.stopBroadcast();

        vm.createSelectFork("SpokeChain");
        vm.startBroadcast(vm.envUint("WALLET_PRIVATE_KEY"));
        // tokenMock.mint(owner, 10 ether);
        // tokenMock.approve(address(agent), type(uint256).max);

        bytes memory executionData = _supplyCollateralCalldata(3, 10 ether);

        CurrencyData[] memory debitBundle = new CurrencyData[](1);

        debitBundle[0] = CurrencyData({currency: poolKey.currency1, amount: 10 ether});

        agent.initiate(address(authorizedOperator), executionData, debitBundle);

        vm.stopBroadcast();
        // uint256 supply = ampli.supplyFungibleCollateral(poolKey, 2, 0, 20 ether);
        // vm.stopBroadcast();
        // return supply;
    }
}
