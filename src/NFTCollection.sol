// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./ERC2981/ERC2981.sol";

contract NFTCollection is ERC721URIStorage, ERC2981, Ownable {
    /// @dev The token ID of the next token to mint.
    uint256 private _nextTokenId = 1;
    /// @dev The burned tokens counter.
    uint256 private _burned;

    constructor() ERC721("NFT Collection", "NFTC") {}

    /// @notice Mint NFT Collection token.
    /// @param _to The address of the token recipient.
    /// @param _tokenURI The tokenURI of the minting token.
    /// @param _royaltyRecipient The recipient for royalties (if royaltyValue > 0)
    /// @param _royaltyValue The royalties asked for (EIP2981).
    function mint(
        address _to,
        string calldata _tokenURI,
        address _royaltyRecipient,
        uint256 _royaltyValue
    ) external onlyOwner {
        uint256 _tokenId = _nextTokenId;
        _safeMint(_to, _tokenId);
        _setTokenURI(_tokenId, _tokenURI);
        if (_royaltyValue > 0) {
            _setTokenRoyalty(_tokenId, _royaltyRecipient, _royaltyValue);
        }
        unchecked { _tokenId++; }
        _nextTokenId = _tokenId;
    }

    /// @notice Set the tokenURI.
    /// @param _tokenId token id.
    /// @param _tokenURI token Uri.
    function setTokenURI(uint256 _tokenId, string calldata _tokenURI) external onlyOwner {
        _setTokenURI(_tokenId, _tokenURI);
    }

    /// @notice Set the collection royalties.
    /// @param _tokenId the token id fir which we register the royalties
    /// @param _recipient recipient of the royalties
    /// @param _value percentage (using 2 decimals - 10000 = 100, 0 = 0)
    function setTokenRoyalty(uint256 _tokenId, address _recipient, uint256 _value) external onlyOwner {
        _setTokenRoyalty(_tokenId, _recipient, _value);
    }

    /// @notice Return the totalSupply.
    function totalSupply() public view returns (uint256) {
        return (_nextTokenId - 1) - _burned;
    }

    /// @dev Burns `tokenId`.
    function burn(uint256 _tokenId) public {
        require(_isApprovedOrOwner(_msgSender(), _tokenId), "Not approved to burn.");
        _burn(_tokenId);
        unchecked { _burned++; }
    }

    /// @inheritdoc	ERC165
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}