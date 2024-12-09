// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STRATING_ERC20_BALANCE = 10 ether;
    uint256 public constant AMOUNT_TO_MINT = 10;
    uint256 public constant AMOUNT_TO_BURN = 2;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant ETH_VALUE = 2000e18;
    uint256 private constant LIQUIDATION_TRESHOLD = 50;

    //////////////////
    // Events       //
    //////////////////
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, engine, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STRATING_ERC20_BALANCE);
    }
    ///////////////////////////
    /// Contructor Tests    ///
    ///////////////////////////

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLenghtDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    //////////////////////
    /// Price Tests    ///
    //////////////////////

    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        // 15e18 * 2000/ETH = 30,000e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = engine.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        // $2,000 / ETH, $100
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = engine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    ///////////////////////////////////
    /// Deposit Collateral Tests    ///
    ///////////////////////////////////

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock();
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        engine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralWithoutMinting() public depositedCollateral {
        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, 0);
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = engine.getTokenAmountFromUsd(weth, collateralValueInUsd);

        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    function testDepositCollateralAndMintDsc() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();

        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);

        uint256 expectedDepositAmount = engine.getTokenAmountFromUsd(weth, collateralValueInUsd);

        assertEq(totalDscMinted, AMOUNT_TO_MINT);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    /////////////////////////
    /// Mint DSC Tests    ///
    /////////////////////////

    function testMintDscAndHealthFactorIfNoCollateralDeposited() public {
        bytes memory expectedRevertData = abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, 0);

        vm.expectRevert(expectedRevertData);
        vm.startPrank(USER);
        engine.mintDsc(AMOUNT_TO_MINT);
        vm.stopPrank();
    }

    function testMintDsc() public depositedCollateral {
        uint256 startingDscMinted = engine.getDscMinted(address(USER));

        vm.startPrank(USER);
        engine.mintDsc(AMOUNT_TO_MINT);
        vm.stopPrank();

        uint256 endingDscMinted = engine.getDscMinted(address(USER));

        assertEq(startingDscMinted + AMOUNT_TO_MINT, endingDscMinted);
    }


    function testRevertsIfMintAmountIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.mintDsc(0);
        vm.stopPrank();
    }

    /////////////////////////
    /// Burn DSC Tests    ///
    /////////////////////////

    function testRevertsIfBurnAmountIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.burnDsc(0);
        vm.stopPrank();
    }
    
    function testBurnDscWithoutMintOne() public {
        vm.expectRevert();
        vm.startPrank(USER);
        engine.burnDsc(AMOUNT_TO_MINT);
        vm.stopPrank();
    }

    function testBurnDscWithMinted() public depositedCollateral {
        vm.startPrank(USER);

        engine.mintDsc(AMOUNT_TO_MINT);
        uint256 mintedDscBefore = engine.getDscMinted(USER);
        console.log("Mint 1: ", mintedDscBefore);

        dsc.approve(address(engine), AMOUNT_TO_BURN);
        engine.burnDsc(AMOUNT_TO_BURN);

        vm.stopPrank();

        uint256 mintedDscAfter = engine.getDscMinted(USER);
        console.log("Mint 2: ", mintedDscBefore);

        assertEq(mintedDscBefore, mintedDscAfter + AMOUNT_TO_BURN);
    }

    //////////////////////////////////
    /// Redeem Collateral Tests    ///
    //////////////////////////////////

    function testRevertsIfRedeemAmountIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRedeemCollateralIfThereIsNotCollateral() public {
        vm.expectRevert();
        vm.startPrank(USER);
        engine.redeemCollateral(weth, AMOUNT_TO_MINT);
        vm.stopPrank();
    }

    function testRedeemCollateralEmitsEvent() public depositedCollateral {
        vm.expectEmit(true, true, true, true, address(engine));
        emit CollateralRedeemed(address(USER), address(USER), weth, 1 ether);

        vm.startPrank(USER);
        engine.redeemCollateral(weth, 1 ether);
        vm.stopPrank();
    }

    function testRedeemCollateral() public depositedCollateral {
        (, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);
        console.log("Collateral value before redeem: ", collateralValueInUsd);

        vm.startPrank(USER);
        engine.redeemCollateral(weth, 1 ether);
        vm.stopPrank();
        // 10 eth - 1 eth = 9 eth
        // 1 ether == 2000e18

        (, uint256 collateralValueInUsdAfterRedeem) = engine.getAccountInformation(USER);
        console.log("Collateral value after redeem: ", collateralValueInUsdAfterRedeem);

        assertEq(collateralValueInUsd, collateralValueInUsdAfterRedeem + ETH_VALUE);
    }

    function testRedeemCollateralAndBurnDSC() public depositedCollateral {
        vm.startPrank(USER);
        engine.mintDsc(AMOUNT_TO_MINT);

        (uint256 dscMintedBefore, uint256 collateralValueInUsdBefore) = engine.getAccountInformation(USER);
        console.log(
            "Collateral value And DSC minted before redeemForDsc: ", collateralValueInUsdBefore, " - ", dscMintedBefore
        );

        dsc.approve(address(engine), AMOUNT_TO_BURN);
        engine.redeemCollateralForDsc(weth, 1 ether, AMOUNT_TO_BURN);
        vm.stopPrank();

        (uint256 dscMintedAfter, uint256 collateralValueInUsdAfter) = engine.getAccountInformation(USER);
        console.log(
            "Collateral value And DSC minted after redeemForDsc: ", dscMintedAfter, " - ", collateralValueInUsdAfter
        );
        // 1 ether = ETH_VALUE
        assertEq(collateralValueInUsdBefore, collateralValueInUsdAfter + ETH_VALUE);
        assertEq(dscMintedBefore, dscMintedAfter + AMOUNT_TO_BURN);
    }

    function testHealthFactorWithoutCollateralValue() public {
        vm.startPrank(USER);
        uint256 healthFactor = engine.getHealthFactor(USER);
        vm.stopPrank();
        console.log(healthFactor);

        assert(healthFactor >= MIN_HEALTH_FACTOR);
    }

    ////////////////////////////
    /// Liquidation Tests    ///
    ////////////////////////////

    function testLiquidateIfHealthFactorIsOk() public depositedCollateral {
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);

        vm.startPrank(USER);
        engine.liquidate(weth, address(USER), AMOUNT_TO_BURN);
        vm.stopPrank();
    }

    ///////////////////////////////////
    // View & Pure Function Tests //
    //////////////////////////////////
    function testGetCollateralTokenPriceFeed() public {
        address priceFeed = engine.getCollateralTokenPriceFeed(weth);
        assertEq(priceFeed, ethUsdPriceFeed);
    }

    function testGetCollateralTokens() public {
        address[] memory collateralTokens = engine.getCollateralTokens();
        assertEq(collateralTokens[0], weth);
    }

    function testGetMinHealthFactor() public {
        uint256 minHealthFactor = engine.getMinHealthFactor();
        assertEq(minHealthFactor, MIN_HEALTH_FACTOR);
    }

    function testGetLiquidationThreshold() public {
        uint256 liquidationThreshold = engine.getLiquidationThreshold();
        assertEq(liquidationThreshold, LIQUIDATION_TRESHOLD);
    }

    function testGetAccountCollateralValueFromInformation() public depositedCollateral {
        (, uint256 collateralValue) = engine.getAccountInformation(address(USER));
        uint256 expectedCollateralValue = engine.getUsdValue(weth, AMOUNT_COLLATERAL);
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetCollateralBalanceOfUser() public {
        vm.startPrank(address(USER));
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        uint256 collateralBalance = engine.getCollateralBalanceOfUser(address(USER), weth);
        assertEq(collateralBalance, AMOUNT_COLLATERAL);
    }

    function testGetAccountCollateralValue() public {
        vm.startPrank(address(USER));
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        uint256 collateralValue = engine.getAccountCollateralValueInUsd(address(USER));
        uint256 expectedCollateralValue = engine.getUsdValue(weth, AMOUNT_COLLATERAL);
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetDsc() public {
        address dscAddress = engine.getDsc();
        assertEq(dscAddress, address(dsc));
    }

    function testLiquidationPrecision() public {
        uint256 expectedLiquidationPrecision = 100;
        uint256 actualLiquidationPrecision = engine.getLiquidationPrecision();
        assertEq(actualLiquidationPrecision, expectedLiquidationPrecision);
    }
}
