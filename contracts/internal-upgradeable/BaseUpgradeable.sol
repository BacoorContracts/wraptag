// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "oz-custom/contracts/oz-upgradeable/utils/ContextUpgradeable.sol";
import "oz-custom/contracts/oz-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interfaces/IAuthority.sol";

import "../libraries/Roles.sol";

error Base__Paused();
error Base__NotPaused();
error Base__AlreadySet();
error Base__Blacklisted();
error Base__Unauthorized();

abstract contract BaseUpgradeable is ContextUpgradeable, UUPSUpgradeable {
    bytes32 private _authority;

    event AuthorityUpdated(IAuthority indexed from, IAuthority indexed to);

    modifier onlyRole(bytes32 role) {
        _checkRole(role, _msgSender());
        _;
    }

    modifier onlyWhitelisted() {
        _checkBlacklist(_msgSender());
        _;
    }

    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    modifier whenPaused() {
        _requirePaused();
        _;
    }

    function updateAuthority(IAuthority authority_)
        external
        onlyRole(Roles.OPERATOR_ROLE)
    {
        IAuthority old = authority();
        if (old == authority_) revert Base__AlreadySet();
        __updateAuthority(authority_);
        emit AuthorityUpdated(old, authority_);
    }

    function authority() public view returns (IAuthority authority_) {
        /// @solidity memory-safe-assembly
        assembly {
            authority_ := sload(_authority.slot)
        }
    }

    function __Base_init(IAuthority authority_, bytes32 role_)
        internal
        onlyInitializing
    {
        __Base_init_unchained(authority_, role_);
    }

    function __Base_init_unchained(IAuthority authority_, bytes32 role_)
        internal
        onlyInitializing
    {
        if (role_ != 0) authority_.requestAccess(role_);
        __updateAuthority(authority_);
    }

    function _checkBlacklist(address account_) internal view {
        if (authority().isBlacklisted(account_)) revert Base__Blacklisted();
    }

    function _checkRole(bytes32 role_, address account_) internal view {
        if (!authority().hasRole(role_, account_)) revert Base__Unauthorized();
    }

    function __updateAuthority(IAuthority authority_) internal {
        /// @solidity memory-safe-assembly
        assembly {
            sstore(_authority.slot, authority_)
        }
    }

    function _requirePaused() internal view {
        if (!authority().paused()) revert Base__NotPaused();
    }

    function _requireNotPaused() internal view {
        if (authority().paused()) revert Base__Paused();
    }

    function _authorizeUpgrade(address implement_)
        internal
        virtual
        override
        onlyRole(Roles.UPGRADER_ROLE)
    {}

    function _hasRole(bytes32 role_, address account_)
        internal
        view
        returns (bool)
    {
        return authority().hasRole(role_, account_);
    }

    uint256[49] private __gap;
}
