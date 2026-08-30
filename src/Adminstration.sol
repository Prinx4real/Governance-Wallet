//SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Administration is ReentrancyGuard {
    using SafeERC20 for IERC20;

    ////////// ////// State Variables //////////////
    uint256 public constant MAX_ADMINS = 5;
    address[] private admins;
    uint256 public signatureThreshold;
    mapping(address => bool) private hasApprovedAdd;
    uint256 private addApprovalCount;
    address private pendingAdmin;

    ////////////// Error Definitions //////////////

    error NotAdmin();
    error InvalidAdminAddress();
    error MaxAdminsReached();
    error AdminAlreadyExists();
    error AlreadyApproved();
    error DifferentAdminPending();
    error NoAdminsToRemove();
    error AdminNotFound();
    error CannotRemoveLastAdmin();
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

    function getSignatureThreshold() public view returns (uint256) {
        if (admins.length <= 2) return 1;
        return admins.length - 1;
    }

    function getAdminCount() public view returns (uint256) {
        // Logic to return the current number of admins
        return admins.length; // Placeholder return value
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