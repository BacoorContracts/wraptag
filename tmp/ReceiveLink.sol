// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// import "oz-custom/contracts/oz-upgradeable/utils/structs/BitMapsUpgradeable.sol";
// import "oz-custom/contracts/oz-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";
// import {
//     IERC721Upgradeable,
//     ERC721TokenReceiverUpgradeable
// } from "oz-custom/contracts/oz-upgradeable/token/ERC721/ERC721Upgradeable.sol";

// import "oz-custom/contracts/internal-upgradeable/SignableUpgradeable.sol";
// import "oz-custom/contracts/internal-upgradeable/TransferableUpgradeable.sol";
// import "oz-custom/contracts/internal-upgradeable/ProxyCheckerUpgradeable.sol";
// import "oz-custom/contracts/internal-upgradeable/FundForwarderUpgradeable.sol";

// import "./internal-upgradeable/BaseUpgradeable.sol";

// import "./interfaces/IReceiveLink.sol";
// import "./utils/interfaces/IERC721PermitAll.sol";
// import "oz-custom/contracts/oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";
// import "oz-custom/contracts/oz-upgradeable/token/ERC721/IERC721Upgradeable.sol";
// import "oz-custom/contracts/oz-upgradeable/token/ERC721/extensions/IERC721PermitUpgradeable.sol";
// import "oz-custom/contracts/oz-upgradeable/token/ERC20/extensions/draft-IERC20PermitUpgradeable.sol";

// import "oz-custom/contracts/libraries/SSTORE2.sol";
// import "oz-custom/contracts/libraries/FixedPointMathLib.sol";

// contract VoucherUpgradeable is
//     IReceiveLink,
//     BaseUpgradeable,
//     SignableUpgradeable,
//     TransferableUpgradeable,
//     ProxyCheckerUpgradeable,
//     FundForwarderUpgradeable,
//     ERC721TokenReceiverUpgradeable
// {
//     using SSTORE2 for bytes;
//     using SSTORE2 for bytes32;
//     using FixedPointMathLib for uint256;
//     using ERC165CheckerUpgradeable for address;
//     using BitMapsUpgradeable for BitMapsUpgradeable.BitMap;

//     bytes32 public constant VERSION =
//         0x310ed6d16676d4c9359ae2543f048a44e4901f7cc9b005de459701fce327c823;
//     bytes32 private constant __PERMIT_TYPE_HASH = 0x00;

//     /// voucherId => Voucher
//     mapping(bytes32 => bytes32) private vouchers;

//     /// @custom:oz-upgrades-unsafe-allow constructor
//     constructor() payable {
//         _disableInitializers();
//     }

//     function initialize(IAuthority authority_, ITreasury treasury_)
//         external
//         initializer
//     {
//         __Signable_init("ReceiveLink", "2");
//         __FundForwarder_init(address(treasury_));
//         __Base_init(authority_, Roles.TREASURER_ROLE);
//     }

//     function onERC721Received(
//         address token_,
//         address from_,
//         uint256 tokenId_,
//         bytes calldata data_
//     ) external override returns (bytes4) {
//         emit Received(token_, from_, tokenId_, data_);
//         return this.onERC721Received.selector;
//     }

//     function createPermitVoucher(
//         address token_,
//         uint256 value_,
//         uint256[] calldata tokenIds_,
//         uint256 deadline_,
//         uint8 v,
//         bytes32 r,
//         bytes32 s
//     ) external payable whenNotPaused {
//         address user = _msgSender();
//         __checkUser(user);
//         if (!ITreasury(vault).supportedPayment(token_))
//             revert ReceiveLink__UnsupportedToken();

//         if (token_ != address(0)) {
//             __checkDeadline(deadline_);
//             if (token_.supportsInterface(type(IERC20Upgradeable).interfaceId)) {
//                 IERC20PermitUpgradeable(token_).permit(
//                     user,
//                     address(this),
//                     value_,
//                     deadline_,
//                     v,
//                     r,
//                     s
//                 );

//                 _safeERC20TransferFrom(
//                     IERC20Upgradeable(token_),
//                     user,
//                     address(this),
//                     value_
//                 );
//             } else if (
//                 token_.supportsInterface(type(IERC721Upgradeable).interfaceId)
//             ) {
//                 IERC721PermitAll(token_).permit(
//                     user,
//                     address(this),
//                     deadline_,
//                     v,
//                     r,
//                     s
//                 );

//                 uint256 length = tokenIds_.length;
//                 for (uint256 i; i < length; ) {
//                     IERC721Upgradeable(token_).transferFrom(
//                         user,
//                         address(this),
//                         tokenIds_[i]
//                     );
//                     unchecked {
//                         ++i;
//                     }
//                 }
//             }
//         }

//         emit
//     }

//     function redeem(
//         address token_,
//         uint256 value_,
//         uint256 deadline_,
//         bytes calldata signature_
//     ) external whenNotPaused {
//         address user = _msgSender();
//         __checkUser(user);

//         __checkDeadline(deadline_);
//         if (
//             !_hasRole(
//                 Roles.SIGNER_ROLE,
//                 _recoverSigner(
//                     keccak256(
//                         abi.encode(
//                             __PERMIT_TYPE_HASH,
//                             user,
//                             token_,
//                             value_,
//                             /// @dev nonce incremented to 1, resistance to reentrancy attacks
//                             _useNonce(user),
//                             deadline_
//                         )
//                     ),
//                     signature_
//                 )
//             )
//         ) revert ReceiveLink__InvalidSignature();

//         if (token_.supportsInterface(type(IERC721Upgradeable).interfaceId)) {
//             IERC721Upgradeable(token_).safeTransferFrom(
//                 address(this),
//                 user,
//                 value_
//             );
//         } else _safeTransfer(IERC20Upgradeable(token_), user, value_);

//         emit Redeemed(user);
//     }

//     function __voucherIdOf() private pure returns (bytes32) {}

//     function __checkUser(address user_) private view {
//         _checkBlacklist(user_);
//         _onlyEOA(user_);
//     }

//     function __checkDeadline(uint256 deadline_) private view {
//         if (block.timestamp > deadline_) revert ReceiveLink__Expired();
//     }
// }
