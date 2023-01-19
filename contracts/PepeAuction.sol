pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./interfaces/IVault.sol";

contract PepeAuction {
    uint256 private _nextId = 1;
    uint256[] public auctions;
    address public WETH;

    struct auctionDetails {
        uint256 timestamp; //unix timestamp of when the auction started
        uint256 loanId; //pepfi loan ID


        address collateral; //nft
        uint256 assetId; //ID

        uint startingPrice;

        uint256 duration; //every n
        uint256 decreasePercentage; //percentage to decrease

        address withdraw; //wallet to receive withdraw
        address liquidator;
        uint32 liquidatorFee;
    }

    mapping(uint256 => auctionDetails) public _auctions;

    constructor(address _WETH){
        WETH = _WETH;
    }

    function getAllAuctions() public view returns (uint256[] memory){
        return auctions;
    }

    function createAuction(uint256 _loanId, address _nft, uint256 _nftId, uint256 _startingPrice, uint256 _duration, uint256 _discountRate,   address _owner, address _liquidator, uint32 liquidatorFee) public returns (uint256){
        IERC721(_nft).transferFrom(msg.sender, address(this), _nftId); //Transfer the NFT to our wallet. 

        _auctions[_nextId+1] = auctionDetails({
                timestamp: block.timestamp,
                loanId: _loanId,
                collateral: _nft,
                assetId: _nftId,
                startingPrice: _startingPrice,
                duration: _duration,
                decreasePercentage: _discountRate,
                withdraw: _owner,
                liquidator: _liquidator,
                liquidatorFee: liquidatorFee

            });

        auctions.push(_nextId+1);
        _nextId++;
        return _nextId;
    }

    function getPrice(uint256 _auctionId) public view returns (uint256) {
        auctionDetails memory auction = _auctions[_auctionId];
        uint timeElapsed = ((block.timestamp - auction.timestamp) / auction.duration) + 1;

        uint256 price = auction.startingPrice - ((auction.decreasePercentage * auction.startingPrice * timeElapsed)/1000);

        //for sanity 
        if (price < 10){
            price = 10;
        }

        return price;
    }

    function buy(uint256 _auctionId) external payable {
        auctionDetails memory auction = _auctions[_auctionId];


        uint price = getPrice(_auctionId);

        uint liquidator = (auction.decreasePercentage * price)/1000;
        uint owner = price - liquidator;

        // send the liquidator and to self

        (bool success, ) = WETH.call(abi.encodeWithSelector(0x23b872dd, msg.sender, auction.liquidator, liquidator));
        (bool success2, ) = WETH.call(abi.encodeWithSelector(0x23b872dd, msg.sender, auction.withdraw, owner));

        if ((success) && (success2)){
            IVault(auction.withdraw).finishedAuction(auction.loanId);
        }
        else{
            revert();
        }

    }

}