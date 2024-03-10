// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ReentrancyGuard} from "@openzeppelin/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";

import {EarthMind721} from "./EarthMind721.sol";

import "./Errors.sol";

contract EarthMindNFTFactory is Ownable, ReentrancyGuard {
    struct Collection {
        uint256 id;
        string name;
        string symbol;
        uint256 itemCount;
        EarthMind721 collectionInstance;
    }

    struct ItemRequest {
        address requester;
        string prompt;
        string metadataURI;
        uint256 creationFeePaid;
        bool approved;
    }

    struct CollectionRequest {
        address requester;
        string prompt;
        uint256 creationFeePaid;
        bool approved;
    }

    uint256 private constant MAX_ITEMS_PER_COLLECTION = 5000;
    uint256 private constant MAX_NUMBER_OF_COLLECTIONS = 100;

    uint256 public COLLECTION_CREATIONG_FEE = 0.01 ether;
    uint256 public ADD_ITEM_TO_COLLECTION_FEE = 0.01 ether;

    uint256 private _nextCollectionId;
    uint256 public activeCollectionId;

    // Collection structs
    mapping(uint256 collectionId => Collection collection) public collections;
    mapping(bytes32 collectionRequestId => CollectionRequest collectionRequestInfo) public collectionRequests;

    event CollectionCreated(uint256 indexed collectionId, string name, string symbol, uint256 feePaid);
    event CollectionCreationRequested(bytes32 requestId, address requester, string prompt, uint256 fee);

    // Item structs
    mapping(bytes32 itemRequestId => ItemRequest itemRequestInfo) public itemRequests;
    mapping(uint256 collectionId => mapping(uint256 itemId => string metadataUri)) private itemURIs;

    event ItemRequestCreated(
        uint256 indexed collectionId, bytes32 requestId, address requester, string prompt, uint256 fee
    );
    event ItemAdded(uint256 indexed collectionId, uint256 indexed itemId, uint256 feePaid);

    constructor() {
        _nextCollectionId = 0;
        activeCollectionId = 0;
        _createGenesisCollection();
    }

    // External functions
    function requestCreateCollection(string memory _prompt) external payable nonReentrant {
        if (activeCollectionId != 0) {
            revert CollectionInProgress();
        }

        if (_nextCollectionId >= MAX_NUMBER_OF_COLLECTIONS) {
            revert MaxCollectionsReached();
        }

        if (msg.value < COLLECTION_CREATIONG_FEE) {
            revert InsufficientFee();
        }

        bytes32 requestId = keccak256(abi.encodePacked(_prompt, msg.sender));

        collectionRequests[requestId] =
            CollectionRequest({requester: msg.sender, prompt: _prompt, approved: false, creationFeePaid: msg.value});

        emit CollectionCreationRequested(requestId, msg.sender, _prompt, msg.value);
    }

    // TODO: Modify onlyOwner to accept an aggregated BLS signature
    function approveCreateCollection(bytes32 _requestId, string memory _name, string memory _symbol)
        external
        onlyOwner
    {
        if (collectionRequests[_requestId].approved) {
            revert CollectionRequestAlreadyApproved();
        }

        if (collectionRequests[_requestId].requester == address(0)) {
            revert CollectionRequestNotFound();
        }

        if (activeCollectionId != 0) {
            revert CollectionInProgress();
        }

        if (_nextCollectionId >= MAX_NUMBER_OF_COLLECTIONS) {
            revert MaxCollectionsReached();
        }

        collectionRequests[_requestId].approved = true;

        _createCollection(_name, _symbol, collectionRequests[_requestId].creationFeePaid);
    }

    function requestAddItemToCollection(string memory _metadataURI, string memory _prompt)
        external
        payable
        nonReentrant
    {
        if (activeCollectionId != 0) {
            revert CollectionNotInProgress();
        }

        if (msg.value < ADD_ITEM_TO_COLLECTION_FEE) {
            revert InsufficientFee();
        }

        if (collections[activeCollectionId].itemCount > MAX_ITEMS_PER_COLLECTION) {
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

        emit ItemRequestCreated(activeCollectionId, requestId, msg.sender, _prompt, msg.value);
    }

    // TODO: Modify onlyOwner to accept an aggregated BLS signature
    function approveItemAddition(uint256 _collectionId, bytes32 _requestId) external onlyOwner nonReentrant {
        if (_collectionId != activeCollectionId) {
            revert CollectionNotActive();
        }

        if (activeCollectionId == 0) {
            revert CollectionNotInProgress();
        }

        if (collections[_collectionId].id == 0) {
            revert InvalidCollection();
        }

        ItemRequest memory itemRequestInstance = itemRequests[_requestId];

        if (itemRequestInstance.requester == address(0)) {
            revert ItemRequestNotFound();
        }

        if (itemRequestInstance.approved) {
            revert ItemRequestAlreadyApproved();
        }

        if (collections[_collectionId].itemCount > MAX_ITEMS_PER_COLLECTION) {
            revert MaxItemsReachedForCollection();
        }

        // increase the item count for the collection
        collections[_collectionId].itemCount++;

        uint256 itemId = collections[_collectionId].itemCount;

        itemRequests[_requestId].approved = true;

        EarthMind721 collectionInstance = collections[_collectionId].collectionInstance;

        collectionInstance.mintNFT(itemId, msg.sender, itemRequestInstance.metadataURI);

        emit ItemAdded(_collectionId, itemId, itemRequestInstance.creationFeePaid);

        if (collections[_collectionId].itemCount == MAX_ITEMS_PER_COLLECTION) {
            // this means it is the last item of the collection
            activeCollectionId = 0;
        }
    }

    // Internal functions
    function _createGenesisCollection() internal {
        _createCollection("Genesis", "Genesis", 0);
    }

    function _createCollection(string memory _name, string memory _symbol, uint256 _feePaid) internal {
        EarthMind721 newCollection = new EarthMind721(_name, _symbol);
        _nextCollectionId++;
        activeCollectionId = _nextCollectionId;
        collections[_nextCollectionId] = Collection({
            id: _nextCollectionId,
            name: _name,
            symbol: _symbol,
            itemCount: 0,
            collectionInstance: newCollection
        });

        emit CollectionCreated(_nextCollectionId, _name, _symbol, _feePaid);
    }

    // Admin functions
    function setCollectionCreationFee(uint256 _newFee) external onlyOwner {
        COLLECTION_CREATIONG_FEE = _newFee;
    }

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
