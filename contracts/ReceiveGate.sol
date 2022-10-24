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
import "oz-custom/contracts/utils/interfaces/IWNT.sol";
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

    IWNT public immutable wrappedNativeToken;
    BitMaps.BitMap private __isWhitelisted;

    constructor(address vault_, IWNT wrappedNativeToken_, IAuthority authority_)
        payable
        Base(authority_, 0)
        FundForwarder(vault_)
    {
        wrappedNativeToken = wrappedNativeToken_;
    }

    function kill() external onlyRole(Roles.FACTORY_ROLE) {
        selfdestruct(payable(vault));
    }

    function whitelistAddress(address addr_) external {
        __isWhitelisted.set(addr_.fillLast96Bits());
    }

    function depositNativeTokenWithCommand() external payable whenNotPaused {
        IWNT wnt = wrappedNativeToken;
        emit Received(address(wnt), _msgSender(), msg.value);
        wnt.deposit{value: msg.value}();
        (address target, bytes memory data) = __decodeData(msg.data);
        __executeTx(target, data);
    }

    function depositERC20WithCommand(
        IERC20Permit token_,
        uint256 value_,
        uint256 deadline_,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bytes calldata data_
    ) external whenNotPaused {
        address user = _msgSender();
        if (block.timestamp > deadline_) revert ReceiveGate__Expired();
        token_.permit(user, address(this), value_, deadline_, v, r, s);
        _safeERC20TransferFrom(
            IERC20(address(token_)),
            user,
            address(this),
            value_
        );
        (address target, bytes memory data) = __decodeData(data_);
        __executeTx(target, data);
    }

    function withdrawTo(address token_, address to_, uint256 value_) external {
        if (token_.supportsInterface(type(IERC20).interfaceId)) {
            IWNT wnt = wrappedNativeToken;
            if (token_ == address(wnt)) {
                wnt.withdraw(value_);
                _safeNativeTransfer(to_, value_);
            } else _safeERC20Transfer(IERC20(token_), to_, value_);
        } else if (token_.supportsInterface(type(IERC721).interfaceId))
            IERC721(token_).safeTransferFrom(address(this), to_, value_);
    }

    function onERC721Received(
        address token_,
        address from_,
        uint256 tokenId_,
        bytes calldata data_
    ) external override returns (bytes4) {
        emit Received(token_, from_, tokenId_);

        (address target, bytes memory data) = __decodeData(data_);
        __executeTx(target, data);

        return this.onERC721Received.selector;
    }

    function __decodeData(bytes calldata data_)
        private
        view
        returns (address target, bytes memory callData)
    {
        (target, callData) = abi.decode(data_, (address, bytes));

        if (!__isWhitelisted.get(target.fillLast96Bits()))
            revert ReceiveGate__UnknownAddress(target);
    }

    function __executeTx(address target_, bytes memory data_) private {
        (bool ok, ) = target_.call(data_);
        if (!ok) revert ReceiveGate__ExecutionFailed();
    }
}
