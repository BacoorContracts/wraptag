// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IVoucherCreator {
    error VoucherCreator__Expired();
    error VoucherCreator__InvalidProof();
    error VoucherCreator__InvalidReveal();
    error VoucherCreator__LengthMismatch();
    error VoucherCreator__AlreadyRedeemed();
    error VoucherCreator__UnsupportedToken();
    error VoucherCreator__InvalidArguments();
    error VoucherCreator__InvalidSignature();
    error VoucherCreator__ExpiredOrNotYetStarted();
    error VoucherCreator__CommitRevealNotEnabled();
    error VoucherCreator__XOREncryptionNotEnabled();
    error VoucherCreator__SignatureVerificationNotEnabled();

    struct Voucher {
        address token;
        uint64 start;
        uint64 end;
        uint256 value;
    }

    event Commited(address indexed user, bytes32 indexed commitment);
    event Redeemed(
        address indexed redeemer,
        address indexed token,
        uint256 indexed value
    );
    event VoucherCreated(
        address indexed,
        address indexed token,
        uint256 indexed value,
        uint256 start,
        uint256 end
    );
    event TokensUpdated(address[] indexed tokens, bool[] indexed statuses);

    function toggleVerificationMode(uint256 mode_) external;

    function updateTokens(address[] calldata tokens_, bool[] calldata statuses_)
        external;

    function requestVoucherCreation(
        address from_,
        address token_,
        uint64 start_,
        uint64 end_,
        uint256 value_,
        bytes32 root_
    ) external;

    function batchProcess(bytes[] calldata data_) external;

    function commit(bytes32 commitment_) external;

    function redeemWithReveal(
        bytes32 root_,
        bytes32 leaf_,
        bytes32[] calldata proof_
    ) external;

    function redeem(bytes32 root_, bytes32 leaf_, bytes32[] calldata proof_)
        external;

    function redeemWithSignature(
        bytes32 root_,
        bytes32 leaf_,
        uint256 deadline_,
        bytes32[] calldata proof_,
        bytes calldata signature_
    ) external;
}
