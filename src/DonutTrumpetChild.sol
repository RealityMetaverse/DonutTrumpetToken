// SPDX-License-Identifier: BUSL-1.1
// Reality NFT Contracts

pragma solidity 0.8.20;

import "./DonutTrumpet.sol";

/**
* @title Donut Trumpet Token for child chain
* @dev Child chain refers to Polygon
*/
contract DonutTrumpetChild is DonutTrumpet {
    address public childChainManager;

    function setChildChainManager(address childChainManagerAddress) external onlyOwner {
        require(childChainManagerAddress != address(0), string.concat(name(), ": manager address can not be 0"));
        childChainManager = childChainManagerAddress;
    }

    modifier onlyChildChainManager() {
        require(msg.sender == childChainManager, string.concat(name(), ": only `childChainManager` can call this function"));
        _;
    }

    /**
     * @notice called when token is deposited on root chain
     * Should handle deposit by minting the required amount for user
     * @param user user address for whom deposit is being done
     * @param depositData abi encoded amount
     */
    function deposit(address user, bytes calldata depositData) external onlyChildChainManager {
        uint256 amount = abi.decode(depositData, (uint256));

        _mint(user, amount);
    }

    /**
     * @notice called when user wants to withdraw tokens back to root chain
     * @dev Should burn user's tokens. This transaction will be verified when exiting on root chain
     * @param amount amount of tokens to withdraw
     */
    function withdraw(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    function initialize(address initialOwner, address feeReceiverAddress, uint256 _tokenSupply, uint256 _defaultFeeTX, uint256 _defaultFeeTrade) initializer public override {
        childChainManager = initialOwner;
        super.initialize(initialOwner, feeReceiverAddress, _tokenSupply, _defaultFeeTX, _defaultFeeTrade);
    }
}
