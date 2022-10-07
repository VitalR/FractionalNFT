// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "src/TokenVault.sol";
import "src/NFTCollection.sol";

contract TokenVaultTest is Test {
    address owner;
    address ZERO_ADDRESS = address(0);
    address curator = address(1);
    address user = address(2);
    uint256 fee = 0;
    uint256 tokenId = 1;
    uint256 supply = 1000;
    uint256 price = 0.1 ether;

    string name = "TokenName";
    string symbol = "TNS";
    string tokenUri = "tokenURI";

    NFTCollection public collection;
    TokenVault public tokenVault;

    event Fractionalized(address indexed collection, address indexed token);
    event Redeemed(
        address indexed sender,
        address indexed collection,
        uint256 indexed tokenId
    );
    event BoughtOut(
        address indexed sender,
        address collection,
        uint256 indexed tokenId
    );
    event Claimed(address indexed sender, uint256 indexed amount);

    function setUp() public {
        owner = address(this);
        collection = new NFTCollection();
        tokenVault = new TokenVault(curator, fee, name, symbol, tokenUri);
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
        collection.mint(
            address(tokenVault),
            tokenUri,
            address(tokenVault),
            250
        );
        assertEq(collection.balanceOf(address(tokenVault)), 1);
        tokenVault.fractionalize(
            address(tokenVault),
            address(collection),
            tokenId,
            supply
        );
        assertEq(tokenVault.totalSupply(), supply);
        assertEq(tokenVault.balanceOf(address(curator)), supply);
    }

    function testFractionalizedFailsAsNotOwner() public {
        vm.prank(owner);
        collection.mint(
            address(tokenVault),
            tokenUri,
            address(tokenVault),
            250
        );
        assertEq(collection.balanceOf(address(tokenVault)), 1);
        vm.prank(user);
        vm.expectRevert("Ownable: caller is not the owner");
        tokenVault.fractionalize(
            address(tokenVault),
            address(collection),
            tokenId,
            supply
        );
        assertEq(tokenVault.totalSupply(), 0);
        assertEq(tokenVault.balanceOf(address(curator)), 0);
    }

    function testConfigureSaleWorksAsOwner() public {
        vm.prank(owner);
        collection.mint(
            address(tokenVault),
            tokenUri,
            address(tokenVault),
            250
        );
        assertEq(collection.balanceOf(address(tokenVault)), 1);
        tokenVault.fractionalize(
            address(tokenVault),
            address(collection),
            tokenId,
            supply
        );
        assertEq(tokenVault.totalSupply(), supply);
        assertEq(tokenVault.balanceOf(address(curator)), supply);
        uint256 start = block.timestamp + 1;
        tokenVault.configureSale(start, 0, price);
        assertEq(tokenVault.start(), start);
        assertEq(tokenVault.end(), 0);
        assertEq(tokenVault.listPrice(), price);
    }

    function testConfigureSaleFailsAsNotOwner() public {
        vm.prank(owner);
        collection.mint(
            address(tokenVault),
            tokenUri,
            address(tokenVault),
            250
        );
        assertEq(collection.balanceOf(address(tokenVault)), 1);
        tokenVault.fractionalize(
            address(tokenVault),
            address(collection),
            tokenId,
            supply
        );
        assertEq(tokenVault.totalSupply(), supply);
        assertEq(tokenVault.balanceOf(address(curator)), supply);
        uint256 start = block.timestamp + 1;
        vm.prank(user);
        vm.expectRevert("Ownable: caller is not the owner");
        tokenVault.configureSale(start, 0, price);
        assertEq(tokenVault.start(), 0);
        assertEq(tokenVault.end(), 0);
        assertEq(tokenVault.listPrice(), 0);
    }

    function testPurchaseWorks() public {
        vm.prank(owner);
        collection.mint(
            address(tokenVault),
            tokenUri,
            address(tokenVault),
            250
        );
        assertEq(collection.balanceOf(address(tokenVault)), 1);
        vm.expectEmit(true, true, false, true);
        emit Fractionalized(address(collection), address(tokenVault));
        tokenVault.fractionalize(
            address(tokenVault),
            address(collection),
            tokenId,
            supply
        );
        assertEq(tokenVault.totalSupply(), supply);
        assertEq(tokenVault.balanceOf(address(curator)), supply);
        uint256 start = block.timestamp + 1;
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
            address(tokenVault),
            abi.encodeCall(tokenVault.purchase, (amount))
        );
        tokenVault.purchase{value: 1000000000000000000}(amount);
        assertEq(tokenVault.balanceOf(address(user)), amount);
        assertEq(tokenVault.balanceOf(address(tokenVault)), supply - amount);
    }

    function testPurchaseFailsAsNotEnoughEtherSent() public {
        vm.prank(owner);
        collection.mint(
            address(tokenVault),
            tokenUri,
            address(tokenVault),
            250
        );
        assertEq(collection.balanceOf(address(tokenVault)), 1);
        tokenVault.fractionalize(
            address(tokenVault),
            address(collection),
            tokenId,
            supply
        );
        assertEq(tokenVault.totalSupply(), supply);
        assertEq(tokenVault.balanceOf(address(curator)), supply);
        uint256 start = block.timestamp + 1;
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
            address(tokenVault),
            abi.encodeCall(tokenVault.purchase, (amount))
        );

        vm.expectRevert("Not enough ether sent");
        tokenVault.purchase{value: 999999999999999999}(amount);
        assertEq(tokenVault.balanceOf(address(user)), 0);
        assertEq(tokenVault.balanceOf(address(tokenVault)), supply);
    }

    function testPurchaseFailsAsSaleIsNotStarted() public {
        vm.prank(owner);
        collection.mint(
            address(tokenVault),
            tokenUri,
            address(tokenVault),
            250
        );
        assertEq(collection.balanceOf(address(tokenVault)), 1);
        tokenVault.fractionalize(
            address(tokenVault),
            address(collection),
            tokenId,
            supply
        );
        assertEq(tokenVault.totalSupply(), supply);
        assertEq(tokenVault.balanceOf(address(curator)), supply);
        uint256 start = block.timestamp + 1;
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
            address(tokenVault),
            abi.encodeCall(tokenVault.purchase, (amount))
        );

        vm.expectRevert("The primary sale is not started");
        tokenVault.purchase{value: 1000000000000000000}(amount);
        assertEq(tokenVault.balanceOf(address(user)), 0);
        assertEq(tokenVault.balanceOf(address(tokenVault)), supply);
    }

    function testPurchaseFailsAsExceedsTotalSupply() public {
        supply = 100;
        vm.prank(owner);
        collection.mint(
            address(tokenVault),
            tokenUri,
            address(tokenVault),
            250
        );
        assertEq(collection.balanceOf(address(tokenVault)), 1);
        tokenVault.fractionalize(
            address(tokenVault),
            address(collection),
            tokenId,
            supply
        );
        assertEq(tokenVault.totalSupply(), supply);
        assertEq(tokenVault.balanceOf(address(curator)), supply);
        uint256 start = block.timestamp + 1;
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
            address(tokenVault),
            abi.encodeCall(tokenVault.purchase, (amount))
        );

        vm.expectRevert("Exceeds the total supply");
        tokenVault.purchase{value: 10100000000000000000}(amount);
        assertEq(tokenVault.balanceOf(address(user)), 0);
        assertEq(tokenVault.balanceOf(address(tokenVault)), supply);
    }

    function testRedeemWorks() public {
        supply = 100;
        vm.prank(owner);
        collection.mint(
            address(tokenVault),
            tokenUri,
            address(tokenVault),
            250
        );
        assertEq(collection.balanceOf(address(tokenVault)), 1);
        vm.expectEmit(true, true, false, true);
        emit Fractionalized(address(collection), address(tokenVault));
        tokenVault.fractionalize(
            address(tokenVault),
            address(collection),
            tokenId,
            supply
        );
        assertEq(tokenVault.totalSupply(), supply);
        assertEq(tokenVault.balanceOf(address(curator)), supply);
        uint256 start = block.timestamp + 1;
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
            address(tokenVault),
            abi.encodeCall(tokenVault.purchase, (amount))
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
        collection.mint(
            address(tokenVault),
            tokenUri,
            address(tokenVault),
            250
        );
        tokenVault.fractionalize(
            address(tokenVault),
            address(collection),
            tokenId,
            supply
        );
        uint256 start = block.timestamp + 1;
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
        collection.mint(
            address(tokenVault),
            tokenUri,
            address(tokenVault),
            250
        );
        tokenVault.fractionalize(
            address(tokenVault),
            address(collection),
            tokenId,
            supply
        );
        uint256 start = block.timestamp + 1;
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

    function testClaimWorks() public {
        vm.prank(owner);
        collection.mint(
            address(tokenVault),
            tokenUri,
            address(tokenVault),
            250
        );
        assertEq(collection.balanceOf(address(tokenVault)), 1);
        vm.expectEmit(true, true, false, true);
        emit Fractionalized(address(collection), address(tokenVault));
        tokenVault.fractionalize(
            address(tokenVault),
            address(collection),
            tokenId,
            supply
        );
        assertEq(tokenVault.totalSupply(), supply);
        assertEq(tokenVault.balanceOf(address(curator)), supply);
        uint256 start = block.timestamp + 1;
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
            address(tokenVault),
            abi.encodeCall(tokenVault.purchase, (amount))
        );
        tokenVault.purchase{value: 1 ether}(amount);
        assertEq(tokenVault.balanceOf(address(user)), amount);
        assertEq(tokenVault.balanceOf(address(tokenVault)), supply - amount);

        hoax(curator, 100 ether);
        vm.expectEmit(true, true, true, true);
        emit BoughtOut(address(curator), address(collection), tokenId);
        tokenVault.buyout{value: 100 ether}();
        assertEq(collection.balanceOf(address(curator)), 1);
        assertEq(address(tokenVault).balance, 101 ether);

        vm.startPrank(user);
        uint256 userPreBalance = address(user).balance;
        uint256 claimerBalance = tokenVault.balanceOf(address(user));
        console.log(claimerBalance);
        assertEq(tokenVault.balanceOf(address(user)), amount);
        uint256 fractionsAmount = tokenVault.totalSupply();
        uint256 buyoutPrice = price * fractionsAmount;
        uint256 claimAmountWei = (buyoutPrice * amount) / fractionsAmount;
        vm.expectEmit(true, true, false, false);
        emit Claimed(address(user), claimAmountWei);
        tokenVault.claim();
        uint256 userPostBalance = address(user).balance;
        assertEq(userPostBalance, userPreBalance + claimAmountWei);
        assertEq(tokenVault.balanceOf(address(user)), 0);
    }

    function testClaimFailsAsNoTokens() public {
        vm.prank(owner);
        collection.mint(
            address(tokenVault),
            tokenUri,
            address(tokenVault),
            250
        );
        tokenVault.fractionalize(
            address(tokenVault),
            address(collection),
            tokenId,
            supply
        );
        uint256 start = block.timestamp + 1;
        tokenVault.configureSale(start, 0, price);

        vm.prank(curator);
        tokenVault.transfer(address(tokenVault), supply);

        vm.warp(start + 5);
        uint8 amount = 10;
        hoax(user, 10 ether);
        tokenVault.purchase{value: 1 ether}(amount);

        hoax(curator, 100 ether);
        tokenVault.buyout{value: 100 ether}();

        vm.startPrank(owner);
        uint256 claimerBalance = tokenVault.balanceOf(address(owner));
        console.log(claimerBalance);
        vm.expectRevert("Claimer does not hold any tokens");
        tokenVault.claim();
    }

    function testClaimFailsAsNoBuyout() public {
        vm.prank(owner);
        collection.mint(
            address(tokenVault),
            tokenUri,
            address(tokenVault),
            250
        );
        tokenVault.fractionalize(
            address(tokenVault),
            address(collection),
            tokenId,
            supply
        );
        uint256 start = block.timestamp + 1;
        tokenVault.configureSale(start, 0, price);

        vm.prank(curator);
        tokenVault.transfer(address(tokenVault), supply);

        vm.warp(start + 5);
        uint8 amount = 10;
        hoax(user, 10 ether);
        tokenVault.purchase{value: 1 ether}(amount);

        // hoax(curator, 100 ether);
        // tokenVault.buyout{value: 100 ether}();

        vm.startPrank(owner);
        vm.expectRevert("Fractionalized NFT has not been bought out");
        tokenVault.claim();
    }
}
