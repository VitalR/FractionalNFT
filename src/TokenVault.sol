// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

contract TokenVault is ERC20, Ownable, ReentrancyGuard {
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

    enum State { inactive, fractionalized, live, redeemed }
    State public state;

    /// @notice Emitted when an NFT is transferred to the token vault NFT contract.
    /// @param sender The address that sent the NFT.
    event DepositedERC721(address indexed sender);

    /// @notice Emitted when a user successfully fractionalizes an NFT and receives the total supply of the newly created ERC20 token.
    /// @param collection The address of the newly fractionalized NFT.
    /// @param token The contract address of the newly created ERC20 token.
    event Fractionalized(address indexed collection, address indexed token);

    /// @notice Emitted when a user successfully purchase some amount of NFT fractions.
    /// @param buyer The buyer of the fractions.
    /// @param amount The amount of bought fractions.
    event Purchased(address buyer, uint256 amount);

    /// @notice Emitted when a user successfully redeems an NFT in exchange for the total ERC20 supply.
    /// @param sender The address that redeemed the NFT (i.e., the address that called redeem()).
    /// @param collection The address of fractionalized NFT.
    /// @param tokenId The token Id of fractionalized NFT.
    event Redeemed(address indexed sender, address indexed collection, uint indexed tokenId);

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

        emit Fractionalized(collection, address(this));
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

    /// @notice Allows an account to purchase vault fraction tokens.
    /// @param _amount The amount of the fractions of fractional nft.
    function purchase(uint256 _amount) external payable nonReentrant {
        require(state == State.live, "The state should be fractionalized");
        require((_amount * listPrice) == msg.value, "Not enough ether sent");
        require(block.timestamp >= start, "The primary sale is not started");

        if (end > 0) {
            require(block.timestamp < end, "The primary sale is already finished");
        }

        uint256 _supply = balanceOf(address(this));
        require(_amount <= _supply, "Exceeds the total supply");
        _transfer(address(this), _msgSender(), _amount);

        emit Purchased(_msgSender(), _amount);
    }

    /// @notice A holder of the entire ERC20 supply can call redeem in order to receive the underlying NFT from the contract. 
    ///         The ERC20 tokens get transferred to the contract address.
    /// @dev Note, the ERC20 must be approved for transfer by the TokenVault contract before calling redeem().
    function redeem() public {
        uint redeemerBalance = IERC20(address(this)).balanceOf(_msgSender());
        require(redeemerBalance == IERC20(address(this)).totalSupply(), "Redeemer does not hold the entire supply");
        state = State.redeemed;
        _transfer(_msgSender(), address(this), redeemerBalance);
        IERC721(collection).safeTransferFrom(address(this), _msgSender(), tokenId);

        emit Redeemed(_msgSender(), collection, tokenId);
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