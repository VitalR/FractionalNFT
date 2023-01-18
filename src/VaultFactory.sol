// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/security/Pausable.sol";
import { CREATE3 } from "lib/solmate/src/utils/CREATE3.sol";
import "./TokenVault.sol";

contract VaultFactory is Ownable, Pausable {
    /// @notice the number of vaults
    uint public vaultCount;

    /// @notice the mapping of vault number to vault contract
    mapping(uint => address) public vaults;

    /// @notice Emitted when a new NFT vault is deployed.
    event VaultCreated(address collection, uint tokenId, address vault, uint vaultCount);

    constructor() {}

    /// @notice the function to create and deploy a new vault
    /// @param _collection the ERC721 token address fo the NFT
    /// @param _tokenId the uint ID of the token
    /// @param _supply the total supply amount of fractions of the fractionalized NFT
    /// @param _fee the platform fee paid to the curator
    /// @param _name the desired name of the vault
    /// @param _symbol the desired sumbol of the vault
    /// @param _uri the URI for all tokens
    /// @param _start The start date of primary sale
    /// @param _end The end date of primary sale
    /// @param _price the initial price of the NFT
    /// @return address of the vault
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
    ) public whenNotPaused returns (address) {
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

        emit VaultCreated(_collection, _tokenId, vaultAddress, vaultCount);

        return vaultAddress;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}