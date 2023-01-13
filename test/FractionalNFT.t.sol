// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "test/mocks/MockFractionalNFT.sol";
import "test/utils/DSTestPlus.sol";
import "test/utils/DSInvariantTest.sol";
import "test/utils/Hevm.sol";

import "lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Receiver.sol";

contract FractionalNFTTest is Test {
    string name = "Vault Token Name";
    string symbol = "VTS";
    string uri = "tokenUri";
    MockFractionalNFT public fractional;

    bytes32 constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function setUp() public {
        fractional = new MockFractionalNFT(name, symbol, uri);
    }

    function invariantMetadata() public {
        assertEq(fractional.name(), name);
        assertEq(fractional.symbol(), symbol);
        assertEq(fractional.decimals(), 0);
        assertEq(fractional.uri(0), uri);
    }

    function testMint() public {
        fractional.mint(address(0xBEEF), 1e18);

        assertEq(fractional.totalSupply(), 1e18);
        assertEq(fractional.balanceOf(address(0xBEEF)), 1e18);
    }

    function testBurn() public {
        fractional.mint(address(0xBEEF), 1e18);
        fractional.burn(address(0xBEEF), 0.9e18);

        assertEq(fractional.totalSupply(), 1e18 - 0.9e18);
        assertEq(fractional.balanceOf(address(0xBEEF)), 0.1e18);
    }

    function testApprove() public {
        assertTrue(fractional.approve(address(0xBEEF), 1e18));

        assertEq(fractional.allowance(address(this), address(0xBEEF)), 1e18);
    }

    function testTransfer() public {
        fractional.mint(address(this), 1e18);

        assertTrue(fractional.transfer(address(0xBEEF), 1e18));
        assertEq(fractional.totalSupply(), 1e18);

        assertEq(fractional.balanceOf(address(this)), 0);
        assertEq(fractional.balanceOf(address(0xBEEF)), 1e18);
    }

    function testTransferFrom() public {
        address from = address(0xABCD);

        fractional.mint(from, 1e18);

        vm.prank(from);
        fractional.approve(address(this), 1e18);
        assertEq(fractional.allowance(from, address(this)), 1e18);

        assertTrue(fractional.transferFrom(from, address(0xBEEF), 1e18));
        assertEq(fractional.totalSupply(), 1e18);

        assertEq(fractional.allowance(from, address(this)), 0);

        assertEq(fractional.balanceOf(from), 0);
        assertEq(fractional.balanceOf(address(0xBEEF)), 1e18);
    }

    function testSafeTransferFromToEOA() public {
        address from = address(0xABCD);

        fractional.mint(from, 1e18);

        vm.prank(from);
        fractional.setApprovalForAll(address(this), true);

        fractional.safeTransferFrom(from, address(0xBEEF), 0, 1e18, "");

        assertEq(fractional.balanceOf(address(0xBEEF), 0), 1e18);
        assertEq(fractional.balanceOf(from, 0), 0);
    }

    function testSafeTransferFromToERC1155Recipient() public {
        ERC1155Recipient to = new ERC1155Recipient();

        address from = address(0xABCD);

        fractional.mint(from, 1e18);

        vm.prank(from);
        fractional.setApprovalForAll(address(this), true);

        fractional.safeTransferFrom(from, address(to), 0, 1e18, "testing 123");

        assertEq(to.operator(), address(this));
        assertEq(to.from(), from);
        assertEq(to.id(), 0);
        // assertBytesEq(to.mintData(), "testing 123");

        assertEq(fractional.balanceOf(address(to), 0), 1e18);
        assertEq(fractional.balanceOf(from, 0), 0);
    }

    function testInfiniteApproveTransferFrom() public {
        address from = address(0xABCD);

        fractional.mint(from, 1e18);

        vm.prank(from);
        fractional.approve(address(this), type(uint256).max);

        assertTrue(fractional.transferFrom(from, address(0xBEEF), 1e18));
        assertEq(fractional.totalSupply(), 1e18);

        assertEq(fractional.allowance(from, address(this)), type(uint256).max);

        assertEq(fractional.balanceOf(from), 0);
        assertEq(fractional.balanceOf(address(0xBEEF)), 1e18);
    }

    function testFailTransferInsufficientBalance() public {
        fractional.mint(address(this), 0.9e18);
        fractional.transfer(address(0xBEEF), 1e18);
    }

    function testFailTransferFromInsufficientAllowance() public {
        address from = address(0xABCD);

        fractional.mint(from, 1e18);

        vm.prank(from);
        fractional.approve(address(this), 0.9e18);

        fractional.transferFrom(from, address(0xBEEF), 1e18);
    }
    
    function testFailTransferFromInsufficientBalance() public {
        address from = address(0xABCD);

        fractional.mint(from, 0.9e18);

        vm.prank(from);
        fractional.approve(address(this), 1e18);

        fractional.transferFrom(from, address(0xBEEF), 1e18);
    }

   function testMetadata(
        string calldata name,
        string calldata symbol,
        string calldata uri
    ) public {
        MockFractionalNFT fractional = new MockFractionalNFT(name, symbol, uri);
        assertEq(fractional.name(), name);
        assertEq(fractional.symbol(), symbol);
        assertEq(fractional.uri(0), uri);
    }

    function testMint(address from, uint256 amount) public {
        fractional.mint(from, amount);

        assertEq(fractional.totalSupply(), amount);
        assertEq(fractional.balanceOf(from), amount);
    }

    function testBurn(
        address from,
        uint256 mintAmount,
        uint256 burnAmount
    ) public {
        burnAmount = bound(burnAmount, 0, mintAmount);

        fractional.mint(from, mintAmount);
        fractional.burn(from, burnAmount);

        assertEq(fractional.totalSupply(), mintAmount - burnAmount);
        assertEq(fractional.balanceOf(from), mintAmount - burnAmount);
    }

    function testApprove(address to, uint256 amount) public {
        assertTrue(fractional.approve(to, amount));

        assertEq(fractional.allowance(address(this), to), amount);
    }

    function testTransfer(address from, uint256 amount) public {
        vm.assume(address(from) != address(0));
        fractional.mint(address(this), amount);

        assertTrue(fractional.transfer(from, amount));
        assertEq(fractional.totalSupply(), amount);

        if (address(this) == from) {
            assertEq(fractional.balanceOf(address(this)), amount);
            assertEq(fractional.balanceOf(address(this), 0), amount);
        } else {
            assertEq(fractional.balanceOf(address(this)), 0);
            assertEq(fractional.balanceOf(address(this), 0), 0);
            assertEq(fractional.balanceOf(from), amount);
            assertEq(fractional.balanceOf(from, 0), amount);
        }
    }

    function testTransferFrom(
        address to,
        uint256 approval,
        uint256 amount
    ) public {
        vm.assume(address(to) != address(0));
        amount = bound(amount, 0, approval);

        address from = address(0xABCD);

        fractional.mint(from, amount);

        vm.prank(from);
        fractional.approve(address(this), approval);

        assertTrue(fractional.transferFrom(from, to, amount));
        assertEq(fractional.totalSupply(), amount);

        uint256 app = from == address(this) || approval == type(uint256).max ? approval : approval - amount;
        assertEq(fractional.allowance(from, address(this)), app);

        if (from == to) {
            assertEq(fractional.balanceOf(from), amount);
            assertEq(fractional.balanceOf(from, 0), amount);
        } else {
            assertEq(fractional.balanceOf(from), 0);
            assertEq(fractional.balanceOf(from, 0), 0);
            assertEq(fractional.balanceOf(to), amount);
            assertEq(fractional.balanceOf(to, 0), amount);
        }
    }

    function testFailBurnInsufficientBalance(
        address to,
        uint256 mintAmount,
        uint256 burnAmount
    ) public {
        burnAmount = bound(burnAmount, mintAmount + 1, type(uint256).max);

        fractional.mint(to, mintAmount);
        fractional.burn(to, burnAmount);
    }

    function testFailTransferInsufficientBalance(
        address to,
        uint256 mintAmount,
        uint256 sendAmount
    ) public {
        sendAmount = bound(sendAmount, mintAmount + 1, type(uint256).max);

        fractional.mint(address(this), mintAmount);
        fractional.transfer(to, sendAmount);
    }

    function testFailTransferFromInsufficientAllowance(
        address to,
        uint256 approval,
        uint256 amount
    ) public {
        amount = bound(amount, approval + 1, type(uint256).max);

        address from = address(0xABCD);

        fractional.mint(from, amount);

        vm.prank(from);
        fractional.approve(address(this), approval);

        fractional.transferFrom(from, to, amount);
    }

    function testFailTransferFromInsufficientBalance(
        address to,
        uint256 mintAmount,
        uint256 sendAmount
    ) public {
        sendAmount = bound(sendAmount, mintAmount + 1, type(uint256).max);

        address from = address(0xABCD);

        fractional.mint(from, mintAmount);

        vm.prank(from);
        fractional.approve(address(this), sendAmount);

        fractional.transferFrom(from, to, sendAmount);
    }

   function testPermit() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    fractional.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );

        fractional.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);

        assertEq(fractional.allowance(owner, address(0xCAFE)), 1e18);
        assertEq(fractional.nonces(owner), 1);
    }

    function testFailPermitBadNonce() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    fractional.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 1, block.timestamp))
                )
            )
        );

        fractional.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }

    function testFailPermitBadDeadline() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    fractional.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );

        fractional.permit(owner, address(0xCAFE), 1e18, block.timestamp + 1, v, r, s);
    }

    function testFailPermitPastDeadline() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    fractional.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, block.timestamp - 1))
                )
            )
        );

        fractional.permit(owner, address(0xCAFE), 1e18, block.timestamp - 1, v, r, s);
    }

    function testFailPermitReplay() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    fractional.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );

        fractional.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
        fractional.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }
}

