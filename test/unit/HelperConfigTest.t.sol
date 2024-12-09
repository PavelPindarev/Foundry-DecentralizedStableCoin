// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract HelperConfigTest {
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }

    HelperConfig config;
    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;

    function setUp() external {
        config = new HelperConfig();
    }

    function testAnvilChain() public {
        if (block.chainid != 31337) {
            return; // Skip the test for other chains
        }

        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        (address actualPriceFeedEth,,,,) = config.activeNetworkConfig();

        (, int256 expectedPrice,,,) = ethUsdPriceFeed.latestRoundData();
        (, int256 actualPrice,,,) = MockV3Aggregator(actualPriceFeedEth).latestRoundData();

        assert(expectedPrice == actualPrice);
    }
}
