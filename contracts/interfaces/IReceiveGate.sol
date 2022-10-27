// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    IKillable
} from "oz-custom/contracts/internal-upgradeable/ProxylessUpgrader.sol";
import {
    IERC20Permit
} from "oz-custom/contracts/oz/token/ERC20/extensions/draft-IERC20Permit.sol";

interface IReceiveGate is IKillable {
    error ReceiveGate__Expired();
    error ReceiveGate__ExecutionFailed();
    error ReceiveGate__UnknownAddress(address addr);

    event Received(
        address indexed token,
        address indexed from,
        uint256 indexed value
    );

    function whitelistAddress(address addr_) external;

    // function depositNativeTokenWithCommand(bytes calldata data_) external payable;

    // function depositERC20WithCommand(
    //     IERC20Permit token_,
    //     uint256 value_,
    //     uint256 deadline_,
    //     uint8 v,
    //     bytes32 r,
    //     bytes32 s,
    //     bytes calldata data_
    // ) external;

    function withdrawTo(address token_, address to_, uint256 value_) external;
}
