// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "src/NFTCollection.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";

contract NFTCollectionTest is Test, ERC721Holder {
    address owner;
    address ZERO_ADDRESS = address(0);
    address user = address(1);

    string name = "TokenName";
    string symbol = "TNS";
    string tokenUri = "tokenURI";

    NFTCollection public collection;

    function setUp() public {
        owner = address(this);
        collection = new NFTCollection();
    }

    function testMintWorks() public {
        vm.prank(owner);
        collection.mint(address(owner), tokenUri, address(owner), 250);
        uint256 userBalance = collection.balanceOf(owner);
        assertEq(userBalance, 1);
    }
}
