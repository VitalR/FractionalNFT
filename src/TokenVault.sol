// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "./FractionalNFT.sol";

contract TokenVault is FractionalNFT, Ownable, ReentrancyGuard {
    /// @notice The ERC721 token address of the fractional NFT.
    address public collection;

    /// @notice The ERC721 token ID of the fractional NFT.
    uint256 public tokenId;

    /// @notice The price of fraction of the fractionalized NFT for the primary sale.
    uint256 public listPrice;

    /// @notice The address who initially deposited the NFT.
    address public curator;

    /// @notice The platform fee paid to the curator, percentage bps (using 2 decimals - 10000 = 100, 0 = 0), eg 495 == 4.95%.
    uint256 public fee;

    /// @notice The start date of primary sale.
    uint256 public start;

    /// @notice The end date of primary sale.
    uint256 public end;

    /// @dev Max bps in the System.
    uint128 private constant MAX_BPS = 10_000;

    /// @notice A boolean to indicate if the vault has closed.
    bool public vaultClosed;

    enum State { inactive, fractionalized, live, redeemed, boughtOut }
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
    event Redeemed(address indexed sender, address indexed collection, uint256 indexed tokenId);

    /// @notice Emitted when a user successfully buys an NFT from the FractionalizeNFT contract.
    /// @param sender The address that bought the NFT (i.e., the address that called buyout()).
    /// @param collection The address of fractionalized NFT.
    /// @param tokenId The token Id of fractionalized NFT.
    event BoughtOut(address indexed sender, address collection, uint256 indexed tokenId);

    /// @notice Emitted when a user successfully claims a payout following the buyout of an NFT from the FractionalizeNFT contract.
    /// @param sender The address that the user held ERC20 tokens for (i.e., the address that called claim()).
    /// @param amount The amount of ether claimded.
    event Claimed(address indexed sender, uint256 indexed amount);

    /// @notice Emitted when the curator change curator account address.
    event UpdateCurator(address indexed curator);
    /// @notice Emitted when the curator change their fee.
    event UpdateFee(uint256 fee);

    constructor(address _curator, uint256 _fee, string memory _name, string memory _symbol, string memory _uri) FractionalNFT(_name, _symbol, _uri) {
        require(_curator != address(0), "Set the zero address");
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
    ) external onlyOwner {
        require(state == State.inactive, "State should be inactive");
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
    /// @param _price The new listing price per fraction.
    function configureSale(uint256 _start, uint256 _end, uint256 _price) external onlyOwner {
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
        require(block.timestamp > start, "The primary sale is not started");
        if (end > 0) require(block.timestamp < end, "The primary sale is already finished");

        if (fee > 0) {
            uint256 feeAmount = ((_amount * listPrice) * fee) / MAX_BPS;
            require(((_amount * listPrice) + feeAmount) == msg.value, "Insufficient value sent");
        } else {
            require((_amount * listPrice) == msg.value, "Not enough ether sent");
        }

        uint256 _supply = balanceOf(address(this));
        require(_amount <= _supply, "Exceeds the total supply");
        _transfer(address(this), _msgSender(), _amount);

        emit Purchased(_msgSender(), _amount);
    }

    /// @notice A holder of the entire ERC20 supply can call redeem in order to receive the underlying NFT from the contract.
    ///         The function burns all shares and transfers the vault NFT to the user.
    /// @dev Note, the ERC20 must be approved for transfer by the TokenVault contract before calling redeem().
    function redeem() external {
        // require(state == State.inactive, "No redeeming");
        uint256 redeemerBalance = IERC20(address(this)).balanceOf(_msgSender());
        require(
            redeemerBalance == IERC20(address(this)).totalSupply(),
            "Redeemer does not hold the entire supply"
        );
        state = State.redeemed;
        // _transfer(_msgSender(), address(this), redeemerBalance);
        _burn(_msgSender(), totalSupply());
        IERC721(collection).safeTransferFrom(address(this), _msgSender(), tokenId);

        emit Redeemed(_msgSender(), collection, tokenId);
    }

    /// @notice Allows an account to buy the NFT from the contract for the specified buyout price.
    function buyout() external payable {
        uint256 fractionsAmount = totalSupply();
        uint256 buyoutPrice = reservePrice();
        require(msg.value >= buyoutPrice, "Sender sent less than the buyout price");
        state = State.boughtOut;
        IERC721(collection).safeTransferFrom(address(this), _msgSender(), tokenId);

        emit BoughtOut(_msgSender(), collection, tokenId);
    }

    /// @notice Allows a holder of the ERC20 tokens to claim his share of the sale proceedings (in ether) following a buyout of the fractionalized NFT.
    /// @dev Note, the ERC20 must be approved for transfer by the TokenVault contract before calling claim().
    function claim() external {
        require(state == State.boughtOut, "Fractionalized NFT has not been bought out");
        uint256 claimerBalance = balanceOf(_msgSender());
        require(claimerBalance > 0, "Claimer does not hold any tokens");
        // _transfer(_msgSender, address(this), claimerBalance);

        uint256 fractionsAmount = totalSupply();
        uint256 buyoutPrice = reservePrice();
        uint256 claimAmountWei = (buyoutPrice * claimerBalance) / fractionsAmount;
        _burn(_msgSender(), claimerBalance);
        (bool success, ) = payable(_msgSender()).call{value: claimAmountWei}("");
        require(success, "Claim failed");

        emit Claimed(_msgSender(), claimAmountWei);
    }

    /// @notice Allow curator to update the curator address.
    /// @param _curator new curator address.
    function updateCurator(address _curator) external {
        require(_msgSender() == curator, "ANG: not curator");
        curator = _curator;
        emit UpdateCurator(_curator);
    }

    /// @notice Allow the curator to change their fee.
    /// @param _fee The new fee.
    function updateFee(uint256 _fee) external {
        require(_msgSender() == curator, "ANG: not curator");
        fee = _fee;
        emit UpdateFee(_fee);
    }

    /// @dev Returns the reserve price of Fractional NFT.
    function reservePrice() public view returns (uint256) {
        return listPrice * totalSupply();
    }

    /// @dev Required to use safeTransferFrom() from OpenZeppelin's ERC721 contract (when transferring NFTs to this contract).
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public returns (bytes4) {
        emit DepositedERC721(msg.sender);
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }
}
