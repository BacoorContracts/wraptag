// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    ERC721TokenReceiver
} from "oz-custom/contracts/oz/token/ERC721/ERC721.sol";
import "oz-custom/contracts/oz/utils/structs/BitMaps.sol";
import "oz-custom/contracts/oz/utils/introspection/ERC165Checker.sol";

import "oz-custom/contracts/internal/FundForwarder.sol";
import "oz-custom/contracts/internal/MultiDelegatecall.sol";

import "./internal/Base.sol";

import "./interfaces/IReceiveGate.sol";
import "oz-custom/contracts/oz/token/ERC721/IERC721.sol";

import "oz-custom/contracts/libraries/Bytes32Address.sol";

contract ReceiveGate is
    Base,
    IKillable,
    IReceiveGate,
    FundForwarder,
    MultiDelegatecall,
    ERC721TokenReceiver
{
    using Bytes32Address for address;
    using ERC165Checker for address;
    using BitMaps for BitMaps.BitMap;

    BitMaps.BitMap private __isWhitelisted;

    constructor(address vault_, IAuthority authority_)
        payable
        Base(authority_, 0)
        FundForwarder(vault_)
    {}

    function kill() external onlyRole(Roles.FACTORY_ROLE) {
        selfdestruct(payable(vault));
    }

    function whitelistAddress(address addr_)
        external
        onlyRole(Roles.OPERATOR_ROLE)
    {
        __isWhitelisted.set(addr_.fillLast96Bits());
    }

    function depositNativeTokenWithCommand(
        address contract_,
        bytes4 fnSig_,
        bytes calldata params_
    ) external payable whenNotPaused {
        if (!__isWhitelisted.get(contract_.fillLast96Bits()))
            revert ReceiveGate__UnknownAddress(contract_);

        __executeTx(
            contract_,
            fnSig_,
            bytes.concat(params_, abi.encode(address(0), msg.value))
        );
    }

    function depositERC20WithCommand(
        IERC20Permit token_,
        uint256 value_,
        uint256 deadline_,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bytes4 fnSig_,
        address contract_,
        bytes calldata data_
    ) external whenNotPaused {
        address user = _msgSender();
        if (block.timestamp > deadline_) revert ReceiveGate__Expired();
        if (!__isWhitelisted.get(contract_.fillLast96Bits()))
            revert ReceiveGate__UnknownAddress(contract_);
        token_.permit(user, address(this), value_, deadline_, v, r, s);
        _safeERC20TransferFrom(
            IERC20(address(token_)),
            user,
            address(this),
            value_
        );

        __executeTx(
            contract_,
            fnSig_,
            bytes.concat(data_, abi.encode(token_, value_))
        );
    }

    function withdrawTo(address token_, address to_, uint256 value_) external {
        if (token_.supportsInterface(type(IERC20).interfaceId))
            _safeERC20Transfer(IERC20(token_), to_, value_);
        else if (token_.supportsInterface(type(IERC721).interfaceId))
            IERC721(token_).safeTransferFrom(address(this), to_, value_);
        else if (token_ == address(0)) _safeNativeTransfer(to_, value_);
    }

    function onERC721Received(address, address, uint256, bytes calldata data_)
        external
        override
        returns (bytes4)
    {
        (address target, bytes4 fnSig, bytes memory data) = __decodeData(data_);

        if (!__isWhitelisted.get(target.fillLast96Bits()))
            revert ReceiveGate__UnknownAddress(target);

        __executeTx(
            target,
            fnSig,
            bytes.concat(data, abi.encode(_msgSender(), 0))
        );

        return this.onERC721Received.selector;
    }

    function depositERC721MultiWithCommand(
        uint256[] calldata tokenIds_,
        address[] calldata contracts_,
        bytes[] calldata data_
    ) external whenNotPaused {
        uint256 length = tokenIds_.length;
        address sender = _msgSender();
        for (uint256 i; i < length; ) {
            IERC721(contracts_[i]).safeTransferFrom(
                sender,
                address(this),
                tokenIds_[i],
                data_[i]
            );
            unchecked {
                ++i;
            }
        }
    }

    function __decodeData(bytes calldata data_)
        private
        view
        returns (address target, bytes4 fnSig, bytes memory params)
    {
        (target, fnSig, params) = abi.decode(data_, (address, bytes4, bytes));

        if (!__isWhitelisted.get(target.fillLast96Bits()))
            revert ReceiveGate__UnknownAddress(target);
    }

    function __executeTx(
        address target_,
        bytes4 fnSignature_,
        bytes memory params_
    ) private {
        (bool ok, ) = target_.call(abi.encodePacked(fnSignature_, params_));
        if (!ok) revert ReceiveGate__ExecutionFailed();
    }
}
