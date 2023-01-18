// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "openzeppelin-contracts/access/Ownable.sol";
// import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "./TokenVault.sol";

import { CREATE3 } from "lib/solmate/src/utils/CREATE3.sol";

import "forge-std/console.sol";

// interface IERC721 {
//     function safeTransferFrom(
//         address from,
//         address to,
//         uint256 tokenId
//     ) external;
// }

interface ITokenVault {
    function initialize(address, uint) external;
    function fractionalize(address, uint, uint) external;
}

// Pausable

contract VaultFactory is Ownable {
    /// @notice the number of vaults
    uint public vaultCount;

    /// @notice the mapping of vault number to vault contract
    mapping(uint => address) public vaults;
    address[] public allVaults;

    address public logic;

    event VaultCreated(address collection, uint tokenId, address vault, uint vaultCount);

    constructor() {} 


    // create and deploy vault
    function createVault(
        address _collection,
        uint _tokenId,
        uint _supply,
        uint _fee,
        string memory _name,
        string memory _symbol,
        string memory _uri,
        uint _start,
        uint _end,
        uint _price
    ) public returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(
            _collection,
            _tokenId,
            _supply,
            msg.sender,
            _fee,
            _name,
            _symbol,
            _uri
        ));

        TokenVault vault = TokenVault(
            CREATE3.deploy(
                salt,
                abi.encodePacked(
                    type(TokenVault).creationCode,
                    abi.encode(
                        msg.sender,
                        _fee,
                        _name,
                        _symbol,
                        _uri
                    )
                ),
                0
            )
        );

        assert(address(vault) == CREATE3.getDeployed(salt));

        IERC721(_collection).transferFrom(msg.sender, address(vault), _tokenId);

        TokenVault(vault).fractionalize(msg.sender, _collection, _tokenId, _supply);

        TokenVault(vault).configureSale(_start, _end, _price);

        address vaultAddress = address(vault);

        vaultCount++;
        vaults[vaultCount] = vaultAddress;
        allVaults.push(vaultAddress);


        emit VaultCreated(_collection, _tokenId, vaultAddress, vaultCount);

        return vaultAddress;
    }

}