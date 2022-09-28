// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "src/TokenVault.sol";
import "src/FERC721.sol";

import "forge-std/console.sol";

contract TokenVaultTest is Test {
    address owner;
    address ZERO_ADDRESS = address(0);
    address curator = address(1);
    address user = address(2);
    uint fee = 0;
    uint tokenId = 1;
    uint supply = 1000;
    uint price = 0.1 ether;

    string name = "TokenName";
    string symbol = "TNS";

    FERC721 public collection;
    TokenVault public tokenVault;

    event Fractionalized(address indexed collection, address indexed token);
    event Redeemed(address indexed sender, address indexed collection, uint indexed tokenId);
    event BoughtOut(address indexed sender, address collection, uint indexed tokenId);

    function setUp() public {
        owner = address(this);
        collection = new FERC721(name, symbol);
        tokenVault = new TokenVault(curator, fee, name, symbol);
    }

    function testInitialState() public {
        assertEq(tokenVault.name(), name);
        assertEq(tokenVault.symbol(), symbol);
        assertEq(tokenVault.decimals(), 0);
        assertEq(tokenVault.curator(), curator);
        assertEq(tokenVault.fee(), fee);
    }

    function testFractionalizedWorksAsOwner() public {
        vm.prank(owner);
        collection.mintTo(address(tokenVault));
        assertEq(collection.balanceOf(address(tokenVault)), 1);
        tokenVault.fractionalize(address(tokenVault), address(collection), tokenId, supply);
        assertEq(tokenVault.totalSupply(), supply);
        assertEq(tokenVault.balanceOf(address(curator)), supply);
    }

    function testFractionalizedFailsAsNotOwner() public {
        vm.prank(owner);
        collection.mintTo(address(tokenVault));
        assertEq(collection.balanceOf(address(tokenVault)), 1);
        vm.prank(user);
        vm.expectRevert("Ownable: caller is not the owner");
        tokenVault.fractionalize(address(tokenVault), address(collection), tokenId, supply);
        assertEq(tokenVault.totalSupply(), 0);
        assertEq(tokenVault.balanceOf(address(curator)), 0);
    }

    function testConfigureSaleWorksAsOwner() public {
        vm.prank(owner);
        collection.mintTo(address(tokenVault));
        assertEq(collection.balanceOf(address(tokenVault)), 1);
        tokenVault.fractionalize(address(tokenVault), address(collection), tokenId, supply);
        assertEq(tokenVault.totalSupply(), supply);
        assertEq(tokenVault.balanceOf(address(curator)), supply);
        uint start = block.timestamp + 1;
        tokenVault.configureSale(start, 0, price);
        assertEq(tokenVault.start(), start);
        assertEq(tokenVault.end(), 0);
        assertEq(tokenVault.listPrice(), price);
    }

    function testConfigureSaleFailsAsNotOwner() public {
        vm.prank(owner);
        collection.mintTo(address(tokenVault));
        assertEq(collection.balanceOf(address(tokenVault)), 1);
        tokenVault.fractionalize(address(tokenVault), address(collection), tokenId, supply);
        assertEq(tokenVault.totalSupply(), supply);
        assertEq(tokenVault.balanceOf(address(curator)), supply);
        uint start = block.timestamp + 1;
        vm.prank(user);
        vm.expectRevert("Ownable: caller is not the owner");
        tokenVault.configureSale(start, 0, price);
        assertEq(tokenVault.start(), 0);
        assertEq(tokenVault.end(), 0);
        assertEq(tokenVault.listPrice(), 0);
    }

    function testPurchaseWorks() public {
        vm.prank(owner);
        collection.mintTo(address(tokenVault));
        assertEq(collection.balanceOf(address(tokenVault)), 1);
        vm.expectEmit(true, true, false, true);
        emit Fractionalized(address(collection), address(tokenVault));
        tokenVault.fractionalize(address(tokenVault), address(collection), tokenId, supply);
        assertEq(tokenVault.totalSupply(), supply);
        assertEq(tokenVault.balanceOf(address(curator)), supply);
        uint start = block.timestamp + 1;
        tokenVault.configureSale(start, 0, price);
        assertEq(tokenVault.start(), start);
        assertEq(tokenVault.end(), 0);
        assertEq(tokenVault.listPrice(), price);

        vm.prank(curator);
        tokenVault.transfer(address(tokenVault), supply);

        vm.warp(start + 5);
        uint8 amount = 10;
        hoax(user, 10 ether);
        vm.expectCall(
            address(tokenVault), abi.encodeCall(tokenVault.purchase, (amount))
        );
        tokenVault.purchase{value: 1000000000000000000}(amount);
        assertEq(tokenVault.balanceOf(address(user)), amount);
        assertEq(tokenVault.balanceOf(address(tokenVault)), supply - amount);
    }

    function testPurchaseFailsAsNotEnoughEtherSent() public {
        vm.prank(owner);
        collection.mintTo(address(tokenVault));
        assertEq(collection.balanceOf(address(tokenVault)), 1);
        tokenVault.fractionalize(address(tokenVault), address(collection), tokenId, supply);
        assertEq(tokenVault.totalSupply(), supply);
        assertEq(tokenVault.balanceOf(address(curator)), supply);
        uint start = block.timestamp + 1;
        tokenVault.configureSale(start, 0, price);
        assertEq(tokenVault.start(), start);
        assertEq(tokenVault.end(), 0);
        assertEq(tokenVault.listPrice(), price);

        vm.prank(curator);
        tokenVault.transfer(address(tokenVault), supply);

        vm.warp(start + 5);
        uint8 amount = 10;
        hoax(user, 10 ether);
        vm.expectCall(
            address(tokenVault), abi.encodeCall(tokenVault.purchase, (amount))
        );

        vm.expectRevert("Not enough ether sent");
        tokenVault.purchase{value: 999999999999999999}(amount);
        assertEq(tokenVault.balanceOf(address(user)), 0);
        assertEq(tokenVault.balanceOf(address(tokenVault)), supply);
    }

    function testPurchaseFailsAsSaleIsNotStarted() public {
        vm.prank(owner);
        collection.mintTo(address(tokenVault));
        assertEq(collection.balanceOf(address(tokenVault)), 1);
        tokenVault.fractionalize(address(tokenVault), address(collection), tokenId, supply);
        assertEq(tokenVault.totalSupply(), supply);
        assertEq(tokenVault.balanceOf(address(curator)), supply);
        uint start = block.timestamp + 1;
        tokenVault.configureSale(start, 0, price);
        assertEq(tokenVault.start(), start);
        assertEq(tokenVault.end(), 0);
        assertEq(tokenVault.listPrice(), price);

        vm.prank(curator);
        tokenVault.transfer(address(tokenVault), supply);

        // vm.warp(start + 5);
        uint8 amount = 10;
        hoax(user, 10 ether);
        vm.expectCall(
            address(tokenVault), abi.encodeCall(tokenVault.purchase, (amount))
        );

        vm.expectRevert("The primary sale is not started");
        tokenVault.purchase{value: 1000000000000000000}(amount);
        assertEq(tokenVault.balanceOf(address(user)), 0);
        assertEq(tokenVault.balanceOf(address(tokenVault)), supply);
    }

    function testPurchaseFailsAsExceedsTotalSupply() public {
        supply = 100;
        vm.prank(owner);
        collection.mintTo(address(tokenVault));
        assertEq(collection.balanceOf(address(tokenVault)), 1);
        tokenVault.fractionalize(address(tokenVault), address(collection), tokenId, supply);
        assertEq(tokenVault.totalSupply(), supply);
        assertEq(tokenVault.balanceOf(address(curator)), supply);
        uint start = block.timestamp + 1;
        tokenVault.configureSale(start, 0, price);
        assertEq(tokenVault.start(), start);
        assertEq(tokenVault.end(), 0);
        assertEq(tokenVault.listPrice(), price);

        vm.prank(curator);
        tokenVault.transfer(address(tokenVault), supply);

        vm.warp(start + 5);
        uint8 amount = 101;
        hoax(user, 10.1 ether);
        vm.expectCall(
            address(tokenVault), abi.encodeCall(tokenVault.purchase, (amount))
        );

        vm.expectRevert("Exceeds the total supply");
        tokenVault.purchase{value: 10100000000000000000}(amount);
        assertEq(tokenVault.balanceOf(address(user)), 0);
        assertEq(tokenVault.balanceOf(address(tokenVault)), supply);
    }

    function testRedeemWorks() public {
        supply = 100;
        vm.prank(owner);
        collection.mintTo(address(tokenVault));
        assertEq(collection.balanceOf(address(tokenVault)), 1);
        vm.expectEmit(true, true, false, true);
        emit Fractionalized(address(collection), address(tokenVault));
        tokenVault.fractionalize(address(tokenVault), address(collection), tokenId, supply);
        assertEq(tokenVault.totalSupply(), supply);
        assertEq(tokenVault.balanceOf(address(curator)), supply);
        uint start = block.timestamp + 1;
        tokenVault.configureSale(start, 0, price);
        assertEq(tokenVault.start(), start);
        assertEq(tokenVault.end(), 0);
        assertEq(tokenVault.listPrice(), price);

        vm.prank(curator);
        tokenVault.transfer(address(tokenVault), supply);

        vm.warp(start + 5);
        uint8 amount = 100;
        hoax(user, 10 ether);
        vm.expectCall(
            address(tokenVault), abi.encodeCall(tokenVault.purchase, (amount))
        );
        tokenVault.purchase{value: 10000000000000000000}(amount);
        assertEq(tokenVault.balanceOf(address(user)), amount);
        assertEq(tokenVault.balanceOf(address(user)), tokenVault.totalSupply());
        assertEq(tokenVault.balanceOf(address(tokenVault)), 0);

        vm.startPrank(user);
        tokenVault.approve(address(this), amount);
        // vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit Redeemed(address(user), address(collection), tokenId);
        tokenVault.redeem();
        assertEq(collection.balanceOf(address(user)), 1);
        assertEq(tokenVault.balanceOf(address(user)), 0);
        assertEq(tokenVault.totalSupply(), 0);
    }

    function testBuyoutWorks() public {
        supply = 100;
        vm.prank(owner);
        collection.mintTo(address(tokenVault));
        tokenVault.fractionalize(address(tokenVault), address(collection), tokenId, supply);
        uint start = block.timestamp + 1;
        tokenVault.configureSale(start, 0, price);

        vm.prank(curator);
        tokenVault.transfer(address(tokenVault), supply);

        vm.warp(start + 5);
        hoax(user, 10 ether);
        vm.expectEmit(true, true, true, true);
        emit BoughtOut(address(user), address(collection), tokenId);
        tokenVault.buyout{value: 10 ether}();
        assertEq(collection.balanceOf(address(user)), 1);
        assertEq(address(tokenVault).balance, 10 ether);
    }

    function testBuyoutFails() public {
        supply = 100;
        vm.prank(owner);
        collection.mintTo(address(tokenVault));
        tokenVault.fractionalize(address(tokenVault), address(collection), tokenId, supply);
        uint start = block.timestamp + 1;
        tokenVault.configureSale(start, 0, price);

        vm.prank(curator);
        tokenVault.transfer(address(tokenVault), supply);

        vm.warp(start + 5);
        hoax(user, 10 ether);
        vm.expectRevert("Sender sent less than the buyout price");
        tokenVault.buyout{value: 9 ether}();
        assertEq(collection.balanceOf(address(user)), 0);
        assertEq(address(tokenVault).balance, 0);
    }
}