// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

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

contract Frenz is Ownable {
    address public erc20Token;
    uint256 public erc20Rate; // 1 ERC20 token per how much value of NFT
    address payable public feeAddress;
    uint256 public constant FEE_AMOUNT = 0.01 ether;
    bool public paused;

    event NFTLocked(address indexed sender, address indexed tokenAddress, uint256 tokenId, uint256 amountOfTokens);
    event FeePaid(address indexed payer, uint256 amount);
    event Paused(address account);
    event Unpaused(address account);

    constructor(address _erc20Token, uint256 _erc20Rate, address payable _feeAddress) {
        erc20Token = _erc20Token;
        erc20Rate = _erc20Rate;
        feeAddress = _feeAddress;
        paused = false;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier whenPaused() {
        require(paused, "Contract is not paused");
        _;
    }

    modifier onlyOwnerOrPaused() {
        require(msg.sender == owner() || paused, "Not the contract owner or contract is not paused");
        _;
    }

    function lockERC721(address _nftContract, uint256 _tokenId) external payable whenNotPaused {
        require(msg.value >= FEE_AMOUNT, "Insufficient fee");

        ERC721 nft = ERC721(_nftContract);
        address owner = nft.ownerOf(_tokenId);
        require(owner == msg.sender, "You do not own this ERC721 token");

        // Transfer ERC721 token to this contract
        nft.transferFrom(msg.sender, address(this), _tokenId);

        // Mint ERC20 tokens to the sender
        ERC20(erc20Token).transfer(msg.sender, erc20Rate);

        // Send fee to the fee address
        feeAddress.transfer(FEE_AMOUNT);

        emit NFTLocked(msg.sender, _nftContract, _tokenId, erc20Rate);
        emit FeePaid(msg.sender, FEE_AMOUNT);
    }

    function lockERC1155(address _nftContract, uint256 _tokenId, uint256 _amount) external payable whenNotPaused {
        require(msg.value >= FEE_AMOUNT, "Insufficient fee");

        ERC1155 nft = ERC1155(_nftContract);
        require(nft.balanceOf(msg.sender, _tokenId) >= _amount, "Insufficient balance of ERC1155 token");
        require(nft.isApprovedForAll(msg.sender, address(this)), "You haven't approved this contract to transfer your ERC1155 token");

        // Transfer ERC1155 token to this contract
        nft.safeTransferFrom(msg.sender, address(this), _tokenId, _amount, "");

        // Mint ERC20 tokens to the sender
        ERC20(erc20Token).transfer(msg.sender, _amount / erc20Rate);

        // Send fee to the fee address
        feeAddress.transfer(FEE_AMOUNT);

        emit NFTLocked(msg.sender, _nftContract, _tokenId, _amount / erc20Rate);
        emit FeePaid(msg.sender, FEE_AMOUNT);
    }

    // Function to withdraw any ETH balance in the contract to the owner
    function withdrawETH() external onlyOwnerOrPaused {
        payable(owner()).transfer(address(this).balance);
    }

    // Function to withdraw any ERC20 balance in the contract to the owner
    function withdrawERC20(address _token) external onlyOwnerOrPaused {
        ERC20(_token).transfer(owner(), address(this).balance);


    }

    // Function to update the fee address
    function updateFeeAddress(address payable _newFeeAddress) external onlyOwner {
        feeAddress = _newFeeAddress;
    }

    // Function to update the ERC20 rate
    function updateERC20Rate(uint256 _newRate) external onlyOwner {
        erc20Rate = _newRate;
    }

    // Function to update the ERC20 token address
    function updateERC20Token(address _newERC20Token) external onlyOwner {
        erc20Token = _newERC20Token;
    }

    // Function to pause the contract
    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    // Function to unpause the contract
    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    // Function to check if the contract is paused
    function isPaused() external view returns (bool) {
        return paused;
    }
}
