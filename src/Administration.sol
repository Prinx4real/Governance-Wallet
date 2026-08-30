//SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AdminLogic} from "./AdminLogic.sol";

contract Administration is ReentrancyGuard, AdminLogic {
    using SafeERC20 for IERC20;

    constructor(address _admin) {
        admins.push(_admin);
    }

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
        if (admins.length == 1) revert CannotRemoveLastAdmin();
        if (!_isAdmin(msg.sender)) revert NotAdmin();
        if (!_isAdmin(_admin)) revert AdminNotFound();
        if (hasApprovedRemoval[msg.sender]) revert AlreadyApproved();

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
}
