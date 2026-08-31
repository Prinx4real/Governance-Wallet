//SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AdminLogic} from "./AdminLogic.sol";

contract GovernanceWallet is ReentrancyGuard, AdminLogic {
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

    function _executeTransfer(address token, address payable to, uint256 amount, bool isEth) internal {
        if (isEth) {
            (bool success, ) = to.call{value: amount}("");
            if (!success) revert BatchTransferFailed();
            return;
        }

        IERC20(token).safeTransfer(to, amount);
    }

    function _validateTransfer(address token, address payable to, uint256 amount, bool isEth) internal view {
        if (to == address(0)) revert InvalidAdminAddress();
        if (amount == 0) {
            if (isEth) revert InvalidEtherAmount();
            revert InvalidTokenAmount();
        }

        if (isEth) {
            if (amount > address(this).balance) revert InsufficientEtherBalance();
            return;
        }

        if (token == address(0)) revert InvalidTokenAddress();
        if (amount > IERC20(token).balanceOf(address(this))) revert InsufficientTokenBalance();
    }

    function send(address token, address payable to, uint256 amount, bool isEth) external nonReentrant {
        if (!_isAdmin(msg.sender)) revert NotAdmin();

        if (isEth) {
            if (hasApprovedEtherSend[msg.sender]) revert AlreadyApproved();
            if (_isApprovalExpired(pendingEtherSendApprovalAt)) {
                _clearEtherSendState();
            }
        } else {
            if (hasApprovedTokenSend[msg.sender]) revert AlreadyApproved();
            if (_isApprovalExpired(pendingTokenSendApprovalAt)) {
                _clearTokenSendState();
            }
        }

        _validateTransfer(token, to, amount, isEth);

        if (isEth) {
            _setPendingEtherSend(to, amount);
            _approveEtherSend();

            if (etherSendApprovalCount >= _getThreshold()) {
                _executeTransfer(address(0), to, pendingEtherAmount, true);
                _clearEtherSendState();
            }
            return;
        }

        _setPendingTokenSend(token, to, amount);
        _approveTokenSend();

        if (tokenSendApprovalCount >= _getThreshold()) {
            _executeTransfer(token, to, pendingTokenAmount, false);
            _clearTokenSendState();
        }
    }

    function _executeBatchSend(Transfer[] calldata transfers) internal {
        for (uint256 i = 0; i < transfers.length; i++) {
            _executeTransfer(transfers[i].token, transfers[i].to, transfers[i].amount, transfers[i].isEth);
        }
    }

    function batchSend(Transfer[] calldata transfers) external nonReentrant {
        if (!_isAdmin(msg.sender)) revert NotAdmin();
        if (transfers.length == 0) revert InvalidBatchLength();
        if (hasApprovedBatchSend[msg.sender]) revert AlreadyApproved();
        if (_isApprovalExpired(pendingBatchApprovalAt)) {
            _clearBatchSendState();
        }

        bytes32 batchHash = keccak256(abi.encode(transfers));
        _setPendingBatch(batchHash);
        _approveBatchSend();

        uint256 totalEthAmount;
        for (uint256 i = 0; i < transfers.length; i++) {
            _validateTransfer(transfers[i].token, transfers[i].to, transfers[i].amount, transfers[i].isEth);
            if (transfers[i].isEth) totalEthAmount += transfers[i].amount;
        }

        if (totalEthAmount > address(this).balance) revert InsufficientEtherBalance();

        if (batchSendApprovalCount >= _getThreshold()) {
            _executeBatchSend(transfers);
            _clearBatchSendState();
        }
    }

    receive() external payable {}

    fallback() external payable {}
}
