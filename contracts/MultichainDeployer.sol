// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    Create2Deployer
} from "oz-custom/contracts/internal/DeterministicDeployer.sol";

import "./interfaces/IMultichainDeployer.sol";

contract MultichainDeployer is Create2Deployer, IMultichainDeployer {
    function deploy(uint256 amount_, bytes32 salt_, bytes calldata bytecode_)
        external
    {
        _deploy(amount_, salt_, bytecode_);
    }
}
