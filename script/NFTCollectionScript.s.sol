// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Script.sol";
import "src/NFTCollection.sol";

contract NFTCollectionScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        NFTCollection nft = new NFTCollection();

        vm.stopBroadcast();
    }
}