contract ERC20Invariants is DSTestPlus, DSInvariantTest {
    BalanceSum balanceSum;
    MockFractionalNFT fractional;

    function setUp() public {
        fractional = new MockFractionalNFT("Token", "TKN", "tokenUri");
        balanceSum = new BalanceSum(fractional);

        addTargetContract(address(balanceSum));
    }

    function invariantBalanceSum() public {
        assertEq(fractional.totalSupply(), balanceSum.sum());
    }

    function testInvariantBalanceSum() public {
        assertEq(fractional.totalSupply(), balanceSum.sum());
    }
}

contract BalanceSum {
    MockFractionalNFT fractional;
    uint256 public sum;

    constructor(MockFractionalNFT _token) {
        fractional = _token;
    }

    function mint(address from, uint256 amount) public {
        fractional.mint(from, amount);
        sum += amount;
    }

    function burn(address from, uint256 amount) public {
        fractional.burn(from, amount);
        sum -= amount;
    }

    function approve(address to, uint256 amount) public {
        fractional.approve(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public {
        fractional.transferFrom(from, to, amount);
    }

    function transfer(address to, uint256 amount) public {
        fractional.transfer(to, amount);
    }
}

contract ERC1155Recipient is ERC1155 {
    address public operator;
    address public from;
    uint256 public id;
    uint256 public amount;
    bytes public mintData;

    constructor() ERC1155("URI"){}

    function onERC1155Received(
        address _operator,
        address _from,
        uint256 _id,
        uint256 _amount,
        bytes calldata _data
    ) public returns (bytes4) {
        operator = _operator;
        from = _from;
        id = _id;
        amount = _amount;
        mintData = _data;

        return IERC1155Receiver.onERC1155Received.selector;
    }

    address public batchOperator;
    address public batchFrom;
    uint256[] internal _batchIds;
    uint256[] internal _batchAmounts;
    bytes public batchData;

    function batchIds() external view returns (uint256[] memory) {
        return _batchIds;
    }

    function batchAmounts() external view returns (uint256[] memory) {
        return _batchAmounts;
    }

    function onERC1155BatchReceived(
        address _operator,
        address _from,
        uint256[] calldata _ids,
        uint256[] calldata _amounts,
        bytes calldata _data
    ) external returns (bytes4) {
        batchOperator = _operator;
        batchFrom = _from;
        _batchIds = _ids;
        _batchAmounts = _amounts;
        batchData = _data;

        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }
}

