pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/TokenBankPermit2.sol";
import "../src/ExtERC20.sol";
import {Permit2} from "../src/Permit2.sol";
import {IAllowanceTransfer} from "../src/interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "../src/interfaces/ISignatureTransfer.sol";

contract TokenBankPermit2Test is Test {
    TokenBankPermit2 public bank;
    ExtERC20 public token;
    Permit2 public permit2;
    uint256 ownerPrivateKey;
    address owner;

    function setUp() public {
        // 部署 Permit2
        permit2 = new Permit2();

        // 部署测试代币
        token = new ExtERC20("Test Token", "TST", 18, 1000 ether);

        // 初始化支持的代币列表
        address[] memory tokens = new address[](1);
        tokens[0] = address(token);

        // 部署 TokenBankPermit2
        bank = new TokenBankPermit2(tokens, address(permit2));

        // 创建用户账户
        (owner, ownerPrivateKey) = makeAddrAndKey("owner");
        token.transfer(owner, 100 ether);
    }

    function testDepositWithPermit2() public {
        uint256 amount = 10 ether;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 days;

        // 生成签名
        bytes memory signature = getPermit2Signature(owner, ownerPrivateKey, address(token), amount, nonce, deadline);

        vm.startPrank(owner);
        // 先授权给Permit2合约
        token.approve(address(permit2), type(uint256).max);
        /*
        // 构建permit2数据
        IAllowanceTransfer.PermitSingle memory permit = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(token),
                amount: uint160(amount),
                expiration: uint48(deadline),
                nonce: uint48(nonce)
            }),
            spender: address(bank),
            sigDeadline: deadline
        });
        */

        // 执行permitDeposit
        bank.depositWithPermit2(address(token), amount, nonce, deadline, signature);
        vm.stopPrank();

        // 验证结果
        assertEq(bank.balances(owner, address(token)), amount);
        assertEq(token.balanceOf(address(bank)), amount);
    }

    function getPermit2Signature(
        address _owner,
        uint256 privateKey,
        address _token,
        uint256 amount,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes memory) {
        bytes32 PERMIT2_TYPEHASH = keccak256(
            "PermitSingle(PermitDetails details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
        );

        bytes32 PERMIT_DETAILS_TYPEHASH =
            keccak256("PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)");

        bytes32 detailsHash =
            keccak256(abi.encode(PERMIT_DETAILS_TYPEHASH, _token, uint160(amount), uint48(deadline), uint48(nonce)));

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                permit2.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(PERMIT2_TYPEHASH, detailsHash, address(bank), deadline))
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }
}
