// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IERC721PermitAll {
    function permit(
        address owner_,
        address spender_,
        uint256 deadline_,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}
