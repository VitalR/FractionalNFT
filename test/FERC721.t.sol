// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "src/FERC721.sol";

contract FERC721Test is Test {

    address owner;
    address ZERO_ADDRESS = address(0);
    address user = address(1);
    uint256 public royaltyValue = 250;

    string name = "TokenName";
    string symbol = "TNS";

    FERC721 public nft;

    function setUp() public {
        owner = address(this);
        nft = new FERC721(name, symbol);
    }

    function testMintToWorks() public {
        vm.prank(user);
        nft.mintTo(address(user));
        uint256 userBalance = nft.balanceOf(user);
        assertEq(userBalance, 1);
    }
}
