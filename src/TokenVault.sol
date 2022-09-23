// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";

contract TokenVault is ERC20, Ownable {
    /// @notice The ERC721 token address of the fractional NFT.
    address public collection;

    /// @notice The ERC721 token ID of the fractional NFT.
    uint public tokenId;

    /// @notice The price of fraction of the fractionalized NFT for the primary sale.
    uint public listPrice;

    /// @notice The address who initially deposited the NFT.
    address public curator;

    /// @notice The platform fee paid to the curator.
    uint public fee;

    /// @notice The start date of primary sale.
    uint public start;

    /// @notice The end date of primary sale.
    uint public end;

    /// @notice A boolean to indicate if the vault has closed.
    bool public vaultClosed;

    enum State { inactive, fractionalized, live }
    State public state;

    /// @notice Emitted when an NFT is transferred to the token vault NFT contract.
    /// @param sender The address that sent the NFT.
    event DepositedERC721(address indexed sender);

    /// @notice Emitted when a user successfully fractionalizes an NFT and receives the total supply of the newly created ERC20 token.
    /// @param collection The address of the newly fractionalized NFT.
    /// @param tokenId The contract address of the newly created ERC20 token.
    event Fractionalized(address indexed collection, uint256 indexed tokenId);

    constructor(address _curator, uint256 _fee, string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        require(_curator != address(0), "ANG: zero address not allowed");
        curator = _curator;
        fee = _fee;
        state = State.inactive;
    }

    /// @notice Create a fractionalized NFT: Lock the NFT in the contract; create a new ERC20 token, as specified;
    ///         and transfer the total supply of the token to the curator.
    /// @param _from The address of the curator/NFT owner.
    /// @param _collection The address of the NFT that is to be fractionalized.
    /// @param _tokenId The token ID of the NFT that is to be fractionalized.
    /// @param _supply The count of fractions of the fractionalized NFT - the total supply amount of vault ERC20 tokens.
    /// @dev Note the NFT must be approved for transfer by the owner of NFT token ID.
    function fractionalize(
        address _from,
        address _collection,
        uint256 _tokenId,
        uint256 _supply
    ) public onlyOwner {
        require(state == State.inactive, "ANG: state should be inactive");
        collection = _collection;
        tokenId = _tokenId;
        IERC721(collection).safeTransferFrom(_from, address(this), _tokenId);
        _mint(curator, _supply);
        state = State.fractionalized;

        emit Fractionalized(collection, tokenId);
    }

    /// @notice Configure primary sale.
    /// @param _start The start date of primary sale.
    /// @param _end The end date of primary sale.
    /// @param _price The new listing price.
    function configureSale(uint _start, uint _end, uint _price) external onlyOwner {
        require(state == State.fractionalized, "The state should be fractionalized");
        require(_start >= block.timestamp, "The start primary sale should be set up");
        require(_price > 0, "The listing price should be > 0");
        start = _start;
        end = _end;
        listPrice = _price;
        state = State.live;
    }

    /// @dev Returns the number of decimals used to get its user representation.
    function decimals() public view virtual override returns (uint8) {
        return 0;
    }

    /// @dev Required to use safeTransferFrom() from OpenZeppelin's ERC721 contract (when transferring NFTs to this contract).
    function onERC721Received(address, address, uint256, bytes memory) public returns (bytes4) {
        emit DepositedERC721(msg.sender);
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }

}