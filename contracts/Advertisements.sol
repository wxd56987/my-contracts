// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Advertisements is Ownable, Initializable {
    using SafeMath for uint256;

    struct Ad {
        uint category;
        address publisher;
        uint256 inventory;
        uint256 reward;
        string ipfsHash;
    }

    address public signer;

    Ad[] private _ads;
    mapping(uint256 => uint256) private _adCompleted;
    mapping(uint256 => mapping(address => bool)) private _adUsers;
    mapping(uint => bool) public _categories;

    event CreateAd(uint256 indexed adIndex, address user);
    event CompleteAd(uint256 indexed adIndex, address user, uint256 rewardAmount);

    function initialize(address signer_) external initializer {
        require(signer_ != address(0), "Signer can not be zero address.");
        signer = signer_;
    }

    receive() external payable {}

    function setSigner(address newOne) external onlyOwner {
        require(signer != newOne, "There is no change");
        signer = newOne;
    }

    function addCategory(uint category) external {
        require(!_categories[category], "category already exists.");
        _categories[category] = true;
    }

    function disabledCategory(uint category) external {
        require(_categories[category] == true, "Category does not exist.");
        _categories[category] = false;
    }


    function createAd(string memory ipfsHash, uint category, uint256 inventory, uint256 reward) external payable {
        uint256 requiredAmount = inventory.mul(reward);
        require(msg.value == requiredAmount, "Insufficient balance to create ad.");
        require(_categories[category] == true, "Category does not exist.");

        _ads.push(Ad(category, msg.sender, inventory, reward, ipfsHash));

        emit CreateAd(_ads.length.sub(1), msg.sender);
    }

    function completeAd(uint256 adIndex, bytes memory signature) external {
        require(adIndex < _ads.length, "Ad index over flow");
        require(!_adUsers[adIndex][msg.sender], "User has already completed this ad.");
        require(verifyComplete(adIndex, msg.sender, signature), "Invalid signature.");
        require(_adCompleted[adIndex] < _ads[adIndex].inventory, "Over ad inventory");

        _adUsers[adIndex][msg.sender] = true;
        _adCompleted[adIndex] = _adCompleted[adIndex].add(1);
        payable(msg.sender).transfer(_ads[adIndex].reward);

        emit CompleteAd(adIndex, msg.sender, _ads[adIndex].reward);
    }

    function matchAd(uint _category, address user) external view returns (uint256) {
        for (uint256 i = 0; i < _ads.length; i++) {
            if (_ads[i].category == _category && !_adUsers[i][user]) {
                return i;
            }
        }
        revert("No ads available for this user.");
    }

    function adLength() external view returns(uint256) {
        return _ads.length;
    }

    function adInfo(uint256 adIndex) external view returns(uint, address, uint256, uint256, string memory) {
        Ad memory ad = _ads[adIndex];
        return (ad.category, ad.publisher, ad.inventory, ad.reward, ad.ipfsHash);
    }

    function adCompletedAmount(uint256 adIndex) external view returns(uint256) {
        return _adCompleted[adIndex];
    }

    function verifyComplete(uint256 adIndex, address user, bytes memory signature) public view returns(bool) {
        bytes32 message = keccak256(abi.encodePacked(adIndex, user, address(this)));
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        return SignatureChecker.isValidSignatureNow(signer, hash, signature);
    }
}
