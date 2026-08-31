//SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

abstract contract AdminLogic {
    uint256 internal constant APPROVAL_TIMEOUT = 7 days;

    uint256 public constant MAX_ADMINS = 5;
    uint256 public signatureThreshold;
    uint256 internal addApprovalCount;
    uint256 internal tokenSendApprovalCount;
    uint256 internal etherSendApprovalCount;
    uint256 internal batchSendApprovalCount;
    uint256 internal removeApprovalCount;
    uint256 internal pendingTokenAmount;
    uint256 internal pendingEtherAmount;
    uint256 internal pendingAdminApprovalAt;
    uint256 internal pendingAdminRemovalApprovalAt;
    uint256 internal pendingTokenSendApprovalAt;
    uint256 internal pendingEtherSendApprovalAt;
    uint256 internal pendingBatchApprovalAt;

    address[] internal admins;
    address internal pendingAdmin;
    address internal pendingAdminRemoval;
    address internal pendingToken;
    address internal pendingTokenRecipient;
    address internal pendingEtherRecipient;
    bytes32 internal pendingBatchHash;

    mapping(address => bool) internal hasApprovedTokenSend;
    mapping(address => bool) internal hasApprovedAdd;
    mapping(address => bool) internal hasApprovedRemoval;
    mapping(address => bool) internal hasApprovedEtherSend;
    mapping(address => bool) internal hasApprovedBatchSend;

    error NotAdmin();
    error InvalidAdminAddress();
    error MaxAdminsReached();
    error AdminAlreadyExists();
    error AlreadyApproved();
    error DifferentAdminPending();
    error AdminNotFound();
    error CannotRemoveFoundingAdmins();
    error InvalidTokenAmount();
    error InsufficientTokenBalance();
    error InvalidEtherAmount();
    error InsufficientEtherBalance();
    error InvalidTokenAddress();

    function _setPendingAdmin(address _admin) internal {
        if (pendingAdmin == address(0)) {
            pendingAdmin = _admin;
            pendingAdminApprovalAt = block.timestamp;
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

        _clearAddApprovalState();
    }

    function _setPendingAdminRemoval(address _admin) internal {
        if (pendingAdminRemoval == address(0)) {
            pendingAdminRemoval = _admin;
            pendingAdminRemovalApprovalAt = block.timestamp;
        } else if (pendingAdminRemoval != _admin) {
            revert DifferentAdminPending();
        }
    }

    function _setPendingTokenSend(address token, address to, uint256 amount) internal {
        if (pendingToken == address(0)) {
            pendingToken = token;
            pendingTokenRecipient = to;
            pendingTokenAmount = amount;
            pendingTokenSendApprovalAt = block.timestamp;
        } else if (pendingToken != token || pendingTokenRecipient != to || pendingTokenAmount != amount) {
            revert DifferentAdminPending();
        }
    }

    function _approveTokenSend() internal {
        hasApprovedTokenSend[msg.sender] = true;
        tokenSendApprovalCount++;
    }

    function _setPendingEtherSend(address to, uint256 amount) internal {
        if (pendingEtherRecipient == address(0) && pendingEtherAmount == 0) {
            pendingEtherRecipient = to;
            pendingEtherAmount = amount;
            pendingEtherSendApprovalAt = block.timestamp;
        } else if (pendingEtherRecipient != to || pendingEtherAmount != amount) {
            revert DifferentAdminPending();
        }
    }

    function _approveEtherSend() internal {
        hasApprovedEtherSend[msg.sender] = true;
        etherSendApprovalCount++;
    }

    function _setPendingBatch(bytes32 batchHash) internal {
        if (pendingBatchHash == bytes32(0)) {
            pendingBatchHash = batchHash;
            pendingBatchApprovalAt = block.timestamp;
        } else if (pendingBatchHash != batchHash) {
            revert DifferentAdminPending();
        }
    }

    function _approveBatchSend() internal {
        hasApprovedBatchSend[msg.sender] = true;
        batchSendApprovalCount++;
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

        _clearRemovalApprovalState();
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
        if (admins.length == 2) return 2;
        return admins.length - 1;
    }

    function _isApprovalExpired(uint256 startedAt) internal view returns (bool) {
        return startedAt != 0 && block.timestamp - startedAt >= APPROVAL_TIMEOUT;
    }

    function _clearAddApprovalState() internal {
        pendingAdmin = address(0);
        pendingAdminApprovalAt = 0;
        addApprovalCount = 0;

        for (uint256 i = 0; i < admins.length; i++) {
            hasApprovedAdd[admins[i]] = false;
        }
    }

    function _clearRemovalApprovalState() internal {
        pendingAdminRemoval = address(0);
        pendingAdminRemovalApprovalAt = 0;
        removeApprovalCount = 0;

        for (uint256 i = 0; i < admins.length; i++) {
            hasApprovedRemoval[admins[i]] = false;
        }
    }

    function _clearTokenSendState() internal {
        pendingToken = address(0);
        pendingTokenRecipient = address(0);
        pendingTokenAmount = 0;
        pendingTokenSendApprovalAt = 0;
        tokenSendApprovalCount = 0;

        for (uint256 i = 0; i < admins.length; i++) {
            hasApprovedTokenSend[admins[i]] = false;
        }
    }

    function _clearEtherSendState() internal {
        pendingEtherRecipient = address(0);
        pendingEtherAmount = 0;
        pendingEtherSendApprovalAt = 0;
        etherSendApprovalCount = 0;

        for (uint256 i = 0; i < admins.length; i++) {
            hasApprovedEtherSend[admins[i]] = false;
        }
    }

    function _clearBatchSendState() internal {
        pendingBatchHash = bytes32(0);
        pendingBatchApprovalAt = 0;
        batchSendApprovalCount = 0;

        for (uint256 i = 0; i < admins.length; i++) {
            hasApprovedBatchSend[admins[i]] = false;
        }
    }
}