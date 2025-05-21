// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Ampli} from "src/Ampli.sol";
import {Agent} from "src/Agent.sol";
import {Broker} from "src/Broker.sol";
import {PegTokenFactory} from "src/PegTokenFactory.sol";
import {IPegTokenFactory} from "src/interfaces/IPegTokenFactory.sol";

contract DeployAgentAndBrokerScript is Script {
    address ampli = address(0x00d07f8F1add9948c538D8FfC78B4B61Becf0AC0);

    function run() public returns (Agent agent, Broker broker) {
        address brokerDeployer = vm.envAddress("BROKER_ADDRESS");
        address brokerAddr = vm.computeCreateAddress(brokerDeployer, 0);

        vm.createSelectFork("SpokeChain");
        vm.startBroadcast(vm.envUint("WALLET_PRIVATE_KEY"));
        payable(vm.envAddress("AGENT_ADDRESS")).transfer(1 ether);
        vm.stopBroadcast();

        vm.startBroadcast(vm.envUint("AGENT_PRIVATE_KEY"));
        agent = new Agent(902, brokerAddr);
        vm.stopBroadcast();

        vm.createSelectFork("HubChain");
        vm.startBroadcast(vm.envUint("WALLET_PRIVATE_KEY"));
        payable(vm.envAddress("BROKER_ADDRESS")).transfer(1 ether);
        vm.stopBroadcast();

        vm.startBroadcast(vm.envUint("BROKER_PRIVATE_KEY"));
        broker = new Broker(address(agent), ampli);
        vm.stopBroadcast();

        assert(address(broker) == brokerAddr);
    }
}

contract DeployPegToken is Script {
    bytes32 constant salt = hex"00";

    function run() public returns (PegTokenFactory factory) {
        vm.createSelectFork("HubChain");
        vm.startBroadcast(vm.envUint("BROKER_PRIVATE_KEY"));
        factory = new PegTokenFactory{salt: salt}();
        vm.stopBroadcast();
    }
}

contract DeployHook is Script {
    // Ampli public ampli;
    IPoolManager constant PM_ADDRESS = IPoolManager(0x498581fF718922c3f8e6A244956aF099B2652b2b);
    bytes32 constant salt = 0x9176f517f8281c294b888eb7945af36819bafc42a977bb51437d05f7175dda55;
    address constant factory = address(0x9954EF92D8ac2b3c5E86B56AaAa291F09A592320);

    function run() public returns (Ampli ampli) {
        // vm.createSelectFork("HubChain");
        address brokerDeployer = vm.envAddress("BROKER_ADDRESS");
        address broker = vm.computeCreateAddress(brokerDeployer, 0);

        vm.startBroadcast(vm.envUint("BROKER_PRIVATE_KEY"));
        ampli = new Ampli{salt: salt}(PM_ADDRESS, IPegTokenFactory(factory), broker);
        vm.stopBroadcast();
        
        assert(address(ampli) == address(0x00d91b371d01d40cFdec3c071f02e92aDE5b4aC0));
    }
}
