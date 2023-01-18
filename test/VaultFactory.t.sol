// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "src/TokenVault.sol";
import "src/NFTCollection.sol";
import "src/VaultFactory.sol";

// import "test/mocks/MockFractionalNFT.sol";
// import "src/FractionalNFT.sol";

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
    address user = address(12);

    function setUp() public {
        collection = new NFTCollection();
        factory = new VaultFactory();
    }

    function mintNft(address to) public {
        collection.mint(address(to), tokenUri, address(to), 250);
        assertEq(collection.balanceOf(address(curator)), 1);
    }

    function testCreateTokenVault() public {
        mintNft(address(curator));
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
        vm.stopPrank();

        assertEq(factory.vaultCount(), 1);
        assertEq(factory.vaults(1), address(vault));

        assertEq(TokenVault(vault).curator(), address(curator));
        assertEq(TokenVault(vault).name(), name);
        assertEq(TokenVault(vault).symbol(), symbol);
        assertEq(TokenVault(vault).uri(0), tokenUri);
        assertEq(TokenVault(vault).totalSupply(), supply);
        assertEq(TokenVault(vault).balanceOf(address(curator)), supply);
    }

    function testCreateSeveralTokenVaults() public {
        testCreateTokenVault();

        uint tokenId2 = 2;

        collection.mint(address(user), tokenUri, address(user), 250);

        assertEq(collection.ownerOf(tokenId2), address(user));
        vm.startPrank(user);
        collection.approve(address(factory), tokenId2);
        
        uint start = block.timestamp + 1;
        uint end = 0;
        
        address vault = VaultFactory(factory).createVault(
            address(collection),
            tokenId2,
            supply,
            fee,
            name,
            symbol,
            tokenUri,
            start,
            end,
            price
        );
        vm.stopPrank();

        assertEq(factory.vaultCount(), 2);
        assertEq(factory.vaults(2), address(vault));

        assertEq(collection.balanceOf(address(vault)), 1);
        assertEq(collection.ownerOf(tokenId2), address(vault));

        assertEq(TokenVault(vault).curator(), address(user));
        assertEq(TokenVault(vault).name(), name);
        assertEq(TokenVault(vault).symbol(), symbol);
        assertEq(TokenVault(vault).uri(0), tokenUri);
        assertEq(TokenVault(vault).totalSupply(), supply);
        assertEq(TokenVault(vault).balanceOf(address(user)), supply);

        assertEq(TokenVault(vault).start(), start);
        assertEq(TokenVault(vault).end(), end);
        assertEq(TokenVault(vault).listPrice(), price);
    }

    function testUnableCreateVaultIfPaused() public {
        factory.pause();

        mintNft(address(curator));
        vm.startPrank(curator);
        collection.approve(address(factory), tokenId);

        uint start = block.timestamp + 1;
        uint end = 0;

        vm.expectRevert("Pausable: paused");
        VaultFactory(factory).createVault(
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
        vm.stopPrank();
    }

    function testUnableUnpausedNotOwner() public {
        testUnableCreateVaultIfPaused();
        vm.startPrank(curator);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.unpause();
        vm.stopPrank();
    }
}