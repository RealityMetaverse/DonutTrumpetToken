// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract DonutTrumpet is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PermitUpgradeable,
    OwnableUpgradeable
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ======================================
    // =          State Variables           =
    // ======================================
    uint256 private constant FIXED_POINT_PRECISION = 10 ** 18;

    /// @dev `minTransferableAmount`, `defaultFeeTX` and `defaultFeeTrade` represent 0.0x
    uint256 public constant minTransferableAmount = 10000;
    uint256 public defaultFeeTX;
    uint256 public defaultFeeTrade;

    bool public isFeeEnabledTX;
    bool public isFeeEnabledTrade;

    /// @dev if false then the fee added to the amount instead of deducting during a simple tx
    bool public isFeeDeductedTX;
    /// @dev if false then the fee added to the amount instead of deducting during a trade
    bool public isFeeDecuctedTrade;

    address public feeReceiver;

    enum TokenSender {
        INITIATOR,
        PARTICIPATOR
    }

    struct SpecialWallet {
        bool hasSpecialFee;
        uint256 specialFeePercentage;
    }

    struct SpecialContract {
        bool hasSpecialFee;
        bool hasSpecialTreatment;
        uint256 specialFeePercentage;
        TokenSender feePayer;
    }

    mapping(address => SpecialWallet) private walletsWithSpecialTreatment;
    mapping(address => SpecialContract) private contractsWithSpecialTreatment;

    // ======================================
    // =           Custom Errors            =
    // ======================================
    error PercentageOverflow(uint256 maxValue);
    error BelowMinTranferableAmout(uint256 intendedAmount, uint256 minAmount);

    // ======================================
    // =         Contract Functions         =
    // ======================================
    function _checkIfContract(address targetAddress) private view returns (bool) {
        if (targetAddress.code.length > 0) return true;
        else return false;
    }

    // As a side effect it is considered trade if multi-sig wallet owners send the token to themselves
    function _checkIfTrade(address sender, address recipient) private view returns (bool) {
        if (msg.sender == sender && tx.origin != recipient) return false;
        else return true;
    }

    // ======================================
    // =    Determining Fee Percentage      =
    // ======================================
    function _getContractFee(address msgSender, address tokenReceiver) private view returns (uint256) {
        SpecialContract memory targetContract = contractsWithSpecialTreatment[msgSender];
        TokenSender payerSide = (tx.origin == tokenReceiver) ? TokenSender.PARTICIPATOR : TokenSender.INITIATOR;

        if (targetContract.hasSpecialFee) {
            if (targetContract.specialFeePercentage != 0) {
                return (!targetContract.hasSpecialTreatment || targetContract.feePayer == payerSide)
                    ? targetContract.specialFeePercentage
                    : 0;
            } else {
                return 0;
            }
        } else {
            return (!targetContract.hasSpecialTreatment || targetContract.feePayer == payerSide) ? defaultFeeTrade : 0;
        }
    }

    function _getWalletFee(address msgSender) private view returns (uint256) {
        SpecialWallet memory walletTreatment = walletsWithSpecialTreatment[msgSender];

        if (walletTreatment.hasSpecialFee) return walletTreatment.specialFeePercentage;
        else return defaultFeeTX;
    }

    function _checkFeePercentage(bool isConsideredTrade, address msgSender, address tokenReceiver)
        private
        view
        returns (uint256)
    {
        if (isConsideredTrade) {
            if (isFeeEnabledTrade) return _getContractFee(msgSender, tokenReceiver);
            else return 0;
        } else {
            if (isFeeEnabledTX) return _getWalletFee(msgSender);
            else return 0;
        }
    }

    // ======================================
    // =  Overriden `_transfer` Function    =
    // ======================================
    function _transfer(address sender, address recipient, uint256 amount) internal override {
        bool isConsideredTrade = (_checkIfContract(msg.sender) && _checkIfTrade(sender, recipient));

        uint256 appliedFeePercentage = _checkFeePercentage(isConsideredTrade, msg.sender, recipient);
        uint256 netTokenTransfer = amount;

        if (appliedFeePercentage != 0) {
            if (amount < minTransferableAmount) revert BelowMinTranferableAmout(amount, minTransferableAmount);
            uint256 fee;

            if ((!isConsideredTrade && isFeeDeductedTX) || (isConsideredTrade && isFeeDecuctedTrade)) {
                fee = amount * appliedFeePercentage * FIXED_POINT_PRECISION / minTransferableAmount
                    / FIXED_POINT_PRECISION;
                netTokenTransfer = amount - fee;
            } else {
                uint256 totalAmount = amount * minTransferableAmount * FIXED_POINT_PRECISION
                    / (minTransferableAmount - appliedFeePercentage) / FIXED_POINT_PRECISION;
                fee = totalAmount - amount;

                if (msg.sender != sender) {
                    require(
                        allowance(sender, msg.sender) >= totalAmount, string.concat(name(), ": insufficient allowance")
                    );
                }
                require(balanceOf(sender) >= totalAmount, string.concat(name(), ": insufficient balance"));
            }

            super._transfer(sender, feeReceiver, fee);
        }

        super._transfer(sender, recipient, netTokenTransfer);
    }

    // ======================================
    // =      Adminstrative Functions       =
    // ======================================
    function setdefaultFeeTX(uint256 newFeePercentage) external onlyOwner {
        defaultFeeTX = newFeePercentage;
    }

    function setdefaultFeeTrade(uint256 newFeePercentage) external onlyOwner {
        defaultFeeTrade = newFeePercentage;
    }

    function changeFeeReceiver(address feeReceiverAddress) external {
        require(
            feeReceiverAddress != address(0), string.concat(name(), ": `feeReceiveAddress` cannot be the zero address")
        );
        require(msg.sender == feeReceiver, string.concat(name(), ": function only accesible by `feeReceiver`"));
        feeReceiver = feeReceiverAddress;
    }

    function setSpecialWalletFee(address targetAddress, uint256 txFeePercentage) external onlyOwner {
        require(!_checkIfContract(targetAddress), string.concat(name(), ": not a wallet`"));
        if (txFeePercentage >= 10000) revert PercentageOverflow(minTransferableAmount);

        walletsWithSpecialTreatment[targetAddress] = SpecialWallet(true, txFeePercentage);
    }

    function setSpecialContractFee(address targetAddress, uint256 tradeFeePercentage) external onlyOwner {
        require(_checkIfContract(targetAddress), string.concat(name(), ": not a contract`"));
        if (tradeFeePercentage >= 10000) revert PercentageOverflow(minTransferableAmount);

        SpecialContract memory previousTreatment = contractsWithSpecialTreatment[targetAddress];
        contractsWithSpecialTreatment[targetAddress] =
            SpecialContract(true, previousTreatment.hasSpecialTreatment, tradeFeePercentage, previousTreatment.feePayer);
    }

    function setSpecialContractFeePayer(address targetAddress, TokenSender feePayer) external onlyOwner {
        require(_checkIfContract(targetAddress), string.concat(name(), ": not a contract`"));

        SpecialContract memory previousTreatment = contractsWithSpecialTreatment[targetAddress];
        contractsWithSpecialTreatment[targetAddress] =
            SpecialContract(previousTreatment.hasSpecialFee, true, previousTreatment.specialFeePercentage, feePayer);
    }

    function removeSpecialWalletFee(address targetAddress) external onlyOwner {
        walletsWithSpecialTreatment[targetAddress] = SpecialWallet(false, defaultFeeTX);
    }

    function removeSpecialContractFee(address targetAddress) external onlyOwner {
        SpecialContract memory previousTreatment = contractsWithSpecialTreatment[targetAddress];
        contractsWithSpecialTreatment[targetAddress] =
            SpecialContract(false, previousTreatment.hasSpecialTreatment, defaultFeeTrade, previousTreatment.feePayer);
    }

    function removeSpecialContractFeePayer(address targetAddress) external onlyOwner {
        SpecialContract memory previousTreatment = contractsWithSpecialTreatment[targetAddress];
        contractsWithSpecialTreatment[targetAddress] = SpecialContract(
            previousTreatment.hasSpecialFee, false, previousTreatment.specialFeePercentage, TokenSender.INITIATOR
        );
    }

    // ======================================
    // =           Read Functions           =
    // ======================================
    function checkIfSpecialWallet(address targetAddress) external view returns (SpecialWallet memory) {
        require(!_checkIfContract(targetAddress), string.concat(name(), ": not a wallet`"));
        return (walletsWithSpecialTreatment[targetAddress]);
    }

    function checkIfSpecialContract(address targetAddress) external view returns (SpecialContract memory) {
        require(_checkIfContract(targetAddress), string.concat(name(), ": not a contract`"));
        return (contractsWithSpecialTreatment[targetAddress]);
    }

    function initialize(
        address initialOwner,
        address feeReceiverAddress,
        uint256 _tokenSupply,
        uint256 _defaultFeeTX,
        uint256 _defaultFeeTrade
    ) public virtual initializer {
        __ERC20_init("DT Test", "DTT");
        __ERC20Burnable_init();
        __ERC20Permit_init("DT Test");
        __Ownable_init(initialOwner);

        require(feeReceiverAddress != address(0), string.concat(name(), ": treasuary address can not be 0"));
        if (_defaultFeeTX >= 10000 || _defaultFeeTrade >= 10000) revert PercentageOverflow(minTransferableAmount);

        feeReceiver = feeReceiverAddress;

        defaultFeeTX = _defaultFeeTX;
        defaultFeeTrade = _defaultFeeTrade;

        isFeeEnabledTX = true;
        isFeeEnabledTrade = true;

        _mint(msg.sender, _tokenSupply * 10 ** decimals());
    }
}
