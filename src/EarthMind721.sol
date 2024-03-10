// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Ownable} from "@openzeppelin/access/Ownable.sol";

import "@openzeppelin/token/ERC721/extensions/ERC721URIStorage.sol";

contract EarthMind721 is ERC721URIStorage, Ownable {
    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        _transferOwnership(msg.sender);
    }

    function mintNFT(uint256 _itemId, address _recipient, string memory _metadataURI) public onlyOwner {
        _mint(_recipient, _itemId);
        _setTokenURI(_itemId, _metadataURI);
    }
}
