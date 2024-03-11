// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Strings} from "@openzeppelin/utils/Strings.sol";

import {EarthMindNFT} from "@contracts/v1/EarthMindNFT.sol";
import "@contracts/Errors.sol";

import {Test} from "forge-std/Test.sol";

contract EarthMindNFTTest is Test {
    address internal DEPLOYER = address(0x1);
    address internal ALICE = address(0x2);
    address internal NON_OWNER = address(0x3);

    EarthMindNFT internal earthMindNFT;

    event ItemRequestCreated(bytes32 indexed requestId, address indexed requester, string prompt, uint256 fee);
    event ItemAdded(uint256 indexed itemId, uint256 feePaid);

    function setUp() public {
        vm.deal(DEPLOYER, 1000 ether);
        vm.deal(ALICE, 1000 ether);
        vm.deal(NON_OWNER, 1000 ether);

        vm.prank(DEPLOYER);
        earthMindNFT = new EarthMindNFT();
    }

    function test_initialProperties() public {
        assertEq(earthMindNFT.owner(), DEPLOYER);
        assertEq(earthMindNFT.ADD_ITEM_TO_COLLECTION_FEE(), 0.01 ether);
        assertEq(earthMindNFT.MAX_ITEMS_PER_COLLECTION(), 5000);
    }

    function test_requestAddItemToCollection() public {
        DefaultRequestValues memory defaultValues = _getDefaultRequestValues();

        vm.expectEmit(true, true, false, true);

        emit ItemRequestCreated(defaultValues.requestId, ALICE, defaultValues.prompt, defaultValues.fee);

        _requestDefaultItem(defaultValues);

        EarthMindNFT.ItemRequest memory itemRequest = earthMindNFT.getItemRequest(defaultValues.requestId);

        assertEq(itemRequest.requester, ALICE);
        assertEq(itemRequest.prompt, defaultValues.prompt);
        assertEq(itemRequest.metadataURI, defaultValues.metadataURI);
        assertEq(itemRequest.creationFeePaid, defaultValues.fee);
        assertEq(itemRequest.approved, false);

        assertEq(address(earthMindNFT).balance, defaultValues.fee);
    }

    function test_requestAddItemToCollection_when_insufficient_fee_reverts() public {
        string memory metadataURI = "metadataURI";
        string memory prompt = "prompt";

        vm.startPrank(ALICE);

        vm.expectRevert(InsufficientFee.selector);

        earthMindNFT.requestAddItemToCollection(metadataURI, prompt);
    }

    function test_requestAddItemToCollection_when_item_request_already_exists_reverts() public {
        DefaultRequestValues memory defaultValues = _getDefaultRequestValues();

        _requestDefaultItem(defaultValues);

        vm.prank(ALICE);

        vm.expectRevert(ItemRequestAlreadyExists.selector);

        earthMindNFT.requestAddItemToCollection{value: defaultValues.fee}(
            defaultValues.metadataURI, defaultValues.prompt
        );
    }

    function test_requestAddItemToCollection_when_max_items_reached_reverts() public {
        DefaultRequestValues memory defaultValues = _getDefaultRequestValues();
        uint256 maxItemsPerCollection = earthMindNFT.MAX_ITEMS_PER_COLLECTION();

        // From 1 to 5000
        for (uint256 i = 1; i <= maxItemsPerCollection; i++) {
            string memory indexAsString = Strings.toString(i);

            string memory metadataURI = string(abi.encodePacked(defaultValues.metadataURI, indexAsString));

            bytes32 computedRequestId = keccak256(abi.encodePacked(metadataURI, ALICE));

            vm.prank(ALICE);
            earthMindNFT.requestAddItemToCollection{value: defaultValues.fee}(metadataURI, defaultValues.prompt);

            vm.prank(DEPLOYER);
            earthMindNFT.approveItemAddition(computedRequestId);
        }

        vm.startPrank(ALICE);
        vm.expectRevert(MaxItemsReachedForCollection.selector);
        earthMindNFT.requestAddItemToCollection{value: defaultValues.fee}(
            defaultValues.metadataURI, defaultValues.prompt
        );
    }

    function test_approveItemAddition() public {
        DefaultRequestValues memory defaultValues = _getDefaultRequestValues();

        _requestDefaultItem(defaultValues);

        vm.prank(DEPLOYER);
        earthMindNFT.approveItemAddition(defaultValues.requestId);

        EarthMindNFT.ItemRequest memory itemRequest = earthMindNFT.getItemRequest(defaultValues.requestId);

        assertEq(itemRequest.requester, defaultValues.requester);
        assertEq(itemRequest.prompt, defaultValues.prompt);
        assertEq(itemRequest.metadataURI, defaultValues.metadataURI);
        assertEq(itemRequest.creationFeePaid, defaultValues.fee);
        assertEq(itemRequest.approved, true);
        assertEq(address(earthMindNFT).balance, defaultValues.fee);

        assertEq(earthMindNFT.getTotalItemsInCollection(), 1);
        assertEq(earthMindNFT.uri(1), defaultValues.metadataURI);
    }

    function test_approveItemAddition_when_item_request_not_found_reverts() public {
        bytes32 computedRequestId = keccak256(abi.encodePacked("metadataURI", ALICE));

        vm.prank(DEPLOYER);

        vm.expectRevert(ItemRequestNotFound.selector);

        earthMindNFT.approveItemAddition(computedRequestId);
    }

    function test_approveItemAddition_when_item_request_already_approved_reverts() public {
        DefaultRequestValues memory defaultValues = _getDefaultRequestValues();

        _requestDefaultItem(defaultValues);

        vm.prank(DEPLOYER);
        earthMindNFT.approveItemAddition(defaultValues.requestId);

        vm.prank(DEPLOYER);
        vm.expectRevert(ItemRequestAlreadyApproved.selector);
        earthMindNFT.approveItemAddition(defaultValues.requestId);
    }

    function test_approveItemAddition_when_max_items_reached_reverts() public {
        DefaultRequestValues memory defaultValues = _getDefaultRequestValues();
        uint256 maxItemsPerCollection = earthMindNFT.MAX_ITEMS_PER_COLLECTION();

        // From 1 to the maxItemsPerCollection - 1 because we will request 2 more and attempt to approve them but 1 will fail
        for (uint256 i = 1; i <= maxItemsPerCollection - 1; i++) {
            string memory indexAsString = Strings.toString(i);

            string memory metadataURI = string(abi.encodePacked(defaultValues.metadataURI, indexAsString));

            bytes32 computedRequestId = keccak256(abi.encodePacked(metadataURI, ALICE));

            vm.prank(ALICE);
            earthMindNFT.requestAddItemToCollection{value: defaultValues.fee}(metadataURI, defaultValues.prompt);

            vm.prank(DEPLOYER);
            earthMindNFT.approveItemAddition(computedRequestId);
        }

        // We request 2 more but not approve here yet
        for (uint256 i = maxItemsPerCollection; i <= maxItemsPerCollection + 1; i++) {
            string memory indexAsString = Strings.toString(i);

            string memory metadataURI = string(abi.encodePacked(defaultValues.metadataURI, indexAsString));

            vm.prank(ALICE);
            earthMindNFT.requestAddItemToCollection{value: defaultValues.fee}(metadataURI, defaultValues.prompt);
        }

        // We attempt to approve both but the last one will fail
        for (uint256 i = maxItemsPerCollection; i <= maxItemsPerCollection + 1; i++) {
            string memory indexAsString = Strings.toString(i);

            string memory metadataURI = string(abi.encodePacked(defaultValues.metadataURI, indexAsString));

            bytes32 computedRequestId = keccak256(abi.encodePacked(metadataURI, ALICE));

            vm.prank(DEPLOYER);

            if (i == maxItemsPerCollection + 1) {
                // the last one will fail
                vm.expectRevert(MaxItemsReachedForCollection.selector);
                earthMindNFT.approveItemAddition(computedRequestId);
            } else {
                earthMindNFT.approveItemAddition(computedRequestId);
            }
        }
    }

    function test_setAddItemToCollectionFee() public {
        vm.startPrank(DEPLOYER);

        earthMindNFT.setAddItemToCollectionFee(0.02 ether);

        assertEq(earthMindNFT.ADD_ITEM_TO_COLLECTION_FEE(), 0.02 ether);
    }

    function test_setAddItemToCollectionFee_when_noOwner_reverts() public {
        vm.startPrank(NON_OWNER);

        vm.expectRevert("Ownable: caller is not the owner");

        earthMindNFT.setAddItemToCollectionFee(0.02 ether);
    }

    function test_withdraw() public {
        DefaultRequestValues memory defaultValues = _getDefaultRequestValues();
        _requestDefaultItem(defaultValues);

        uint256 balanceBefore = DEPLOYER.balance;

        vm.prank(DEPLOYER);
        earthMindNFT.withdraw();

        assertEq(address(earthMindNFT).balance, 0);
        assertEq(DEPLOYER.balance, balanceBefore + defaultValues.fee);
    }

    function test_withdraw_when_noOwner_reverts() public {
        _requestDefaultItem(_getDefaultRequestValues());

        vm.startPrank(NON_OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        earthMindNFT.withdraw();
    }

    // Helpers
    struct DefaultRequestValues {
        bytes32 requestId;
        string metadataURI;
        string prompt;
        uint256 fee;
        address requester;
    }

    function _getDefaultRequestValues() internal view returns (DefaultRequestValues memory) {
        string memory metadataURI = "metadataURI";
        string memory prompt = "prompt";
        uint256 fee = 0.01 ether;

        bytes32 computedRequestId = keccak256(abi.encodePacked(metadataURI, ALICE));

        return DefaultRequestValues({
            requestId: computedRequestId,
            metadataURI: metadataURI,
            prompt: prompt,
            fee: fee,
            requester: ALICE
        });
    }

    function _requestDefaultItem(DefaultRequestValues memory _values) internal {
        vm.prank(_values.requester);
        earthMindNFT.requestAddItemToCollection{value: _values.fee}(_values.metadataURI, _values.prompt);
    }
}
