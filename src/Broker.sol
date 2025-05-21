// SPDX-License-Identifier: MIT
pragma solidity =0.8.29;

import {IL2ToL2CrossDomainMessenger} from "./interfaces/external/IL2ToL2CrossDomainMessenger.sol";
import {IAgent} from "./interfaces/IAgent.sol";
import {IBroker} from "./interfaces/IBroker.sol";
import {IAmpli} from "./interfaces/IAmpli.sol";
import {IUnlockCallback} from "src/interfaces/callback/IUnlockCallback.sol";
import {Predeploys} from "./libraries/external/Predeploys.sol";
import {CurrencyData} from "./types/CurrencyData.sol";

contract Broker is IBroker, IUnlockCallback {
    IAgent internal immutable agent;
    IAmpli internal immutable ampli;
    IL2ToL2CrossDomainMessenger internal immutable messenger =
        IL2ToL2CrossDomainMessenger(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER);

    constructor(address _agent, address _ampli) {
        agent = IAgent(_agent);
        ampli = IAmpli(_ampli);
    }

    function handleMessage(
        address user,
        address executor,
        bytes calldata executionData,
        CurrencyData[] calldata debitBundle,
        bytes calldata onSuccessCallback,
        bytes calldata onFailureCallback
    ) external {
        (address sourceSender, uint256 sourceChainId) = messenger.crossDomainMessageContext();
        require(msg.sender == address(messenger), NotMessenger());
        require(sourceSender == address(agent), NotAgent());

        try Broker(this).selfHandleMessage(sourceChainId, user, executor, executionData, debitBundle) {
            if (onSuccessCallback.length > 0) messenger.sendMessage(sourceChainId, sourceSender, onSuccessCallback);
        } catch {
            if (onFailureCallback.length > 0) messenger.sendMessage(sourceChainId, sourceSender, onFailureCallback);
        }
    }

    function selfHandleMessage(
        uint256 sourceChainId,
        address user,
        address executor,
        bytes calldata executionData,
        CurrencyData[] calldata debitBundle
    ) external {
        require(msg.sender == address(this), NotSelf());

        for (uint256 i = 0; i < debitBundle.length; i++) {
            ampli.debit(debitBundle[i].currency, debitBundle[i].amount, user);
        }

        ampli.unlock(abi.encode(executor, executionData));

        // messenger.sendMessage(
        //     recipientChainId, address(agent), abi.encodeCall(IAgent.release, (recipient, creditBundle))
        // );
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory result) {
        (address executor, bytes memory executionData) = abi.decode(data, (address, bytes));

        bool success;
        (success, result) = executor.call(executionData);
        require(success);
    }
}
