// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ReceiveGate} from "./ReceiveGate.sol";

import "./internal-upgradeable/BaseUpgradeable.sol";

import "oz-custom/contracts/internal-upgradeable/ProxylessUpgrader.sol";
import "oz-custom/contracts/internal-upgradeable/FundForwarderUpgradeable.sol";

import "./interfaces/ITreasury.sol";
import "./interfaces/IReceiveGateFactory.sol";

error ReceiveGateFactory__AlreadyDeployed();

contract ReceiveGateFactory is
    BaseUpgradeable,
    ProxylessUpgrader,
    IReceiveGateFactory,
    FundForwarderUpgradeable
{
    /// @dev value is equal to keccak256("ReceiveGateFactory_v1")
    bytes32 public constant VERSION =
        0x0df851f8f5e94c771ff6567b1f5f65fcd056fec283cd3baf65f24b213cdbaca6;

    bytes32 public salt;

    constructor() payable {
        _disableInitializers();
    }

    function initialize(IAuthority authority_, ITreasury treasury_)
        external
        initializer
    {
        __FundForwarder_init(address(treasury_));
        __Base_init(authority_, Roles.FACTORY_ROLE);
    }

    function updateSalt(bytes32 salt_) external onlyRole(Roles.OPERATOR_ROLE) {
        __updateSalt(salt_);
    }

    function __updateSalt(bytes32 salt_) private {
        salt = salt_;
    }

    function deploy(
        IReceiveGate receiveGate_,
        address[] calldata tokens_,
        bool[] calldata statuses_
    ) external onlyRole(Roles.OPERATOR_ROLE) {
        address _authority = address(authority());
        address treasury = vault;

        bytes32 _salt = keccak256(
            abi.encodePacked(_authority, treasury, address(this), VERSION)
        );

        _deploy(
            0,
            _salt,
            abi.encodePacked(
                type(ReceiveGate).creationCode,
                abi.encode(
                    receiveGate_,
                    _authority,
                    treasury,
                    tokens_,
                    statuses_
                )
            )
        );

        __updateSalt(_salt);

        emit InstanceDeployed(address(instance), _salt);
    }

    function destroy() external onlyRole(Roles.OPERATOR_ROLE) {
        instance.kill();

        emit InstanceDestroyed();
    }

    function reinit(
        IReceiveGate receiveGate_,
        address[] calldata tokens_,
        bool[] calldata statuses_
    ) external onlyRole(Roles.OPERATOR_ROLE) {
        address _instance = address(instance);
        if (_instance != address(0) && _instance.code.length != 0)
            revert ReceiveGateFactory__AlreadyDeployed();

        address _authority = address(authority());
        address treasury = vault;

        _deploy(
            0,
            salt,
            abi.encodePacked(
                type(ReceiveGate).creationCode,
                abi.encode(
                    receiveGate_,
                    _authority,
                    treasury,
                    tokens_,
                    statuses_
                )
            )
        );

        emit InstanceReinited();
    }
}
