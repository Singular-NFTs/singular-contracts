// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract EarthMindNFT is ERC1155, Ownable, ReentrancyGuard {
    uint256 public constant MAX_NUMBER_PER_COLLECTION = 5000;

    uint256 public collectionId;

    bool public isCollectionInProgress;

    uint256 private _currentTokenID = 0;

    uint256 public creationFee = 0.01 ether;

    mapping(uint256 => string) private _tokenURIs;

    constructor() ERC1155("") {
        collectionId = 0;
        isCollectionInProgress = false;
    }

    function createCollection(string memory _metadata) public payable nonReentrant {
        require(number <= MAX_NUMBER_PER_COLLECTION, "Number exceeds the maximum number per collection");

        if (isCollectionInProgress) {
            revert CollectionInProgress();
        }

        if (msg.value < creationFee) {
            revert MustPayCreationFee();
        }

        uint256 newTokenID = _getNextTokenID();

        _incrementTokenID();

        _mint(msg.sender, newTokenID, 1, "");

        _setTokenURI(newTokenID, _metadata); // This now points to the JSON metadata

        // Transfer the creation fee to the owner of the contract
        (bool sent,) = owner().call{value: msg.value}("");
        require(sent, "DynamicNFTCollection: Failed to send Ether");
    }

    // Function to set the URI for a token ID
    function _setTokenURI(uint256 tokenId, string memory newURI) internal {
        _tokenURIs[tokenId] = newURI;
        emit URI(newURI, tokenId);
    }

    // Override the URI function to return the metadata URI for each token
    function uri(uint256 tokenId) public view override returns (string memory) {
        require(bytes(_tokenURIs[tokenId]).length > 0, "DynamicNFTCollection: URI not set");
        return _tokenURIs[tokenId];
    }

    function _getNextTokenID() private view returns (uint256) {
        return _currentTokenID + 1;
    }

    function _incrementTokenID() private {
        _currentTokenID++;
    }

    // Function to update the creation fee
    function setCreationFee(uint256 newFee) external onlyOwner {
        creationFee = newFee;
    }

    // Withdraw function to transfer contract balance to the owner
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        (bool sent,) = owner().call{value: balance}("");
        require(sent, "Failed to send Ether");
    }
}
