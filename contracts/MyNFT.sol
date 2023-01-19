pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";


contract MyNFT is Ownable, ERC721URIStorage{
    uint256 tokenId = 1;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {

    }


    function mint(address recipient, string memory tokenURI) public {        
        _mint(recipient, tokenId);
        _setTokenURI(tokenId, tokenURI);

        tokenId = tokenId + 1;        
    }

}