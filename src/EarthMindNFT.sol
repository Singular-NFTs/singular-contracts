// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC1155} from "@openzeppelin/token/ERC1155/ERC1155.sol";
import {ReentrancyGuard} from "@openzeppelin/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {Counters} from "@openzeppelin/utils/Counters.sol";

import "./Errors.sol";

contract EarthMindNFTSingle is ERC1155, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    struct ItemRequest {
        address requester;
        string prompt;
        string metadataURI;
        uint256 creationFeePaid;
        bool approved;
    }

    uint256 private constant MAX_ITEMS_PER_COLLECTION = 5000;

    uint256 public ADD_ITEM_TO_COLLECTION_FEE = 0.01 ether;

    // Item structs
    mapping(bytes32 itemRequestId => ItemRequest itemRequestInfo) public itemRequests;
    mapping(uint256 itemId => string metadataUri) private itemURIs;

    event ItemRequestCreated(bytes32 requestId, address requester, string prompt, uint256 fee);
    event ItemAdded(uint256 indexed itemId, uint256 feePaid);

    constructor() ERC1155("") {}

    function requestAddItemToCollection(string memory _metadataURI, string memory _prompt)
        external
        payable
        nonReentrant
    {
        if (msg.value < ADD_ITEM_TO_COLLECTION_FEE) {
            revert InsufficientFee();
        }

        if (_tokenIds.current() > MAX_ITEMS_PER_COLLECTION) {
            revert MaxItemsReachedForCollection();
        }

        bytes32 requestId = keccak256(abi.encodePacked(_metadataURI, msg.sender));

        itemRequests[requestId] = ItemRequest({
            requester: msg.sender,
            prompt: _prompt,
            metadataURI: _metadataURI,
            creationFeePaid: msg.value,
            approved: false
        });

        emit ItemRequestCreated(requestId, msg.sender, _prompt, msg.value);
    }

    // TODO: Modify onlyOwner to accept an aggregated BLS signature
    function approveItemAddition(bytes32 _requestId) external onlyOwner nonReentrant {
        ItemRequest memory itemRequestInstance = itemRequests[_requestId];

        if (itemRequestInstance.requester == address(0)) {
            revert ItemRequestNotFound();
        }

        if (itemRequestInstance.approved) {
            revert ItemRequestAlreadyApproved();
        }

        if (_tokenIds.current() > MAX_ITEMS_PER_COLLECTION) {
            revert MaxItemsReachedForCollection();
        }

        // increase the item count for the collection
        _tokenIds.increment();

        uint256 itemId = _tokenIds.current();

        itemRequests[_requestId].approved = true;
        itemURIs[itemId] = itemRequests[_requestId].metadataURI;

        _mint(itemRequestInstance.requester, itemId, 1, "");

        emit ItemAdded(itemId, itemRequestInstance.creationFeePaid);
    }

    function uri(uint256 _tokenId) public view override returns (string memory) {
        return itemURIs[_tokenId];
    }

    // Function to update the fee
    function setAddItemToCollectionFee(uint256 _newFee) external onlyOwner {
        ADD_ITEM_TO_COLLECTION_FEE = _newFee;
    }

    // Withdraw function to transfer contract balance to the owner
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        (bool sent,) = owner().call{value: balance}("");
        require(sent, "Failed to send Ether");
    }
}
