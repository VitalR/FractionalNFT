// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "src/FractionalNFT.sol";

contract MockFractionalNFT is FractionalNFT {
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _uri
    ) FractionalNFT(_name, _symbol, _uri) {}

    function mint(address to, uint256 value) public virtual {
        _mint(to, value);
    }

    function burn(address from, uint256 value) public virtual {
        _burn(from, value);
    }
}