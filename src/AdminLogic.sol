//SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

abstract contract AdminLogic {
    uint256 public constant MAX_ADMINS = 5;
    uint256 public signatureThreshold;
    address[] internal admins;
    mapping(address => bool) internal hasApprovedAdd;
    uint256 internal addApprovalCount;
    address internal pendingAdmin;
    address internal pendingAdminRemoval;
    uint256 internal removeApprovalCount;
    mapping(address => bool) internal hasApprovedRemoval;

    error NotAdmin();
    error InvalidAdminAddress();
    error MaxAdminsReached();
    error AdminAlreadyExists();
    error AlreadyApproved();
    error DifferentAdminPending();
    error AdminNotFound();
    error CannotRemoveLastAdmin();

    function _setPendingAdmin(address _admin) internal {
        if (pendingAdmin == address(0)) {
            pendingAdmin = _admin;
        } else if (pendingAdmin != _admin) {
            revert DifferentAdminPending();
        }
    }

    function _approveAddAdmin() internal {
        hasApprovedAdd[msg.sender] = true;
        addApprovalCount++;
    }

    function _executeAddAdmin() internal {
        admins.push(pendingAdmin);

        pendingAdmin = address(0);
        addApprovalCount = 0;

        for (uint256 i = 0; i < admins.length; i++) {
            hasApprovedAdd[admins[i]] = false;
        }
    }

    function _setPendingAdminRemoval(address _admin) internal {
        if (pendingAdminRemoval == address(0)) {
            pendingAdminRemoval = _admin;
        } else if (pendingAdminRemoval != _admin) {
            revert DifferentAdminPending();
        }
    }

    function _approveAdminRemoval() internal {
        hasApprovedRemoval[msg.sender] = true;
        removeApprovalCount++;
    }

    function _executeAdminRemoval() internal {
        for (uint256 i = 0; i < admins.length; i++) {
            if (admins[i] == pendingAdminRemoval) {
                admins[i] = admins[admins.length - 1];
                admins.pop();
                break;
            }
        }

        pendingAdminRemoval = address(0);
        removeApprovalCount = 0;

        for (uint256 i = 0; i < admins.length; i++) {
            hasApprovedRemoval[admins[i]] = false;
        }
    }

    function _isAdmin(address _admin) internal view returns (bool) {
        for (uint256 i = 0; i < admins.length; i++) {
            if (admins[i] == _admin) {
                return true;
            }
        }

        return false;
    }

    function _getThreshold() internal view returns (uint256) {
        if (admins.length <= 2) return 1;
        return admins.length - 1;
    }
}