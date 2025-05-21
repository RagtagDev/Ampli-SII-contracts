// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Currency} from "v4-core/types/Currency.sol";

struct CurrencyData {
    Currency currency;
    uint256 amount;
}

using CurrencyDataLibrary for CurrencyData global;

library CurrencyDataLibrary {
    error ETHTransferFailed();

    /// @dev Sends `amount` of ERC20 `token` from `from` to `to`.
    /// Reverts upon failure.
    function safeTransferFrom(CurrencyData memory self, address from, address to) internal {
        /// altered from https://github.com/Vectorized/solady/blob/main/src/utils/SafeTransferLib.sol#L204

        address token = Currency.unwrap(self.currency);
        uint256 amount = self.amount;

        assembly ("memory-safe") {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, amount) // Store the `amount` argument.
            mstore(0x40, to) // Store the `to` argument.
            mstore(0x2c, shl(96, from)) // Store the `from` argument.
            mstore(0x0c, 0x23b872dd000000000000000000000000) // `transferFrom(address,address,uint256)`.
            let success := call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x20)
            if iszero(and(eq(mload(0x00), 1), success)) {
                if iszero(lt(or(iszero(extcodesize(token)), returndatasize()), success)) {
                    mstore(0x00, 0x7939f424) // `TransferFromFailed()`.
                    revert(0x1c, 0x04)
                }
            }
            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    function transferIn(CurrencyData[] memory self, address from) internal {
        uint256 sumETHAmount = 0;
        for (uint256 i = 0; i < self.length; i++) {
            CurrencyData memory data = self[i];

            if (data.currency.isAddressZero()) {
                sumETHAmount += data.amount;
            } else {
                data.safeTransferFrom(from, address(this));
            }
        }

        require(sumETHAmount == msg.value, ETHTransferFailed());
    }

    function transferOut(CurrencyData[] memory self, address to) internal {
        for (uint256 i = 0; i < self.length; i++) {
            CurrencyData memory data = self[i];
            data.currency.transfer(to, data.amount);
        }
    }
}
