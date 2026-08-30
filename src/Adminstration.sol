//SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AdminLogic} from "./AdminLogic.sol";

contract Administration is ReentrancyGuard, AdminLogic {
    using SafeERC20 for IERC20;

    error NoAdminsToRemove();
    error InvalidTokenAmount();
    error InsufficientTokenBalance();
    error InvalidEtherAmount();
    error InsufficientEtherBalance();

    constructor() {}

    function addAdmin(address _admin) external nonReentrant {
        if (!_isAdmin(msg.sender)) revert NotAdmin();
        if (_admin == address(0)) revert InvalidAdminAddress();
        if (admins.length >= MAX_ADMINS) revert MaxAdminsReached();
        if (_isAdmin(_admin)) revert AdminAlreadyExists();
        if (hasApprovedAdd[msg.sender]) revert AlreadyApproved();

        _setPendingAdmin(_admin);
        _approveAddAdmin();

        if (addApprovalCount >= _getThreshold()) {
            _executeAddAdmin();
        }
    }

    function removeAdmin(address _admin) external nonReentrant {
        if (admins.length == 0) revert NoAdminsToRemove();
        if (!_isAdmin(msg.sender)) revert NotAdmin();
        if (!_isAdmin(_admin)) revert AdminNotFound();
        if (hasApprovedRemoval[msg.sender]) revert AlreadyApproved();

        _setPendingAdminRemoval(_admin);
        _approveAdminRemoval();

        if (removeApprovalCount >= _getThreshold()) {
            _executeAdminRemoval();
        }
    }

    function getSignatureThreshold() public view returns (uint256) {
        if (admins.length <= 2) return 1;
        return admins.length - 1;
    }

    function getAdminCount() public view returns (uint256) {
        return admins.length;
    }

    function sendTokens(IERC20 token, address to, uint256 amount) external nonReentrant {
        if (!_isAdmin(msg.sender)) revert NotAdmin();
        if (to == address(0)) revert InvalidAdminAddress();
        if (amount == 0) revert InvalidTokenAmount();

        uint256 contractBalance = token.balanceOf(address(this));
        if (amount > contractBalance) revert InsufficientTokenBalance();
        token.safeTransfer(to, amount);
    }

    function sendEther(address payable to, uint256 amount) external nonReentrant {
        if (!_isAdmin(msg.sender)) revert NotAdmin();
        if (to == address(0)) revert InvalidAdminAddress();
        if (amount == 0) revert InvalidEtherAmount();

        uint256 contractBalance = address(this).balance;
        if (amount > contractBalance) revert InsufficientEtherBalance();
        (bool success, ) = to.call{value: amount}("");
        require(success, "Ether transfer failed");
    }

    receive() external payable {}

    fallback() external payable {}
}