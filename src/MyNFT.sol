// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title MyNFT
 */
contract MyNFT is ERC721Enumerable, Ownable, ReentrancyGuard {
    using Strings for uint256;

    string private _baseTokenURI;

    uint256 constant mintFee = 0.0006 ether;

    // fee for referral
    uint256 constant referralDiscountPct = 10;

    // mapping for whitelisted NFT contract addresses
    mapping(address => bool) public whitelistedNFTs;

    // last minted timestamp for each holder of partner NFT
    mapping(address => mapping(address => uint256)) public lastMinted;

    // Tracks the fees earned by referrals for users
    mapping(address => uint256) public referralFeesEarned;

    // Total referral fees that need to be kept in the contract
    uint256 public totalReferralFees;

    // Custom Errors
    error ZeroAddressNotAllowed();
    error NotAnERC721Contract();
    error NFTContractNotWhitelisted();
    error RecipientDoesNotOwnTheNFT();
    error AlreadyMintedToday();
    error ReferralCannotBeSameAsMinter();
    error InsufficientMintFee(uint256 required);
    error NoReferralFeeEarned();

    event WhitelistedNFTAdded(address nftAddress);
    event WhitelistedNFTRemoved(address nftAddress);
    event FeeClaimed(address owner, uint256 amount);
    event Minted(address to, uint256 tokenId, string modelId);
    event FreeMinted(address to, address partnerNFTAddress, uint256 tokenId, string modelId);
    event ReferralFeeClaimed(address referer, uint256 amount);

    /**
     * @dev Initializes the contract by setting a `name`, `symbol` and `baseTokenURI` to the token collection.
     */
    constructor(string memory name, string memory symbol, string memory baseTokenURI) ERC721(name, symbol) {
        _baseTokenURI = baseTokenURI;
    }

    /**
     * @dev Returns the base URI for token metadata.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Sets a new base URI for token metadata.
     * Only the owner can call this function.
     */
    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    /**
     * @dev Returns the full URI for the token metadata for a specified token ID.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json")) : "";
    }

    /**
     * @dev Adds a partner NFT contract address to the whitelist.
     * Only the owner can call this function.
     */
    function addWhitelistedNFT(address nftAddress) external onlyOwner {
        if (nftAddress == address(0)) revert ZeroAddressNotAllowed();

        whitelistedNFTs[nftAddress] = true;
        emit WhitelistedNFTAdded(nftAddress);
    }

    /**
     * @dev Removes a partner NFT contract address from the whitelist.
     * Only the owner can call this function.
     */
    function removeWhitelistedNFT(address nftAddress) external onlyOwner {
        if (nftAddress == address(0)) revert ZeroAddressNotAllowed();

        whitelistedNFTs[nftAddress] = false;
        emit WhitelistedNFTRemoved(nftAddress);
    }

    /**
     * @dev Allows the holder of a partner NFT to mint this NFT for free once per day.
     */
    function partnerFreeMint(address to, address partnerNFTAddress, string memory modelId) external {
        if (!isWhitelistedNFT(partnerNFTAddress)) revert NFTContractNotWhitelisted();

        IERC721 partnerNFT = IERC721(partnerNFTAddress);
        if (partnerNFT.balanceOf(to) == 0) revert RecipientDoesNotOwnTheNFT();
        if (block.timestamp <= lastMinted[to][partnerNFTAddress] + 1 days) revert AlreadyMintedToday();

        uint256 tokenId = totalSupply() + 1;
        _safeMint(to, tokenId);

        lastMinted[to][partnerNFTAddress] = block.timestamp;

        emit FreeMinted(to, partnerNFTAddress, tokenId, modelId);
    }

    /**
     * @dev Mints a new token to the specified address.
     * @param to The address that will receive the minted token.
     * @param referral The address of the referral.
     */
    function mint(address to, address referral, string memory modelId) external payable nonReentrant {
        uint256 requiredMintFee = mintFee;

        // Referral fee is the same as discount. Therefore, if discount rate is 10%,
        // the protocol earns 80% of the original mint price and the referral earns 10%

        if (referral != address(0)) {
            if (referral == to) revert ReferralCannotBeSameAsMinter();

            uint256 discount = (mintFee * referralDiscountPct) / 100;
            requiredMintFee = mintFee - discount;
            uint256 referralFee = discount; // 10% of the reduced mint fee

            if (msg.value != requiredMintFee) revert InsufficientMintFee(requiredMintFee);

            referralFeesEarned[referral] += referralFee;
            totalReferralFees += referralFee;
        } else {
            if (msg.value != mintFee) revert InsufficientMintFee(mintFee);
        }

        uint256 tokenId = totalSupply() + 1;
        _safeMint(to, tokenId);
        emit Minted(to, tokenId, modelId);
    }

    /**
     * @dev Allows the referrer to claim the referral fee.
     */
    function claimReferralFee() external {
        uint256 fee = referralFeesEarned[msg.sender];
        if (fee == 0) revert NoReferralFeeEarned();

        referralFeesEarned[msg.sender] = 0;
        totalReferralFees -= fee;
        (bool success, ) = msg.sender.call{ value: fee }("");
        require(success, "Transfer failed");

        emit ReferralFeeClaimed(msg.sender, fee);
    }

    /**
     * @dev Checks if an NFT contract address is whitelisted.
     */
    function isWhitelistedNFT(address nftAddress) public view returns (bool) {
        return whitelistedNFTs[nftAddress];
    }

    /**
     * @dev Allows the contract owner to claim the collected mint fees.
     * Ensures referral fees are preserved for later claims.
     */
    function claimFee() external onlyOwner {
        uint256 availableBalance = address(this).balance - totalReferralFees;

        (bool success, ) = msg.sender.call{ value: availableBalance }("");
        require(success, "Transfer failed");
        emit FeeClaimed(owner(), availableBalance);
    }

    /**
     * @dev Allows the contract to receive Ether.
     */
    receive() external payable {}

    // Additional functions or overrides can be added here if needed.
}
