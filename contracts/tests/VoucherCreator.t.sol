// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Vm.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

import "./ERC20Mock.t.sol";
import "./ERC721Mock.t.sol";
import "./SigUtils.t.sol";

import {ITreasury, Treasury} from "../Treasury.sol";
import {Roles, IAuthority, Authority} from "../Authority.sol";
import {IReceiveGate, ReceiveGate} from "../ReceiveGate.sol";
import {IVoucherCreator, VoucherCreator} from "../VoucherCreator.sol";

import "../interfaces/ITreasury.sol";
import "../interfaces/IAuthority.sol";
import "../interfaces/IReceiveGate.sol";
import "../interfaces/IVoucherCreator.sol";

interface CheatCodes {
    // Gets address for a given private key, (privateKey) => (address)
    function addr(uint256) external returns (address);
}

contract VoucherCreatorTest is Test {
    address public admin;
    address public creator;
    address public claimer;

    uint256 public adminPk;
    uint256 public creatorPk;

    SigUtils public sigUtils;

    ERC20Test public erc20;
    ERC721Test public erc721;
    Treasury public treasury;
    Authority public authority;
    ReceiveGate public receiveGate;
    VoucherCreator public voucherCreator;

    CheatCodes public cheats = CheatCodes(HEVM_ADDRESS);

    constructor() {
        adminPk = 0xAD111;
        creatorPk = 0xC1EA7;

        admin = vm.addr(adminPk);
        creator = vm.addr(creatorPk);

        claimer = vm.addr(1);

        vm.startPrank(admin, admin);

        erc20 = new ERC20Test();
        sigUtils = new SigUtils(erc20.DOMAIN_SEPARATOR());
        erc721 = new ERC721Test();

        {
            authority = new Authority();
            authority.initialize();
            authority.grantRole(Roles.SIGNER_ROLE, admin);
        }

        {
            treasury = new Treasury();
            treasury.initialize(IAuthority(address(authority)));
        }

        {
            voucherCreator = new VoucherCreator();
        }

        {
            receiveGate = new ReceiveGate(
                address(treasury),
                IAuthority(address(authority))
            );
            receiveGate.whitelistAddress(address(voucherCreator));
        }

        address[] memory tokens = new address[](3);
        tokens[0] = address(0);
        tokens[1] = address(erc20);
        tokens[2] = address(erc721);
        bool[] memory statuses = new bool[](3);
        statuses[0] = true;
        statuses[1] = true;
        statuses[2] = true;
        voucherCreator.initialize(
            IReceiveGate(address(receiveGate)),
            IAuthority(address(authority)),
            ITreasury(address(treasury)),
            tokens,
            statuses
        );

        vm.stopPrank();
        assertTrue(!authority.paused());
    }

    function setUp() public {
        hoax(creator, 1_000_000 ether);
        erc20.mint(creator, 1_000_000);

        uint256[] memory tokenIds = new uint256[](10);
        for (uint256 i; i < 10; ++i) {
            tokenIds[i] = i;
        }

        erc721.mintBatch(creator, tokenIds);
    }

    function testValidNativeVoucher() public {
        bytes32 fakeRoot = 0xcc086fcc038189b4641db2cc4f1de3bb132aefbd65d510d817591550937818c7;

        bytes memory data = abi.encode(
            10,
            uint64(block.timestamp),
            uint64(block.timestamp + 1 days),
            1 ether,
            fakeRoot
        );

        vm.startPrank(creator);

        uint256 gasSpent = gasleft();
        receiveGate.depositNativeTokenWithCommand{value: 10 ether}(
            address(voucherCreator),
            voucherCreator.requestVoucherCreation.selector,
            data
        );
        assembly {
            gasSpent := sub(gasSpent, gas())
        }
        console.logUint(gasSpent);

        vm.stopPrank();
    }

    function testValidERC20Voucher() public {
        bytes memory data;
        {
            bytes32 fakeRoot = 0xcc086fcc038189b4641db2cc4f1de3bb132aefbd65d510d817591550937818c7;

            data = abi.encode(
                10,
                uint64(block.timestamp),
                uint64(block.timestamp + 1 days),
                1 ether,
                fakeRoot
            );
        }

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: creator,
            spender: address(receiveGate),
            value: 10 ether,
            nonce: 0,
            deadline: 1 days
        });

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creatorPk,
            sigUtils.getTypedDataHash(permit)
        );

        vm.startPrank(creator);

        uint256 gasSpent = gasleft();

        receiveGate.depositERC20WithCommand(
            erc20,
            10 ether,
            1 days,
            v,
            r,
            s,
            voucherCreator.requestVoucherCreation.selector,
            address(voucherCreator),
            data
        );
        assembly {
            gasSpent := sub(gasSpent, gas())
        }
        console.logUint(gasSpent);

        vm.stopPrank();
    }

    function testValidERC721SingleVoucher() public {
        bytes32 fakeRoot = 0xcc086fcc038189b4641db2cc4f1de3bb132aefbd65d510d817591550937818c7;

        bytes memory data = abi.encode(
            address(voucherCreator),
            voucherCreator.requestVoucherCreation.selector,
            abi.encode(
                1,
                uint64(block.timestamp),
                uint64(block.timestamp + 1 days),
                3, // tokenId
                fakeRoot
            )
        );

        vm.startPrank(creator);

        uint256 gasSpent = gasleft();

        erc721.safeTransferFrom(creator, address(receiveGate), 3, data);
        assembly {
            gasSpent := sub(gasSpent, gas())
        }
        console.logUint(gasSpent);

        vm.stopPrank();
    }

    function testSuccessRedeemWithXOR() public {
        testValidNativeVoucher();

        bytes32 leaf = 0xdca3326ad7e8121bf9cf9c12333e6b2271abe823ec9edfe42f813b1e768fa57b;
        bytes32 root = 0xcc086fcc038189b4641db2cc4f1de3bb132aefbd65d510d817591550937818c7;
        address _claimer = claimer;
        assembly {
            leaf := xor(shl(96, _claimer), leaf)
            root := xor(shl(96, _claimer), root)
        }

        bytes32[] memory proofs = new bytes32[](2);
        proofs[
            0
        ] = 0x8da9e1c820f9dbd1589fd6585872bc1063588625729e7ab0797cfc63a00bd950;
        proofs[
            1
        ] = 0x995788ffc103b987ad50f5e5707fd094419eb12d9552cc423bd0cd86a3861433;

        vm.startPrank(claimer, claimer);

        voucherCreator.redeem(root, leaf, proofs);

        vm.stopPrank();
    }

    function testSuccessBatchCommitReveal() public {
        testValidERC20Voucher();

        vm.startPrank(admin, admin);
        voucherCreator.toggleVerificationMode(3);
        vm.stopPrank();

        bytes memory commitCallData = abi.encodeCall(
            voucherCreator.commit,
            (
                keccak256(
                    abi.encode(
                        0xdca3326ad7e8121bf9cf9c12333e6b2271abe823ec9edfe42f813b1e768fa57b
                    )
                )
            )
        );
        bytes32[] memory proofs = new bytes32[](2);
        proofs[
            0
        ] = 0x8da9e1c820f9dbd1589fd6585872bc1063588625729e7ab0797cfc63a00bd950;
        proofs[
            1
        ] = 0x995788ffc103b987ad50f5e5707fd094419eb12d9552cc423bd0cd86a3861433;
        bytes memory redeemWithRevealCallData = abi.encodeCall(
            voucherCreator.redeemWithReveal,
            (
                0xcc086fcc038189b4641db2cc4f1de3bb132aefbd65d510d817591550937818c7,
                0xdca3326ad7e8121bf9cf9c12333e6b2271abe823ec9edfe42f813b1e768fa57b,
                proofs
            )
        );

        bytes[] memory data = new bytes[](2);
        data[0] = commitCallData;
        data[1] = redeemWithRevealCallData;

        vm.startPrank(claimer, claimer);

        voucherCreator.batchProcess(data);

        vm.stopPrank();
    }
}
