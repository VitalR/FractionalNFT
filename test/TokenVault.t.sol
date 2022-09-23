// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "src/TokenVault.sol";

contract TokenVaultTest is Test {
    address owner;
    address ZERO_ADDRESS = address(0);
    address curator = address(1);
    address user = address(2);
    uint fee = 0;

    string name = "TokenName";
    string symbol = "TNS";

    TokenVault public tokenVault;

    function setUp() public {
        owner = address(this);
        tokenVault = new TokenVault(curator, fee, name, symbol);
    }

    function testInitialState() public {
        assertEq(tokenVault.name(), name);
        assertEq(tokenVault.symbol(), symbol);
        assertEq(tokenVault.decimals(), 0);
        assertEq(tokenVault.curator(), curator);
        assertEq(tokenVault.fee(), fee);
    }
}