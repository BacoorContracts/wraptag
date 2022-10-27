// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "oz-custom/contracts/oz-upgradeable/utils/structs/BitMapsUpgradeable.sol";
import "oz-custom/contracts/oz-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "oz-custom/contracts/oz-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";

import "oz-custom/contracts/internal-upgradeable/SignableUpgradeable.sol";
import "oz-custom/contracts/internal-upgradeable/TransferableUpgradeable.sol";
import "oz-custom/contracts/internal-upgradeable/ProxyCheckerUpgradeable.sol";
import "oz-custom/contracts/internal-upgradeable/FundForwarderUpgradeable.sol";
import "oz-custom/contracts/internal-upgradeable/MultiDelegatecallUpgradeable.sol";

import "./internal-upgradeable/BaseUpgradeable.sol";

import "./interfaces/ITreasury.sol";
import "./interfaces/IReceiveGate.sol";
import "./interfaces/IVoucherCreator.sol";
import "oz-custom/contracts/oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "oz-custom/contracts/oz-upgradeable/token/ERC721/IERC721Upgradeable.sol";

import "oz-custom/contracts/libraries/Bytes32Address.sol";

contract VoucherCreator is
    IVoucherCreator,
    BaseUpgradeable,
    SignableUpgradeable,
    TransferableUpgradeable,
    ProxyCheckerUpgradeable,
    FundForwarderUpgradeable,
    MultiDelegatecallUpgradeable
{
    using Bytes32Address for address;
    using ERC165CheckerUpgradeable for address;
    using MerkleProofUpgradeable for bytes32[];
    using BitMapsUpgradeable for BitMapsUpgradeable.BitMap;

    /// @dev value is equal to keccak256("VoucherCreator_v1")
    bytes32 public constant VERSION =
        0x09a19cf501f4eabee6139a372ef40601f75e9ae59d97278020c14c8fa1d853a8;

    /// @dev value is equal to keccak256("Permit(address user,bytes32 leaf,uint256 nonce,uint256 deadline)")
    bytes32 private constant __PERMIT_TYPE_HASH =
        0x092629730580794cbe77cfc1bb7dd7c823c7869c6db0078ca3d25f2368adc254;

    IReceiveGate public receiveGate;

    uint256 public verificationModeToggler;

    BitMapsUpgradeable.BitMap private __usedLeafs;
    BitMapsUpgradeable.BitMap private __supportedTokens;

    mapping(bytes32 => Voucher) private __vouchers;
    mapping(address => bytes32) public __commitments;

    modifier whenUseCommitReveal() {
        if (verificationModeToggler != 3)
            revert VoucherCreator__CommitRevealNotEnabled();
        _;
    }

    modifier whenUseXOREncryption() {
        if (verificationModeToggler != 1)
            revert VoucherCreator__XOREncryptionNotEnabled();
        _;
    }

    modifier whenUseSignatureVerification() {
        if (verificationModeToggler != 2)
            revert VoucherCreator__SignatureVerificationNotEnabled();
        _;
    }

    function initialize(
        IReceiveGate receiveGate_,
        IAuthority authority_,
        ITreasury treasury_,
        address[] calldata tokens_,
        bool[] calldata statuses_
    ) external initializer {
        receiveGate = receiveGate_;
        verificationModeToggler = 1;

        __updateTokens(tokens_, statuses_);

        __MultiDelegatecall_init_unchained();

        __Base_init_unchained(authority_, 0);
        __Signable_init(type(VoucherCreator).name, "1");
        __FundForwarder_init_unchained(address(treasury_));
    }

    function toggleVerificationMode(uint256 mode_)
        external
        onlyRole(Roles.OPERATOR_ROLE)
    {
        assembly {
            sstore(verificationModeToggler.slot, mode_)
        }
    }

    function updateTokens(address[] calldata tokens_, bool[] calldata statuses_)
        external
        onlyRole(Roles.OPERATOR_ROLE)
    {
        __updateTokens(tokens_, statuses_);
        emit TokensUpdated(tokens_, statuses_);
    }

    function requestVoucherCreation(
        uint8 amountEach_,
        uint64 start_,
        uint64 end_,
        uint96 value_,
        bytes32 root_,
        address token_,
        uint256 data_
    ) external onlyRole(Roles.PROXY_ROLE) {
        if (start_ > end_) revert VoucherCreator__InvalidArguments();

        if (!__supportedTokens.get(token_.fillLast96Bits()))
            revert VoucherCreator__UnsupportedToken();

        if (
            token_ == address(0) ||
            token_.supportsInterface(type(IERC20Upgradeable).interfaceId)
        )
            if (data_ < value_ * amountEach_)
                revert VoucherCreator__InvalidArguments();

        __vouchers[root_] = Voucher({
            token: token_,
            start: start_,
            end: end_,
            value: value_
        });

        emit VoucherCreated(token_, value_, start_, end_);
    }

    function batchProcess(bytes[] calldata data_) external {
        _multiDelegatecall(data_);
    }

    function commit(bytes32 commitment_)
        external
        whenNotPaused
        whenUseCommitReveal
    {
        address user = _msgSender();

        assembly {
            mstore(0x00, user)
            mstore(0x20, __commitments.slot)
            sstore(keccak256(0x00, 64), commitment_)
        }

        emit Commited(user, commitment_);
    }

    function redeemWithReveal(
        bytes32 root_,
        bytes32 leaf_,
        bytes32[] calldata proof_
    ) external whenNotPaused whenUseCommitReveal {
        address user = _msgSender();
        __checkUser(user);

        if (keccak256(abi.encode(leaf_)) != __commitments[user])
            revert VoucherCreator__InvalidReveal();

        delete __commitments[user];

        __processRedeem(user, root_, leaf_, proof_);
    }

    function redeem(bytes32 root_, bytes32 leaf_, bytes32[] calldata proof_)
        external
        whenNotPaused
        whenUseXOREncryption
    {
        address user = _msgSender();
        __checkUser(user);

        assembly {
            leaf_ := xor(shl(96, user), leaf_)
            root_ := xor(shl(96, user), root_)
        }

        if (__usedLeafs.get(uint256(leaf_)))
            revert VoucherCreator__AlreadyRedeemed();

        __processRedeem(user, root_, leaf_, proof_);
    }

    function redeemWithSignature(
        bytes32 root_,
        bytes32 leaf_,
        uint256 deadline_,
        bytes32[] calldata proof_,
        bytes calldata signature_
    ) external whenNotPaused whenUseSignatureVerification {
        address user = _msgSender();
        __checkUser(user);

        if (block.timestamp > deadline_) revert VoucherCreator__Expired();
        if (
            !_hasRole(
                Roles.SIGNER_ROLE,
                _recoverSigner(
                    keccak256(
                        abi.encode(
                            __PERMIT_TYPE_HASH,
                            user,
                            leaf_,
                            _useNonce(user),
                            deadline_
                        )
                    ),
                    signature_
                )
            )
        ) revert VoucherCreator__InvalidSignature();

        __processRedeem(user, root_, leaf_, proof_);
    }

    function __processRedeem(
        address user_,
        bytes32 root_,
        bytes32 leaf_,
        bytes32[] calldata proof_
    ) private {
        if (proof_.verify(root_, leaf_)) revert VoucherCreator__InvalidProof();

        Voucher memory voucher = __vouchers[root_];

        if (block.timestamp > voucher.end || block.timestamp < voucher.start)
            revert VoucherCreator__ExpiredOrNotYetStarted();

        __usedLeafs.set(uint256(leaf_));

        receiveGate.withdrawTo(voucher.token, user_, voucher.value);

        emit Redeemed(user_, voucher.token, voucher.value);
    }

    function __checkUser(address account_) private view {
        _checkBlacklist(account_);
        _onlyEOA(account_);
    }

    function __updateTokens(
        address[] calldata tokens_,
        bool[] calldata statuses_
    ) private {
        address[] memory tokens = tokens_;
        uint256 length = tokens.length;
        if (length != statuses_.length) revert VoucherCreator__LengthMismatch();
        uint256[] memory uintTokens = new uint256[](length);
        assembly {
            uintTokens := tokens
        }
        for (uint256 i; i < length; ) {
            __supportedTokens.setTo(uintTokens[i], statuses_[i]);

            unchecked {
                ++i;
            }
        }
    }

    uint256[44] private __gap;
}
