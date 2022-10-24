// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "oz-custom/contracts/oz/token/ERC721/extensions/ERC721Permit.sol";

import "./interfaces/IERC721PermitAll.sol";

abstract contract ERC721PermitAll is ERC721Permit, IERC721PermitAll {
    using Bytes32Address for address;
    using BitMaps for BitMaps.BitMap;

    /// @dev value is equal to keccak256("Permit(address owner,address spender,uint256 nonce,uint256 deadline)")
    bytes32 private constant __PERMIT_TYPE_HASH =
        0xdaab21af31ece73a508939fedd476a5ee5129a5ed4bb091f3236ffb45394df62;

    function permit(
        address owner_,
        address spender_,
        uint256 deadline_,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        if (block.timestamp > deadline_) revert ERC721Permit__Expired();
        if (owner_ == spender_) revert ERC721Permit__SelfApproving();
        _verify(
            owner_,
            keccak256(
                abi.encode(
                    __PERMIT_TYPE_HASH,
                    owner_,
                    spender_,
                    _useNonce(owner_),
                    deadline_
                )
            ),
            v,
            r,
            s
        );

        _isApprovedForAll[owner_.fillLast12Bytes()].set(
            spender_.fillLast96Bits()
        );
    }
}
