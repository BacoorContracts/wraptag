// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./IReceiveGate.sol";

interface IReceiveGateFactory {
    event InstanceDeployed(address indexed instance, bytes32 indexed salt);
    event InstanceReinited();
    event InstanceDestroyed();

    function updateSalt(bytes32 salt_) external;

    function deploy(
        IReceiveGate receiveGate_,
        address[] calldata tokens_,
        bool[] calldata statuses_
    ) external;

    function destroy() external;

    function reinit(
        IReceiveGate receiveGate_,
        address[] calldata tokens_,
        bool[] calldata statuses_
    ) external;
}
