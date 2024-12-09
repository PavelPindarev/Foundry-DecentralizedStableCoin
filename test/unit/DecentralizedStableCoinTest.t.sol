// SPDX-License-Identifier

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";

contract DecentralizedStableCoinTest is Test {
    address public USER = makeAddr("user");
    DecentralizedStableCoin dsc;
    string public constant DSC_NAME = "DecentralizedStableCoin";
    uint256 public constant AMOUNT_TO_MINT = 100;
    uint256 public constant AMOUNT_TO_BURN = 60;

    modifier mintedDsc() {
        vm.startPrank(USER);
        dsc.mint(USER, AMOUNT_TO_MINT);
        vm.stopPrank();
        _;
    }

    function setUp() external {
        vm.startPrank(USER);
        dsc = new DecentralizedStableCoin();
        vm.stopPrank();
    }

    function testConstructor() public {
        vm.startPrank(USER);
        string memory dscName = dsc.name();
        vm.stopPrank();

        assertEq(dscName, DSC_NAME);
    }

    function testOnlyOwner() public {
        vm.expectRevert();

        address user2 = makeAddr("user2");
        vm.startPrank(user2);
        dsc.burn(1);
        vm.stopPrank();
    }

    // Mint Function

    function testMintIfAddressIsZero() public {
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__ZeroAddress.selector);

        vm.startPrank(USER);
        dsc.mint(address(0), AMOUNT_TO_MINT);
        vm.stopPrank();
    }

    function testMintIfAmountIsZero() public {
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__MustBeMoreThanZero.selector);

        vm.startPrank(USER);
        dsc.mint(USER, 0);
        vm.stopPrank();
    }

    function testMint() public {
        vm.startPrank(USER);
        bool mintSuccessful = dsc.mint(USER, AMOUNT_TO_MINT);
        vm.stopPrank();

        uint256 actualDscMinted = dsc.balanceOf(USER);

        assertEq(AMOUNT_TO_MINT, actualDscMinted);
        assert(mintSuccessful);
    }

    //Burn Function

    function testBurnIfThereIsNoBalance() public {
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__BurnAmountExceedsBalance.selector);

        vm.startPrank(USER);
        dsc.burn(AMOUNT_TO_BURN);
        vm.stopPrank();
    }

    function testBurnIfThereIsNoAmount() public mintedDsc {
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__MustBeMoreThanZero.selector);

        vm.startPrank(USER);
        dsc.burn(0);
        vm.stopPrank();
    }

    function testBurn() public mintedDsc {
        vm.startPrank(USER);
        dsc.burn(AMOUNT_TO_BURN);
        vm.stopPrank();

        uint256 actualDscBalance = dsc.balanceOf(USER);

        assertEq(AMOUNT_TO_MINT - AMOUNT_TO_BURN, actualDscBalance);
    }
}
