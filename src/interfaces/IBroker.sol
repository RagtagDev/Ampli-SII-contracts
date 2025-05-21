// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CurrencyData} from "../types/CurrencyData.sol";

interface IBroker {
    error NotMessenger();
    error NotAgent();
    error NotSelf();

    function handleMessage(
        address user,
        address executor,
        bytes calldata executionData,
        CurrencyData[] calldata debitBundle,
        bytes calldata onSuccessCallback,
        bytes calldata onFailureCallback
    ) external;
}
