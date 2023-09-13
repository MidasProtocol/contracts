// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {IERC20Upgradeable as IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IERC20MetadataUpgradeable as IERC20Metadata} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import {SafeERC20Upgradeable as SafeERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {EnumerableSetUpgradeable as EnumerableSet} from "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

import "../interfaces/IManageableVault.sol";
import "../interfaces/IStUSD.sol";
import "../interfaces/IDataFeed.sol";

import "../access/Greenlistable.sol";

import "../libraries/DecimalsCorrectionLibrary.sol";
import "../access/Pausable.sol";

/**
 * @title ManageableVault
 * @author RedDuck Software
 * @notice Contract with base Vault methods
 */
abstract contract ManageableVault is
    Greenlistable,
    Pausable,
    IManageableVault
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using DecimalsCorrectionLibrary for uint256;
    using SafeERC20 for IERC20;

    /**
     * @notice address that represents off-chain USD bank transfer
     */
    address public constant MANUAL_FULLFILMENT_TOKEN = address(0x0);

    /**
     * @notice 100 percent with base 100
     * @dev for example, 10% will be (10 * 100)%
     */
    uint256 public constant ONE_HUNDRED_PERCENT = 100 * 100; 
    /**
     * @notice stUSD token
     */
    IStUSD public stUSD;

    /**
     * @dev tokens that can be used as USD representation
     */
    EnumerableSet.AddressSet internal _paymentTokens;

    /**
     * @dev fees for different tokens
     */
    mapping(address => uint256) internal _feesForTokens;

    /**
     * @dev checks that msg.sender do have a vaultRole() role
     */
    modifier onlyVaultAdmin() {
        _onlyRole(vaultRole(), msg.sender);
        _;
    }

    /**
     * @dev upgradeable patter contract`s initializer
     * @param _ac address of MidasAccessControll contract
     * @param _stUSD address of stUSD token
     */
    // solhint-disable func-name-mixedcase
    function __ManageableVault_init(
        address _ac,
        address _stUSD
    ) internal onlyInitializing {
        stUSD = IStUSD(_stUSD);
        __Greenlistable_init(_ac);
        __Pausable_init(_ac);
    }

    /**
     * @notice withdraws `amoount` of a given `token` from the contract.
     * can be called only from permissioned actor.
     * @param token token address
     * @param amount token amount
     * @param withdrawTo withdraw destination address
     */
    function withdrawToken(
        address token,
        uint256 amount,
        address withdrawTo
    ) external onlyVaultAdmin {
        IERC20(token).safeTransfer(withdrawTo, amount);

        emit WithdrawToken(msg.sender, token, withdrawTo, amount);
    }

    /**
     * @inheritdoc IManageableVault
     * @dev reverts if token is already added
     */
    function addPaymentToken(address token) external onlyVaultAdmin {
        require(token != address(0), "MV: invalid token");
        require(_paymentTokens.add(token), "MV: already added");
        emit AddPaymentToken(token, msg.sender);
    }

    /**
     * @inheritdoc IManageableVault
     * @dev reverts if token is not presented
     */
    function removePaymentToken(address token) external onlyVaultAdmin {
        require(_paymentTokens.remove(token), "MV: not exists");
        emit RemovePaymentToken(token, msg.sender);
    }

    /**
     * @inheritdoc IManageableVault
     * @dev reverts is token is not presented
     */
    function setFee(address token, uint256 newFee) external onlyVaultAdmin {
        require(_paymentTokens.contains(token), "MV: doesn't exist");
        
        require(newFee <= ONE_HUNDRED_PERCENT, "MV: fee exceeds limit");

        _feesForTokens[token] = newFee;

        emit SetFee(msg.sender, token, newFee);
    }

    /**
     * @notice returns array of `_paymentTokens`
     * can be called only from permissioned actor.
     * @return paymentTokens array of payment tokens
     */
    function getPaymentTokens() external view returns (address[] memory) {
        return _paymentTokens.values();
    }

    /**
     * @notice AC role of vault administrator
     * @return role bytes32 role
     */
    function vaultRole() public view virtual returns (bytes32);

    function pauseAdminRole() public view override returns (bytes32) {
        return vaultRole();
    }

    /**
     * @dev do safe transfer from on a given token
     * and converts amount from base18 to amount for a given token
     * @param user user address
     * @param token address of token
     * @param amount amount of `token` to transfer to `user`
     */
    function _tokenTransferFrom(
        address user,
        address token,
        uint256 amount
    ) internal {
        IERC20(token).safeTransferFrom(
            user,
            address(this),
            amount.convertFromBase18(_tokenDecimals(token))
        );
    }

    /**
     * @dev do safe transfer on a given token. Doesnt perform transfer if
     * token is `MANUAL_FULLFILMENT_TOKEN` as it should be transfered off-chain
     * @param user user address
     * @param token address of token
     * @param amount amount of `token` to transfer to `user`
     */
    function _transferToken(
        address user,
        address token,
        uint256 amount
    ) internal {
        // MANUAL_FULLFILMENT_TOKEN should be transfered off-chain to user`s bank account
        if (token == MANUAL_FULLFILMENT_TOKEN) return;

        IERC20(token).safeTransfer(
            user,
            amount.convertFromBase18(_tokenDecimals(token))
        );
    }

    /**
     * @dev retreives decimals of a given `token`
     * @param token address of token
     * @return decimals decinmals value of a given `token`
     */
    function _tokenDecimals(address token) internal view returns (uint8) {
        return IERC20Metadata(token).decimals();
    }

    /**
     * @dev checks that `token` is presented in `_paymentTokens`
     * @param token address of token
     */
    function _requireTokenExists(address token) internal view virtual {
        require(_paymentTokens.contains(token), "MV: token not exists");
    }
}
