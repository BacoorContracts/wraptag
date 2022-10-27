// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "oz-custom/contracts/oz/token/ERC721/ERC721.sol";

contract ERC721Test is ERC721 {
    constructor() ERC721("NFT", "NFT") {}

    function mintBatch(address to, uint256[] calldata tokenIds) external {
        for (uint256 i; i < tokenIds.length; ++i) {
            _mint(to, tokenIds[i]);
        }
    }

    function _baseURI()
        internal
        view
        virtual
        override
        returns (string memory)
    {}

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {}
}
