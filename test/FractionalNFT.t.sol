// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "./mocks/MockFractionalNFT.sol";

contract FractionalNFTTest is Test {
    string name = "Vault Token Name";
    string symbol = "VTB";
    string uri = "tokenUri";
    MockFractionalNFT public fractional;

    function setUp() public {
        fractional = new MockFractionalNFT(name, symbol, uri);
    }

    function invariantMetadata() public {
        assertEq(fractional.name(), name);
        assertEq(fractional.symbol(), symbol);
        assertEq(fractional.decimals(), 0);
        assertEq(fractional.uri(0), uri);
    }

    function testMint() public {
        fractional.mint(address(0xBEEF), 1e18);

        assertEq(fractional.totalSupply(), 1e18);
        assertEq(fractional.balanceOf(address(0xBEEF)), 1e18);
    }

    function testBurn() public {
        fractional.mint(address(0xBEEF), 1e18);
        fractional.burn(address(0xBEEF), 0.9e18);

        assertEq(fractional.totalSupply(), 1e18 - 0.9e18);
        assertEq(fractional.balanceOf(address(0xBEEF)), 0.1e18);
    }

    function testApprove() public {
        assertTrue(fractional.approve(address(0xBEEF), 1e18));

        assertEq(fractional.allowance(address(this), address(0xBEEF)), 1e18);
    }

    function testTransfer() public {
        fractional.mint(address(this), 1e18);

        assertTrue(fractional.transfer(address(0xBEEF), 1e18));
        assertEq(fractional.totalSupply(), 1e18);

        assertEq(fractional.balanceOf(address(this)), 0);
        assertEq(fractional.balanceOf(address(0xBEEF)), 1e18);
    }

    function testTransferFrom() public {
        address from = address(0xABCD);

        fractional.mint(from, 1e18);

        vm.prank(from);
        fractional.approve(address(this), 1e18);
        assertEq(fractional.allowance(from, address(this)), 1e18);

        assertTrue(fractional.transferFrom(from, address(0xBEEF), 1e18));
        assertEq(fractional.totalSupply(), 1e18);

        assertEq(fractional.allowance(from, address(this)), 0);

        assertEq(fractional.balanceOf(from), 0);
        assertEq(fractional.balanceOf(address(0xBEEF)), 1e18);
    }

    function testInfiniteApproveTransferFrom() public {
        address from = address(0xABCD);

        fractional.mint(from, 1e18);

        vm.prank(from);
        fractional.approve(address(this), type(uint256).max);

        assertTrue(fractional.transferFrom(from, address(0xBEEF), 1e18));
        assertEq(fractional.totalSupply(), 1e18);

        assertEq(fractional.allowance(from, address(this)), type(uint256).max);

        assertEq(fractional.balanceOf(from), 0);
        assertEq(fractional.balanceOf(address(0xBEEF)), 1e18);
    }

    function testFailTransferInsufficientBalance() public {
        fractional.mint(address(this), 0.9e18);
        fractional.transfer(address(0xBEEF), 1e18);
    }

    function testFailTransferFromInsufficientAllowance() public {
        address from = address(0xABCD);

        fractional.mint(from, 1e18);

        vm.prank(from);
        fractional.approve(address(this), 0.9e18);

        fractional.transferFrom(from, address(0xBEEF), 1e18);
    }
    
    function testFailTransferFromInsufficientBalance() public {
        address from = address(0xABCD);

        fractional.mint(from, 0.9e18);

        vm.prank(from);
        fractional.approve(address(this), 1e18);

        fractional.transferFrom(from, address(0xBEEF), 1e18);
    }
}