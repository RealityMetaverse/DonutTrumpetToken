// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {DonutTrumpet} from "src/DonutTrumpet.sol";

contract DonutTrumpetScript is Script {
    function setUp() public {}

    function run() public {
        // TODO: Set addresses for the variables below, then uncomment the following section:

        vm.startBroadcast();
        address initialOwner = 0x77AE0e97d8073AD7b529D5B67f389a2Ed6Cdf14f;
        address _feeReceiver = 0x77AE0e97d8073AD7b529D5B67f389a2Ed6Cdf14f;

        uint256 _tokenSupply = 1000000000;
        uint256 _defaultFeeTX = 300;
        uint256 _defaultFeeTrade = 10;

        address proxy = Upgrades.deployTransparentProxy(
            "DonutTrumpet.sol",
            initialOwner,
            abi.encodeCall(
                DonutTrumpet.initialize, (initialOwner, _feeReceiver, _tokenSupply, _defaultFeeTX, _defaultFeeTrade)
            )
        );
        DonutTrumpet instance = DonutTrumpet(proxy);
        console.log("Proxy deployed to %s", address(instance));
        vm.stopBroadcast();
    }
}
