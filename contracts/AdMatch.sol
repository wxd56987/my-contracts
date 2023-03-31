// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AdMatch {
    enum AdType {DeFi, GameFi, NFT}

    struct Ad {
        string ipfsHash;
        address publishAddress;
        AdType adType;
        uint256 inventory;
        uint256 reward;
        address[] users;
    }

    mapping(uint256 => Ad) public ads;
    uint256 public adIndex;
    address payable public rewardReceiver;

    constructor() {
        rewardReceiver = payable(msg.sender);
    }

    function createAd(string memory _ipfsHash, AdType _adType, uint256 _inventory, uint256 _reward) public payable {
        uint256 requiredAmount = _inventory * _reward;
        require(msg.value == requiredAmount, "Insufficient balance to create ad.");
        rewardReceiver.transfer(requiredAmount);
        Ad memory newAd = Ad(_ipfsHash, msg.sender, _adType, _inventory, _reward, new address[](0));
        ads[adIndex] = newAd;
        adIndex++;
    }

    function matchAd(AdType _adType) public view returns (uint256) {
        uint256 numAds = adIndex;
        for (uint256 i = 0; i < numAds; i++) {
            Ad storage ad = ads[i];
            if (ad.adType == _adType && !ArrayUtils.contains(ad.users, msg.sender)) {
                return i;
            }
        }
        revert("No ads available for this user.");
    }

    function completeAd(uint256 _adIndex) public {
        Ad storage ad = ads[_adIndex];
        require(!ArrayUtils.contains(ad.users, msg.sender), "User has already completed this ad.");
        ad.users.push(msg.sender);
        rewardReceiver.transfer(ad.reward);
    }

}

library ArrayUtils {
    function contains(address[] storage self, address value) internal view returns (bool) {
        uint256 length = self.length;
        for (uint256 i = 0; i < length; i++) {
            if (self[i] == value) {
                return true;
            }
        }
        return false;
    }
}
