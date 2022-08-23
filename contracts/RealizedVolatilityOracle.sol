// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

// @title On-chain realized volatility oracle with online algorithm,
// by tracking an on-chain price oracle
contract RealizedVolatilityOracle {

    event NewVolatility(uint256 timestamp, uint256 volatility);

    uint256 constant ONE = 10**18;

    string public symbol;
    bytes32 public immutable symbolId;
    address public immutable priceOracle;
    uint256 public immutable lambda;
    uint256 public immutable minDeltaTime;

    // most recent updated timestamp and price
    uint256 public timestamp;
    uint256 public price;
    // most recent updated volatility
    uint256 public volatility;

    constructor (
        string memory symbol_,
        address priceOracle_,
        uint256 lambda_,
        uint256 initialVolatility_,
        uint256 minDeltaTime_
    ) {
        symbol = symbol_;
        symbolId = keccak256(abi.encodePacked(symbol_));
        priceOracle = priceOracle_;
        lambda = lambda_;
        minDeltaTime = minDeltaTime_;

        timestamp = block.timestamp;
        price = IPriceOracle(priceOracle_).getPrice();
        volatility = initialVolatility_;
    }

    // @dev Non-view function which fetches current price and updates realized volatility with an online algorithm
    // @dev The fetched price and returned volatility are both in 18 decimals
    //                                        Pi
    // logReturn: ri = ln(Pi) - ln(Pi-1) ~= ------ - 1
    //                                       Pi-1
    //                                         1 year
    // volatility (EMA): Vi = lambda * ri^2 * -------- + (1 - lambda) * Vi-1
    //                                         deltaT
    function getVolatility() public returns (uint256) {
        if (timestamp + minDeltaTime > block.timestamp) {
            // no updates when elapsed time less than minimum delta time
            return volatility;
        }
        uint256 oldPrice = price;
        uint256 newPrice = IPriceOracle(priceOracle).getPrice();
        uint256 absDiff = newPrice >= oldPrice ? newPrice - oldPrice : oldPrice - newPrice;
        uint256 absLogReturn = absDiff * ONE / oldPrice;
        uint256 newVolatility = (absLogReturn ** 2 * 31536000 / (block.timestamp - timestamp) / ONE * lambda + (ONE - lambda) * volatility) / ONE;

        timestamp = block.timestamp;
        price = newPrice;
        volatility = newVolatility;
        emit NewVolatility(block.timestamp, newVolatility);

        return newVolatility;
    }

}

interface IPriceOracle {
    function getPrice() external view returns (uint256);
}
