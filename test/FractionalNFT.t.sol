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

   function testMetadata(
        string calldata name,
        string calldata symbol,
        string calldata uri
    ) public {
        MockFractionalNFT fractional = new MockFractionalNFT(name, symbol, uri);
        assertEq(fractional.name(), name);
        assertEq(fractional.symbol(), symbol);
        assertEq(fractional.uri(0), uri);
    }

    function testMint(address from, uint256 amount) public {
        fractional.mint(from, amount);

        assertEq(fractional.totalSupply(), amount);
        assertEq(fractional.balanceOf(from), amount);
    }

    function testBurn(
        address from,
        uint256 mintAmount,
        uint256 burnAmount
    ) public {
        burnAmount = bound(burnAmount, 0, mintAmount);

        fractional.mint(from, mintAmount);
        fractional.burn(from, burnAmount);

        assertEq(fractional.totalSupply(), mintAmount - burnAmount);
        assertEq(fractional.balanceOf(from), mintAmount - burnAmount);
    }

    function testApprove(address to, uint256 amount) public {
        assertTrue(fractional.approve(to, amount));

        assertEq(fractional.allowance(address(this), to), amount);
    }

    function testTransfer(address from, uint256 amount) public {
        vm.assume(address(from) != address(0));
        fractional.mint(address(this), amount);

        assertTrue(fractional.transfer(from, amount));
        assertEq(fractional.totalSupply(), amount);

        if (address(this) == from) {
            assertEq(fractional.balanceOf(address(this)), amount);
            assertEq(fractional.balanceOf(address(this), 0), amount);
        } else {
            assertEq(fractional.balanceOf(address(this)), 0);
            assertEq(fractional.balanceOf(address(this), 0), 0);
            assertEq(fractional.balanceOf(from), amount);
            assertEq(fractional.balanceOf(from, 0), amount);
        }
    }

    function testTransferFrom(
        address to,
        uint256 approval,
        uint256 amount
    ) public {
        vm.assume(address(to) != address(0));
        amount = bound(amount, 0, approval);

        address from = address(0xABCD);

        fractional.mint(from, amount);

        vm.prank(from);
        fractional.approve(address(this), approval);

        assertTrue(fractional.transferFrom(from, to, amount));
        assertEq(fractional.totalSupply(), amount);

        uint256 app = from == address(this) || approval == type(uint256).max ? approval : approval - amount;
        assertEq(fractional.allowance(from, address(this)), app);

        if (from == to) {
            assertEq(fractional.balanceOf(from), amount);
            assertEq(fractional.balanceOf(from, 0), amount);
        } else {
            assertEq(fractional.balanceOf(from), 0);
            assertEq(fractional.balanceOf(from, 0), 0);
            assertEq(fractional.balanceOf(to), amount);
            assertEq(fractional.balanceOf(to, 0), amount);
        }
    }

    function testFailBurnInsufficientBalance(
        address to,
        uint256 mintAmount,
        uint256 burnAmount
    ) public {
        burnAmount = bound(burnAmount, mintAmount + 1, type(uint256).max);

        fractional.mint(to, mintAmount);
        fractional.burn(to, burnAmount);
    }

    function testFailTransferInsufficientBalance(
        address to,
        uint256 mintAmount,
        uint256 sendAmount
    ) public {
        sendAmount = bound(sendAmount, mintAmount + 1, type(uint256).max);

        fractional.mint(address(this), mintAmount);
        fractional.transfer(to, sendAmount);
    }

    function testFailTransferFromInsufficientAllowance(
        address to,
        uint256 approval,
        uint256 amount
    ) public {
        amount = bound(amount, approval + 1, type(uint256).max);

        address from = address(0xABCD);

        fractional.mint(from, amount);

        vm.prank(from);
        fractional.approve(address(this), approval);

        fractional.transferFrom(from, to, amount);
    }

    function testFailTransferFromInsufficientBalance(
        address to,
        uint256 mintAmount,
        uint256 sendAmount
    ) public {
        sendAmount = bound(sendAmount, mintAmount + 1, type(uint256).max);

        address from = address(0xABCD);

        fractional.mint(from, mintAmount);

        vm.prank(from);
        fractional.approve(address(this), sendAmount);

        fractional.transferFrom(from, to, sendAmount);
    }
}