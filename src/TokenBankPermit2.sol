// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./tokenBank.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPermit2} from "./interfaces/IPermit2.sol";
import {IAllowanceTransfer} from "./interfaces/IAllowanceTransfer.sol";

contract TokenBankPermit2 is TokenBank {
    using SafeERC20 for IERC20;

    // Uniswap permit2 合约引用
    IPermit2 public immutable PERMIT2;

    constructor(address[] memory _initialTokens, address _permit2) TokenBank(_initialTokens) {
        PERMIT2 = IPermit2(_permit2);
    }

    function depositWithPermit2(address token, uint256 amount, uint256 nonce, uint256 deadline, bytes memory signature)
        external
    {
        require(amount > 0, "Amount must be greater than 0");
        require(supportedTokens[token], "Token not supported");

        // 构建permit2数据
        IAllowanceTransfer.PermitSingle memory permit = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: token,
                amount: uint160(amount),
                expiration: uint48(deadline),
                nonce: uint48(nonce)
            }),
            spender: address(this),
            sigDeadline: deadline
        });

        // 执行permit2授权
        PERMIT2.permit(msg.sender, permit, signature);

        // 记录存款前余额
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));

        // 通过permit2转移代币
        PERMIT2.transferFrom(msg.sender, address(this), uint160(amount), token);

        // 验证余额变化
        require(IERC20(token).balanceOf(address(this)) == balanceBefore + amount, "Balance NOT add up");

        // 更新存款余额
        balances[msg.sender][token] += amount;

        emit Deposited(msg.sender, token, amount);
    }
}
