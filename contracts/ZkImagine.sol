// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title ZkImagine
 */
contract ZkImagine is ERC721Enumerable, Ownable, ReentrancyGuard {
    using Strings for uint256;

    string private _baseTokenURI;

    uint256 constant mintFee = 0.0006 ether;

    // fee for referral
    uint256 constant referralDiscountPct = 10;

    // mapping for whitelisted NFT contract addresses
    mapping(address => bool) public whitelistedNFTs;

    // last minted timestamp for each holder of partner NFT
    mapping(address => mapping(address => uint256)) public lastMinted;

    // last minted timestamp for each signature
    mapping(bytes => uint256) public lastSignatureUsed;

    // Tracks the fees earned by referrals for users
    mapping(address => uint256) public referralFeesEarned;

    // Total referral fees that need to be kept in the contract
    uint256 public totalReferralFees;

    event WhitelistedNFTAdded(address nftAddress);
    event WhitelistedNFTRemoved(address nftAddress);
    event FeeClaimed(address owner, uint256 amount);
    event Minted(address to, uint256 tokenId, string modelId, string imageId);
    event PartnerFreeMint(address to, address partnerNFTAddress, uint256 tokenId, string modelId, string imageId);
    event ReferralFeeClaimed(address referer, uint256 amount);
    event SignatureFreeMint(address to, uint256 tokenId, string modelId, string imageId);

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
        require(nftAddress != address(0), "Zero address not allowed");

        whitelistedNFTs[nftAddress] = true;
        emit WhitelistedNFTAdded(nftAddress);
    }

    /**
     * @dev Removes a partner NFT contract address from the whitelist.
     * Only the owner can call this function.
     */
    function removeWhitelistedNFT(address nftAddress) external onlyOwner {
        require(nftAddress != address(0), "Zero address not allowed");

        whitelistedNFTs[nftAddress] = false;
        emit WhitelistedNFTRemoved(nftAddress);
    }

    /**
     * @dev Allows the holder of a partner NFT to mint this NFT for free once per day.
     */
    function partnerFreeMint(
        address to,
        address partnerNFTAddress,
        string memory modelId,
        string memory imageId
    ) external {
        require(isWhitelistedNFT(partnerNFTAddress), "NFT contract not whitelisted");
        IERC721 partnerNFT = IERC721(partnerNFTAddress);
        require(partnerNFT.balanceOf(to) > 0, "Recipient does not own the NFT");


        require(
            lastMinted[to][partnerNFTAddress] == 0 || block.timestamp > (lastMinted[to][partnerNFTAddress] + 1 days),
            "Already minted today"
        );


        uint256 tokenId = totalSupply() + 1;
        _safeMint(to, tokenId);

        lastMinted[to][partnerNFTAddress] = block.timestamp;

        emit PartnerFreeMint(to, partnerNFTAddress, tokenId, modelId, imageId);
    }

    /**
     * @dev Mints a new token to the specified address.
     * @param to The address that will receive the minted token.
     * @param referral The address of the referral.
     */
    function mint(
        address to,
        address referral,
        string memory modelId,
        string memory imageId
    ) external payable nonReentrant {
        uint256 requiredMintFee = mintFee;

        // Referral fee is the same as discount. Therefore, if discount rate is 10%,
        // the protocol earns 80% of the original mint price and the referral earns 10%

        if (referral != address(0)) {
            require(referral != to, "Referral cannot be same as minter");

            uint256 discount = (mintFee * referralDiscountPct) / 100; // 10% discount -> 0.0006 * 10 / 100 = 0.00006
            requiredMintFee = mintFee - discount; // = 0.00054
            uint256 referralFee = discount; // 10% of the reduced mint fee

            require(msg.value == requiredMintFee, "Insufficient mint fee");

            referralFeesEarned[referral] += referralFee;
            totalReferralFees += referralFee;
        } else {
            require(msg.value == mintFee, "Insufficient mint fee");
        }

        uint256 tokenId = totalSupply() + 1;
        _safeMint(to, tokenId);
        emit Minted(to, tokenId, modelId, imageId);
    }

    /**
     * @dev Allows the owner to mint a token for free using a signature.
     */
    function signatureFreeMint(
        bytes32 hash,
        bytes memory signature,
        string memory modelId,
        string memory imageId
    ) external {
        require(hash == keccak256(abi.encodePacked(msg.sender)), "Invalid hash");
        require(_recoverSigner(hash, signature) == owner(), "Invalid signature");
        require(lastSignatureUsed[signature] == 0 || block.timestamp > lastSignatureUsed[signature] + 1 days, "Already minted today");

        lastSignatureUsed[signature] = block.timestamp;

        uint256 tokenId = totalSupply() + 1;
        _safeMint(msg.sender, tokenId);

        emit SignatureFreeMint(msg.sender, tokenId, modelId, imageId);
    }

    /**
     * @dev Allows the referrer to claim the referral fee.
     */
    function claimReferralFee() external {
        uint256 fee = referralFeesEarned[msg.sender];
        require(fee > 0, "No referral fee earned");

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

    function _recoverSigner(bytes32 hash, bytes memory signature) internal pure returns (address) {
        bytes32 messageDigest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
        return ECDSA.recover(messageDigest, signature);
    }

    /**
     * @dev Allows the contract to receive Ether.
     */
    receive() external payable {}

    // Additional functions or overrides can be added here if needed.
}
