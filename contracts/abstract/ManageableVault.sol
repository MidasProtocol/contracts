// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20Upgradeable as IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IERC20MetadataUpgradeable as IERC20Metadata} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import {SafeERC20Upgradeable as SafeERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {EnumerableSetUpgradeable as EnumerableSet} from "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

import "../interfaces/IManageableVault.sol";
import "../interfaces/IStUSD.sol";
import "../interfaces/IDataFeed.sol";

import "../access/Greenlistable.sol";

import "../libraries/DecimalsCorrectionLibrary.sol";

/**
 * @title Contract with base Vault methods
 * @author RedDuck Software
 */
abstract contract ManageableVault is Greenlistable, IManageableVault {
    using EnumerableSet for EnumerableSet.AddressSet;
    using DecimalsCorrectionLibrary for uint256;
    using SafeERC20 for IERC20;

    /**
     * @notice address that represents off-chain USD bank transfer
     */
    address public constant MANUAL_FULLFILMENT_TOKEN = address(0x0);

    /**
     * @notice base points for percentage calculation
     * @dev for example, 100% will be (100 * PERCENTAGE_BPS)%
     */
    uint256 public constant PERCENTAGE_BPS = 100;

    /**
     * @notice IBO1/USD ChainLink data feed
     */
    IDataFeed public etfDataFeed;

    /**
     * @notice stUSD token
     */
    IStUSD public stUSD;

    /**
     * @dev tokens that can be used as USD representation
     */
    EnumerableSet.AddressSet internal _paymentTokens;

    /**
     * @dev value with `PERCENTAGE_BPS`
     */
    uint256 internal _fee;

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
     * @param _etfDataFeed address of CL`s data feed IB01/USD
     */
    function __ManageableVault_init(
        address _ac,
        address _stUSD,
        address _etfDataFeed
    ) internal onlyInitializing {
        stUSD = IStUSD(_stUSD);
        etfDataFeed = IDataFeed(_etfDataFeed);
        __Greenlistable_init(_ac);
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
        IERC20(token).transfer(withdrawTo, amount);
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
     */
    function setFee(uint256 newFee) external onlyVaultAdmin {
        _fee = newFee;
        emit SetFee(msg.sender, newFee);
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
