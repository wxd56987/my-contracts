// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libraries/TransferHelper.sol";

/**
 * @title Advertisements
 * @author Kmy (github.com/wxd56987)
 * @custom:coauthor Ted (github.cm/tdergouzi)
*/
contract Advertisements is Ownable, Initializable, ReentrancyGuard {
    using SafeMath for uint256;

    struct Ad {
        address publisher;
        address rewardToken;
        uint128 category;
        uint256 inventory;
        uint256 rewardAmount;
        string ipfsHash;
    }

    address public signer;
    mapping(uint128 => bool) public categories;
    mapping(address => bool) public tokenList;
    mapping(uint256 => uint256) public adCompleted;
    mapping(uint256 => mapping(address => bool)) public adUsers;

    Ad[] private _ads;
    
    event CreateAd(uint256 indexed adIndex, address user);
    event CancelAd(uint256 indexed adIndex, address user, uint256 refundAmount);
    event CompleteAd(uint256 indexed adIndex, address user, address rewardToken, uint256 rewardAmount);

    /**
     * @dev Initailize the contract.
     * @param signer_ address The validater address.
    */
    function initialize(address signer_) external initializer {
        require(signer_ != address(0), "Signer can not be zero address.");
        signer = signer_;
    }

    receive() external payable {}

    /**
     * @notice Reset the signer address.
     * @param newOne address New signer address.
    */
    function setSigner(address newOne) external onlyOwner {
        require(signer != newOne, "There is no change");
        require(newOne != address(0), "Signer can not be zero address.");

        signer = newOne;
    }

    /**
     * @notice Batch set the advertisement types.
     * @param categories_ uint128 Array of advertising types.
     * @param states boolean Array the type state.
    */
    function batchSetCategory(uint128[] calldata categories_, bool[] calldata states) external onlyOwner {
        require(categories_.length == states.length, "Diff array length");
        for (uint256 i = 0; i < categories_.length; i++) {
            _setCategory(categories_[i], states[i]);
        }
    }

    /**
     * @notice Batch set the advertisement types.
     * @param tokens uint128 Array of reward token address.
     * @param states boolean Array the token state.
    */
    function batchSetToken(address[] calldata tokens, bool[] calldata states) external onlyOwner {
        require(tokens.length == states.length, "Diff array length");
        for (uint256 i = 0; i < tokens.length; i++) {
            _setToken(tokens[i], states[i]);
        }
    }

    /**
     * @notice Publish advertisement and set reward config.
     * The reward token will be transfer into this contract when create advertisement.
     * The default reward token is gas token which address is zero address.
     * If the reward token is ERC20 token, the caller must set approve to this contract.
     * @param rewardToken address Reward token contract address.
     * @param category uint128 The type of advertisement.
     * @param inventory uint256 The max number of users who completed advertisement want to claim reward.
     * @param rewardAmount uint256 The amount of reward token each user can claim.
     * @param ipfsHash string The hash of adevertise meta data on IPFS.
    */
    function createAd(
        address rewardToken,
        uint128 category,
        uint256 inventory,
        uint256 rewardAmount,
        string memory ipfsHash
    ) external payable {
        uint256 requiredAmount = inventory.mul(rewardAmount);
        require(categories[category] == true, "Category does not exist.");
        
        if (rewardToken == address(0)) {
            // Default reward token is gas token
            require(msg.value == requiredAmount, "Insufficient balance to create ad.");
        } else if (tokenList[rewardToken]) {
            // If the reward token is ERC20 token, check the token is in whitelist
            TransferHelper.safeTransferFrom(rewardToken, msg.sender, address(this), requiredAmount);
        } else {
            revert("RewardToken is not in whitelist");
        }

        _ads.push(
            Ad(
                msg.sender,
                rewardToken,
                category,
                inventory,
                rewardAmount,
                ipfsHash
            ));

        emit CreateAd(_ads.length.sub(1), msg.sender);
    }

    /**
     * @notice Cancel advertisement and refund the reward token.
     * If the inventory of advertisement is greater than completed amount,
     * publisher will get the remain back.
     * @param adIndex uint256 The index in _ads array.
    */
    function cancelAd(uint256 adIndex) external nonReentrant {
        require(adIndex < _ads.length, "Ad index over flow");
        Ad storage ad = _ads[adIndex];
        require(msg.sender == ad.publisher, "Caller is not ad publisher");

        // Update ad inventory to completed amount
        uint256 inventory = ad.inventory;
        ad.inventory = adCompleted[adIndex];

        // Refund the reward token to the publisher
        uint256 refundAmount;
        if (inventory > adCompleted[adIndex]) {
            refundAmount = inventory.sub(adCompleted[adIndex]).mul(ad.rewardAmount);
            if (ad.rewardToken == address(0)) {
                // If the balance of contract of rewardToken is less than calculated refund amount
                // refund amount will update to the balance of contract
                refundAmount = refundAmount > address(this).balance ? address(this).balance : refundAmount;
                TransferHelper.safeTransferETH(msg.sender, refundAmount);
            } else {
                // Identical to the previous one
                uint256 balanceOfContract = IERC20(ad.rewardToken).balanceOf(address(this));
                refundAmount = refundAmount > balanceOfContract ? balanceOfContract : refundAmount;
                TransferHelper.safeTransfer(ad.rewardToken, msg.sender, refundAmount);
            }
        }

        emit CancelAd(adIndex, msg.sender, refundAmount);
    }

    /**
     * @notice User claim the reward when complated the advertisement task.
     * @param adIndex uint256 The index in _ads array.
     * @param signature bytes Signed message by signer.
    */
    function completeAd(uint256 adIndex, bytes memory signature) external nonReentrant {
        require(adIndex < _ads.length, "Ad index over flow");
        require(!adUsers[adIndex][msg.sender], "User has already completed this ad.");
        require(verifyComplete(adIndex, msg.sender, signature), "Invalid signature.");
        Ad memory ad = _ads[adIndex];
        require(adCompleted[adIndex] < ad.inventory, "Over ad inventory");

        adUsers[adIndex][msg.sender] = true;
        adCompleted[adIndex] = adCompleted[adIndex].add(1);

        if (ad.rewardToken == address(0)) {
            TransferHelper.safeTransferETH(msg.sender, ad.rewardAmount);
        } else {
            TransferHelper.safeTransfer(ad.rewardToken, msg.sender, ad.rewardAmount);
        }

        emit CompleteAd(adIndex, msg.sender, ad.rewardToken, ad.rewardAmount);
    }

    /**
     * @notice Get the completed ad index of specific category.
     * @param category_ uint128 The type of advertisement.
     * @param user address Account address.
     * @return A uint256 adIndex.
    */
    function matchAd(uint128 category_, address user) external view returns (uint256) {
        for (uint256 i = 0; i < _ads.length; i++) {
            if (_ads[i].category == category_ && !adUsers[i][user]) {
                return i;
            }
        }
        revert("No ads available for this user.");
    }

    /**
     * @notice Get the length of the ad array.
     * @return A uint256.
    */
    function adLength() external view returns(uint256) {
        return _ads.length;
    }

    /**
     * @notice Get ad info.
     * @param adIndex uint256 The index in _ads array.
     * @return A uint256 The category of ad.
     * @return B address The publisher of ad.
     * @return C uint256 The inventory of ad.
     * @return D uint256 The rewardAmount of ad.
     * @return E string The ipfs of ad.
    */
    function adInfo(uint256 adIndex) external view returns(uint256, address, uint256, uint256, string memory) {
        Ad memory ad = _ads[adIndex];
        return (ad.category, ad.publisher, ad.inventory, ad.rewardAmount, ad.ipfsHash);
    }

    /**
     * @notice Verify the signature is valid.
     * @dev The message data of signature contains adIndex, user and this contract address.
     * @param adIndex uint256 The index in _ads array.
     * @param user address User who completed the task want to claim.
     * @param signature bytes Signed message by signer.
     * @return A boolean.
    */
    function verifyComplete(uint256 adIndex, address user, bytes memory signature) public view returns(bool) {
        bytes32 message = keccak256(abi.encodePacked(adIndex, user, address(this)));
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        return SignatureChecker.isValidSignatureNow(signer, hash, signature);
    }

    function _setCategory(uint128 category, bool state) internal {
        categories[category] = state;
    }

    function _setToken(address token, bool state) internal {
        if (token == address(0)) return;
        tokenList[token] = state;
    }
}
