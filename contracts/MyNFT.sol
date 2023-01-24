pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";


contract MyNFT is Ownable, ERC721URIStorage {
    /// changed: start from 0
    uint256 internal tokenId;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}


    function mint(address recipient, string memory tokenURI) public {  
        // changed: iterate id first and save to memory  
        uint id = ++tokenId;

        _mint(recipient, id);
        _setTokenURI(id, tokenURI);      
    }

}