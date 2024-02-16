// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

interface ERC721 {
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function transferFrom(address from, address to, uint256 tokenId) external;
}

interface ERC1155 {
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function isApprovedForAll(address account, address operator) external view returns (bool);
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
}

contract NFTLock {
    address public erc20Token;
    uint256 public erc20Rate; // 1 ERC20 token per how much value of NFT

    event NFTLocked(address indexed sender, address indexed tokenAddress, uint256 tokenId, uint256 amountOfTokens);

    constructor(address _erc20Token, uint256 _erc20Rate) {
        erc20Token = _erc20Token;
        erc20Rate = _erc20Rate;
    }

    function lockERC721(address _nftContract, uint256 _tokenId) external {
        ERC721 nft = ERC721(_nftContract);
        address owner = nft.ownerOf(_tokenId);
        require(owner == msg.sender, "You do not own this ERC721 token");

        // Transfer ERC721 token to this contract
        nft.transferFrom(msg.sender, address(this), _tokenId);

        // Mint ERC20 tokens to the sender
        ERC20(erc20Token).transfer(msg.sender, erc20Rate);

        emit NFTLocked(msg.sender, _nftContract, _tokenId, erc20Rate);
    }

    function lockERC1155(address _nftContract, uint256 _tokenId, uint256 _amount) external {
        ERC1155 nft = ERC1155(_nftContract);
        require(nft.balanceOf(msg.sender, _tokenId) >= _amount, "Insufficient balance of ERC1155 token");
        require(nft.isApprovedForAll(msg.sender, address(this)), "You haven't approved this contract to transfer your ERC1155 token");

        // Transfer ERC1155 token to this contract
        nft.safeTransferFrom(msg.sender, address(this), _tokenId, _amount, "");

        // Mint ERC20 tokens to the sender
        ERC20(erc20Token).transfer(msg.sender, _amount / erc20Rate);

        emit NFTLocked(msg.sender, _nftContract, _tokenId, _amount / erc20Rate);
    }
}
