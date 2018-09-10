pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

import "./MarketSource.sol";


/**
 * @title Market Oracle
 *
 * @dev Provides price and volume data onchain using data from a whitelisted
 *      set of market sources.
 */
contract MarketOracle is Ownable {
    using SafeMath for uint256;

    // Whitelist of sources
    MarketSource[] public whitelist;

    event LogSourceAdded(MarketSource source);
    event LogSourceRemoved(MarketSource source);
    event LogSourceExpired(MarketSource source);

    /**
     * @dev Calculates the volume weighted average of exchange rates and total trade volume. 
     *      Exchange rate is an 18 decimal fixed point number and volume is a 2 decimal fixed
     *      point number representing the total trade volume in the last 24 hours.
     * @return The volume weighted average of active exchange rates and the total trade.
     */
    function getPriceAndVolume() external returns (uint256, uint256) {
        uint256 volumeWeightedSum = 0;
        uint256 volumeSum = 0;
        uint256 partialRate = 0;
        uint256 partialVolume = 0;
        bool isSourceFresh = false;

        for (uint8 i = 0; i < whitelist.length; i++) {
            (isSourceFresh, partialRate, partialVolume) = whitelist[i].getReport();

            if (!isSourceFresh) {
                emit LogSourceExpired(whitelist[i]);
                continue;
            }

            volumeWeightedSum = volumeWeightedSum.add(partialRate.mul(partialVolume));
            volumeSum = volumeSum.add(partialVolume);
        }

        uint256 exchangeRate = volumeWeightedSum.div(volumeSum);
        return (exchangeRate, volumeSum);
    }

    /**
     * @dev Adds a market source to the whitelist.
     * @param source Address of the MarketSource.
     */
    function addSource(MarketSource source) external onlyOwner {
        whitelist.push(source);
        emit LogSourceAdded(source);
    }

    /**
     * @dev Removes the provided market source from the whitelist.
     * @param source Address of the MarketSource.
     */
    function removeSource(MarketSource source) external onlyOwner {
        for (uint8 i = 0; i < whitelist.length; i++) {
            if (whitelist[i] == source) {
                removeSource(i);
            }
        }
    }

    /**
     * @dev Expunges from the whitelist any MarketSource whose associated contracts have been
     *      destructed.
     */
    function removeDeadSources() external {
        uint8 i = 0;
        while (i < whitelist.length) {
            if (isContractDead(whitelist[i])) {
                removeSource(i);
            } else {
                i++;
            }
        }
    }

    /**
     * @return The number of sources in the whitelist.
     */
    function whitelistCount() public view returns (uint256) {
        return whitelist.length;
    }

    /**
     * @dev Checks if the contract has been destructed.
     * @param _address Address of the smart contract.
     */
    function isContractDead(address _address) private view returns (bool) {
        uint size;
        assembly { size := extcodesize(_address) }
        return size == 0;
    }

   /**
    * @dev Removes the MarketSource at a given index from the whitelist.
    * @param index Index of the MarketSource.
    */
    function removeSource(uint8 index) private {
        emit LogSourceRemoved(whitelist[index]);
        if (index != whitelist.length-1) {
            whitelist[index] = whitelist[whitelist.length-1];
        }
        whitelist.length--;
    }
}
