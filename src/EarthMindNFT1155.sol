// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC1155} from "@openzeppelin/token/ERC1155/ERC1155.sol";
import {ReentrancyGuard} from "@openzeppelin/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";

import "./Errors.sol";

contract EarthMind1155 is ERC1155, Ownable, ReentrancyGuard {
    using Strings for uint256;

    struct Collection {
        uint256 id;
        string name;
        uint256 itemCount;
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
    bool public isCollectionInProgress;

    // Collection structs
    mapping(uint256 collectionId => Collection collection) public collections;
    mapping(bytes32 collectionRequestId => CollectionRequest collectionRequestInfo) public collectionRequests;

    event CollectionCreated(uint256 indexed collectionId, string name, uint256 feePaid);
    event CollectionCreationRequested(bytes32 requestId, address requester, string prompt, uint256 fee);

    // Item structs
    mapping(bytes32 itemRequestId => ItemRequest itemRequestInfo) public itemRequests;
    mapping(uint256 collectionId => mapping(uint256 itemId => string metadataUri)) private itemURIs;

    event ItemRequestCreated(
        uint256 indexed collectionId, bytes32 requestId, address requester, string prompt, uint256 fee
    );
    event ItemAdded(uint256 indexed collectionId, uint256 indexed itemId, uint256 feePaid);

    constructor() ERC1155("") {
        _nextCollectionId = 0;
        isCollectionInProgress = false;

        // TODO: Create a collection with id 0 and name "Genesis Collection"
    }

    function requestCreateCollection(string memory _prompt) external payable nonReentrant {
        if (isCollectionInProgress) {
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
    function approveCreateCollection(bytes32 _requestId, string memory _name) external onlyOwner {
        if (collectionRequests[_requestId].approved) {
            revert CollectionRequestAlreadyApproved();
        }

        if (collectionRequests[_requestId].requester == address(0)) {
            revert CollectionRequestNotFound();
        }

        if (isCollectionInProgress) {
            revert CollectionInProgress();
        }

        if (_nextCollectionId >= MAX_NUMBER_OF_COLLECTIONS) {
            revert MaxCollectionsReached();
        }

        // increment the collection id
        uint256 collectionId = _nextCollectionId++;

        collections[collectionId] = Collection({id: collectionId, name: _name, itemCount: 0});

        activeCollectionId = collectionId;

        isCollectionInProgress = true;

        collectionRequests[_requestId].approved = true;

        emit CollectionCreated(collectionId, _name, collectionRequests[_requestId].creationFeePaid);
    }

    function requestAddItemToCollection(string memory _metadataURI, string memory _prompt)
        external
        payable
        nonReentrant
    {
        if (!isCollectionInProgress) {
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
        // TODO: Refactorizar access to itemRequests[_requestId]
        if (_collectionId != activeCollectionId) {
            revert CollectionNotActive();
        }

        if (!isCollectionInProgress) {
            revert CollectionNotInProgress();
        }

        if (collections[_collectionId].id == 0) {
            revert InvalidCollection();
        }

        if (itemRequests[_requestId].requester == address(0)) {
            revert ItemRequestNotFound();
        }

        if (itemRequests[_requestId].approved) {
            revert ItemRequestAlreadyApproved();
        }

        if (collections[_collectionId].itemCount > MAX_ITEMS_PER_COLLECTION) {
            revert MaxItemsReachedForCollection();
        }

        // increase the item count for the collection
        collections[_collectionId].itemCount++;

        uint256 itemId = collections[_collectionId].itemCount;

        // TODO: think how to do the composite id a string of format "collectionId-itemId"
        uint256 compositeId = _createCompositeId(_collectionId, itemId);

        itemRequests[_requestId].approved = true;
        itemURIs[_collectionId][itemId] = itemRequests[_requestId].metadataURI;

        _mint(itemRequests[_requestId].requester, compositeId, 1, "");

        emit ItemAdded(_collectionId, compositeId, itemRequests[_requestId].creationFeePaid);

        // TODO: si es la ultima pieza de la collection, terminar la collection, lo que implica que no se pueden agregar mas items
        // pero decimos que ya no hay una collection en progreso y hacemos update del activeCollectionId
        // lo cual me indica que tal vez el collection in progress no es necesario
    }

    function uri(uint256 compositeId) public view override returns (string memory) {
        uint256 collectionId = _getCollectionId(compositeId);
        uint256 itemId = _getItemId(compositeId);
        return itemURIs[collectionId][itemId];
    }

    // TODO: Fix these things to remove the hardcoded 10000
    function _createCompositeId(uint256 collectionId, uint256 itemId) private pure returns (uint256) {
        return collectionId * 10000 + itemId; // Adjust if needed based on MAX_ITEMS_PER_COLLECTION
    }

    function _getCollectionId(uint256 compositeId) private pure returns (uint256) {
        return compositeId / 10000; // Adjust if needed based on MAX_ITEMS_PER_COLLECTION
    }

    function _getItemId(uint256 compositeId) private pure returns (uint256) {
        return compositeId % 10000; // Adjust if needed based on MAX_ITEMS_PER_COLLECTION
    }

    // Function to update the fee
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
