// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "src/TokenVault.sol";
import "src/NFTCollection.sol";
import "src/VaultFactory.sol";

import "test/mocks/MockFractionalNFT.sol";
import "src/FractionalNFT.sol";

import "forge-std/console.sol";

contract VaultFactoryTest is Test {

    VaultFactory factory;
    TokenVault tokenVault;
    NFTCollection collection;

    uint256 fee = 0;
    uint256 tokenId = 1;
    uint256 supply = 1000;
    uint256 price = 0.1 ether;

    string name = "TokenName";
    string symbol = "TNS";
    string tokenUri = "tokenURI";

    address curator = address(11);

    function setUp() public {
        collection = new NFTCollection();
        factory = new VaultFactory();
    }

    function mintNft() public {
        collection.mint(
            address(curator),
            tokenUri,
            address(curator),
            250
        );
        assertEq(collection.balanceOf(address(curator)), 1);
    }

    function testCreateTokenVault() public {
        mintNft();
        assertEq(collection.ownerOf(tokenId), address(curator));
        vm.startPrank(curator);
        collection.approve(address(factory), tokenId);
        
        uint start = block.timestamp + 1;
        uint end = 0;
        
        address vault = VaultFactory(factory).createVault(
            address(collection),
            tokenId,
            supply,
            fee,
            name,
            symbol,
            tokenUri,
            start,
            end,
            price
        );

        assertEq(factory.vaultCount(), 1);
        assertEq(factory.vaults(1), address(vault));

        assertEq(TokenVault(vault).curator(), address(curator));
        assertEq(TokenVault(vault).name(), name);
        assertEq(TokenVault(vault).symbol(), symbol);
        assertEq(TokenVault(vault).uri(0), tokenUri);
        assertEq(TokenVault(vault).totalSupply(), supply);
        assertEq(TokenVault(vault).balanceOf(address(curator)), supply);
    }

}