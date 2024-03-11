// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {EarthMindNFT} from "@contracts/v1/EarthMindNFT.sol";
import {DeploymentUtils} from "@utils/DeploymentUtils.sol";
import {DeployerUtils} from "@utils/DeployerUtils.sol";

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Vm} from "forge-std/Vm.sol";

contract EarthMindDeployScript is Script {
    using DeployerUtils for Vm;
    using DeploymentUtils for Vm;

    address internal deployer;

    function run() public {
        console2.log("Deploying EarthMindNFT contract");
        deployer = vm.loadDeployerAddress();

        console2.log("Deployer Address");
        console2.logAddress(deployer);

        vm.startBroadcast(deployer);

        EarthMindNFT earthMindNFT = new EarthMindNFT();
        console2.log("EarthMindNFT Address");
        console2.logAddress(address(earthMindNFT));

        vm.saveDeploymentAddress("EarthMindNFT", address(earthMindNFT));
    }
}
