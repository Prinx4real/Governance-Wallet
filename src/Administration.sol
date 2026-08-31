//SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AdminLogic} from "./AdminLogic.sol";

contract Administration is ReentrancyGuard, AdminLogic {
    using SafeERC20 for IERC20;

    struct Transfer {
        address token;
        address payable to;
        uint256 amount;
        bool isEth;
    }

    error InvalidBatchLength();
    error BatchTransferFailed();

    constructor(address _admin, address _admin2) {
        admins.push(_admin);
        admins.push(_admin2);
    }

    function addAdmin(address _admin) external nonReentrant {
        if (!_isAdmin(msg.sender)) revert NotAdmin();
        if (_admin == address(0)) revert InvalidAdminAddress();
        if (admins.length >= MAX_ADMINS) revert MaxAdminsReached();
        if (_isAdmin(_admin)) revert AdminAlreadyExists();
        if (hasApprovedAdd[msg.sender]) revert AlreadyApproved();
        if (_isApprovalExpired(pendingAdminApprovalAt)) {
            _clearAddApprovalState();
        }

        _setPendingAdmin(_admin);
        _approveAddAdmin();

        if (addApprovalCount >= _getThreshold()) {
            _executeAddAdmin();
        }
    }

    function removeAdmin(address _admin) external nonReentrant {
        if (admins.length == 2) revert CannotRemoveFoundingAdmins();
        if (!_isAdmin(msg.sender)) revert NotAdmin();
        if (!_isAdmin(_admin)) revert AdminNotFound();
        if (hasApprovedRemoval[msg.sender]) revert AlreadyApproved();
        if (_isApprovalExpired(pendingAdminRemovalApprovalAt)) {
            _clearRemovalApprovalState();
        }

        _setPendingAdminRemoval(_admin);
        _approveAdminRemoval();

        if (removeApprovalCount >= _getThreshold()) {
            _executeAdminRemoval();
        }
    }

    function getAdminCount() public view returns (uint256) {
        // Logic to return the current number of admins
        return admins.length; // Placeholder return value
    }

    function send(address token, address payable to, uint256 amount, bool isEth) external nonReentrant {
        if (!_isAdmin(msg.sender)) revert NotAdmin();
        if (to == address(0)) revert InvalidAdminAddress();
        if (amount == 0) revert isEth ? InvalidEtherAmount() : InvalidTokenAmount();

        if (isEth) {
            if (hasApprovedEtherSend[msg.sender]) revert AlreadyApproved();
            if (_isApprovalExpired(pendingEtherSendApprovalAt)) {
                _clearEtherSendState();
            }

            uint256 contractBalance = address(this).balance;
            if (amount > contractBalance) revert InsufficientEtherBalance();

            _setPendingEtherSend(to, amount);
            _approveEtherSend();

            if (etherSendApprovalCount >= _getThreshold()) {
                (bool success, ) = to.call{value: pendingEtherAmount}("");
                require(success, "Ether transfer failed");
                _clearEtherSendState();
            }
            return;
        }

        if (token == address(0)) revert InvalidTokenAddress();
        if (hasApprovedTokenSend[msg.sender]) revert AlreadyApproved();
        if (_isApprovalExpired(pendingTokenSendApprovalAt)) {
            _clearTokenSendState();
        }

        IERC20 erc20 = IERC20(token);
        uint256 contractBalance = erc20.balanceOf(address(this));
        if (amount > contractBalance) revert InsufficientTokenBalance();

        _setPendingTokenSend(token, to, amount);
        _approveTokenSend();

        if (tokenSendApprovalCount >= _getThreshold()) {
            erc20.safeTransfer(to, amount);
            _clearTokenSendState();
        }
    }

    function batchSend(Transfer[] calldata transfers) external nonReentrant {
        if (!_isAdmin(msg.sender)) revert NotAdmin();
        if (transfers.length == 0) revert InvalidBatchLength();

        uint256 totalEthAmount;
        for (uint256 i = 0; i < transfers.length; i++) {
            if (transfers[i].to == address(0)) revert InvalidAdminAddress();
            if (transfers[i].amount == 0) revert transfers[i].isEth ? InvalidEtherAmount() : InvalidTokenAmount();

            if (transfers[i].isEth) {
                totalEthAmount += transfers[i].amount;
                continue;
            }

            if (transfers[i].token == address(0)) revert InvalidAdminAddress();
            if (transfers[i].amount > IERC20(transfers[i].token).balanceOf(address(this))) {
                revert InsufficientTokenBalance();
            }
        }

        if (totalEthAmount > address(this).balance) revert InsufficientEtherBalance();

        for (uint256 i = 0; i < transfers.length; i++) {
            if (transfers[i].isEth) {
                (bool success, ) = transfers[i].to.call{value: transfers[i].amount}("");
                if (!success) revert BatchTransferFailed();
                continue;
            }

            IERC20(transfers[i].token).safeTransfer(transfers[i].to, transfers[i].amount);
        }
    }

    receive() external payable {}

    fallback() external payable {}
}
