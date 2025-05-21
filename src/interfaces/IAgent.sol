// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CurrencyData} from "../types/CurrencyData.sol";

interface IAgent {
    error NotMessenger();
    error NotBroker();
    error NotHubChain();

    function initiate(address executor, bytes calldata executionData, CurrencyData[] calldata debitBundle)
        external
        payable
        returns (uint256 nonce);

    // function release(address recipient, CurrencyData[] calldata creditBundle) external;

    function conclude(uint256 messageNonce) external;

    function rollback(uint256 messageNonce) external;
}
