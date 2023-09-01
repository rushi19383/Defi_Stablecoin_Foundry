// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
// import {MockMoreDebtDSC} from "../mocks/MockMoreDebtDSC.sol";
// import {MockFailedMintDSC} from "../mocks/MockFailedMintDSC.sol";
// import {MockFailedTransferFrom} from "../mocks/MockFailedTransferFrom.sol";
// import {MockFailedTransfer} from "../mocks/MockFailedTransfer.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");

    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BAlANCE = 10 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed,, weth,,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BAlANCE);
    }

    //////////////////////////////////////////////////////
    ///// Constructor Tests      ////////////////////////
    ////////////////////////////////////////////////////

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceeFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses,priceFeedAddresses,address(dsc));
    }

    /////////////////////////////////////////////////////////
    /// Price Test    //////////////////////////////////////
    ///////////////////////////////////////////////////////

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;

        uint256 expectedUsd = 30000e18;

        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;

        uint256 actualWeth = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(actualWeth, expectedWeth);
    }

    ///////////////////////////////////////////////////////////
    // DepositeCollateral Tests///////////////////////////////
    /////////////////////////////////////////////////////////

    function testRavertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositeCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("RAN","RAN",USER,AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositeCollateral(address(ranToken), AMOUNT_COLLATERAL);

        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositeCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    // function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
    //     (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);
    //     uint256 expectedTotalDscMinted = 0;
    //     uint256 expectedDepositedAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);

    //     assertEq(totalDscMinted, expectedTotalDscMinted);
    //     assertEq(AMOUNT_COLLATERAL, expectedDepositedAmount);
    // }
    function testCanDepositedCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);
        uint256 expectedDepositedAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, 0);
        assertEq(expectedDepositedAmount, AMOUNT_COLLATERAL);
    }
}
