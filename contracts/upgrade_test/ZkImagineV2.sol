// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/*

██╗░░██╗███████╗██╗░░░██╗██████╗░██╗░██████╗████████╗
██║░░██║██╔════╝██║░░░██║██╔══██╗██║██╔════╝╚══██╔══╝
███████║█████╗░░██║░░░██║██████╔╝██║╚█████╗░░░░██║░░░
██╔══██║██╔══╝░░██║░░░██║██╔══██╗██║░╚═══██╗░░░██║░░░
██║░░██║███████╗╚██████╔╝██║░░██║██║██████╔╝░░░██║░░░
╚═╝░░╚═╝╚══════╝░╚═════╝░╚═╝░░╚═╝╚═╝╚═════╝░░░░╚═╝░░░

███████╗██╗░░██╗██╗███╗░░░███╗░█████╗░░██████╗░██╗███╗░░██╗███████╗
╚════██║██║░██╔╝██║████╗░████║██╔══██╗██╔════╝░██║████╗░██║██╔════╝
░░███╔═╝█████═╝░██║██╔████╔██║███████║██║░░██╗░██║██╔██╗██║█████╗░░
██╔══╝░░██╔═██╗░██║██║╚██╔╝██║██╔══██║██║░░╚██╗██║██║╚████║██╔══╝░░
███████╗██║░╚██╗██║██║░╚═╝░██║██║░░██║╚██████╔╝██║██║░╚███║███████╗
╚══════╝╚═╝░░╚═╝╚═╝╚═╝░░░░░╚═╝╚═╝░░╚═╝░╚═════╝░╚═╝╚═╝░░╚══╝╚══════╝

*/

/**
 * @title ZkImagine
 */
contract ZkImagineV2 is
    Initializable,
    ERC721EnumerableUpgradeable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using Strings for uint256;

    string private _baseTokenURI;

    uint256 public mintFee;

    // fee for referral
    uint256 public referralDiscountPct;

    // free mint cooldown window
    uint256 public freeMintCooldownWindow;

    // Counter for Token IDs
    uint256 private _tokenIdCounter; // New counter for Token IDs

    // mapping for whitelisted NFT contract addresses
    mapping(address => bool) public whitelistedNFTs;

    // last minted timestamp for each holder of partner NFT
    mapping(address => mapping(address => uint256)) public nextMint;

    // last minted timestamp for each signature
    mapping(bytes => uint256) public nextSignatureMint;

    // Tracks the fees earned by referrals for users
    mapping(address => uint256) public referralFeesEarned;

    // Total referral fees that need to be kept in the contract
    uint256 public totalReferralFees;

    uint256 public globalTimeThreshold;

    struct MintStatus {
        bool canMint;
        string reason;
    }

    event WhitelistedNFTAdded(address nftAddress);
    event WhitelistedNFTRemoved(address nftAddress);
    event FeeClaimed(address owner, uint256 amount);
    event Minted(address to, address referral, uint256 tokenId, string modelId, string imageId);
    event PartnerFreeMint(address to, address partnerNFTAddress, uint256 tokenId, string modelId, string imageId);
    event ReferralFeeClaimed(address referer, uint256 amount);
    event SignatureFreeMint(address to, uint256 tokenId, string modelId, string imageId);
    event MintFeeChanged(uint256 fee);
    event ReferralDiscountChanged(uint256 discount);
    event FreeMintCooldownWindowChanged(uint256 cooldownWindow);

    /**
     * @dev Initializes the contract by setting a `name`, `symbol` and `baseTokenURI` to the token collection.
     */
    // constructor(
    //     string memory name,
    //     string memory symbol,
    //     string memory baseTokenURI,
    //     uint256 mint_fee,
    //     uint256 referralDiscount,
    //     uint256 cooldownWindow,
    //     uint256 startTimestamp
    // ) ERC721(name, symbol) {
    //     _baseTokenURI = baseTokenURI;
    //     mintFee = mint_fee;
    //     referralDiscountPct = referralDiscount;
    //     freeMintCooldownWindow = cooldownWindow;
    //     globalTimeThreshold = startTimestamp + cooldownWindow;
    // }

    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    function initialize(
        string memory name,
        string memory symbol,
        string memory baseTokenURI,
        uint256 mint_fee,
        uint256 referralDiscount,
        uint256 cooldownWindow,
        uint256 startTimestamp
    ) public initializer {
        __ERC721_init(name, symbol);
        __Ownable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _baseTokenURI = baseTokenURI;
        mintFee = mint_fee;
        referralDiscountPct = referralDiscount;
        freeMintCooldownWindow = cooldownWindow;
        globalTimeThreshold = startTimestamp + cooldownWindow;
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
        MintStatus memory status = canMintForPartnerNFT(to, partnerNFTAddress);
        require(status.canMint, status.reason);

        _updateGlobalTimeThreshold();
        nextMint[to][partnerNFTAddress] = globalTimeThreshold;

        uint256 tokenId = _getNextTokenId();
        _safeMint(to, tokenId);
        _incrementTokenId();

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

        if (referral == address(0) || referral == to) {
            require(msg.value == mintFee, "Insufficient mint fee");
        } else {
            uint256 discount;
            (requiredMintFee, discount) = getDiscountedMintFee();
            uint256 referralFee = discount; // 10% of the reduced mint fee

            require(msg.value == requiredMintFee, "Insufficient mint fee");

            referralFeesEarned[referral] += referralFee;
            totalReferralFees += referralFee;
        }

        uint256 tokenId = _getNextTokenId();
        _safeMint(to, tokenId);
        _incrementTokenId();
        emit Minted(to, referral, tokenId, modelId, imageId);
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
        // require(canMintForSignature(hash, signature), "Already minted today");
        MintStatus memory status = canMintForSignature(hash, signature);
        require(status.canMint, status.reason);

        _updateGlobalTimeThreshold();

        nextSignatureMint[signature] = globalTimeThreshold;

        // uint256 tokenId = totalSupply() + 1;
        uint256 tokenId = _getNextTokenId();
        _safeMint(msg.sender, tokenId);
        _incrementTokenId();

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

    // check if address can mint for partner NFT
    function canMintForPartnerNFT(address to, address partnerNFTAddress) public view returns (MintStatus memory) {
        if (!isWhitelistedNFT(partnerNFTAddress)) {
            return MintStatus(false, "NFT contract not whitelisted");
        }

        IERC721 partnerNFT = IERC721(partnerNFTAddress);
        if (partnerNFT.balanceOf(to) == 0) {
            return MintStatus(false, "Recipient does not own the NFT");
        }

        if (!checkValidTime(nextMint[to][partnerNFTAddress])) {
            return MintStatus(false, "Next mint time not reached");
        }

        return MintStatus(true, "");
    }

    // check if address can mint for signature
    function canMintForSignature(bytes32 hash, bytes memory signature) public view returns (MintStatus memory) {
        if (hash != keccak256(abi.encodePacked(msg.sender))) {
            return MintStatus(false, "Invalid hash");
        }

        if (_recoverSigner(hash, signature) != owner()) {
            return MintStatus(false, "Invalid signature");
        }

        if (!checkValidTime(nextSignatureMint[signature])) {
            return MintStatus(false, "Next signature mint time not reached");
        }

        return MintStatus(true, "");
    }

    function checkValidTime(uint256 userNextTimestamp) internal view returns (bool) {
        // triggered by user free mint

        if (block.timestamp > userNextTimestamp) {
            return true;
        }

        return false;
    }

    function _updateGlobalTimeThreshold() internal {
        // triggered by user free mint
        if (block.timestamp > globalTimeThreshold) {
            // update the globalTimeThreshold with multiple of freeMintCooldownWindow until it is greater than block.timestamp
            while (block.timestamp > globalTimeThreshold) {
                globalTimeThreshold += freeMintCooldownWindow;
            }
        }
    }

    /**
     * @dev Allows the contract to receive Ether.
     */
    receive() external payable {}

    // Additional functions or overrides can be added here if needed.
    function setMintFee(uint256 fee) external onlyOwner {
        require(fee > 0, "Fee must be greater than 0");
        mintFee = fee;
        emit MintFeeChanged(fee);
    }

    function setReferralDiscountPct(uint256 discount) external onlyOwner {
        require(discount >= 0 && discount <= 100, "must between 0 and 100");
        referralDiscountPct = discount;
        emit ReferralDiscountChanged(discount);
    }

    function setFreeMintCooldownWindow(uint256 cooldownWindow) external onlyOwner {
        require(cooldownWindow > 0, "Cooldown window must be greater than 0");
        freeMintCooldownWindow = cooldownWindow;
        emit FreeMintCooldownWindowChanged(cooldownWindow);
    }

    function getDiscountedMintFee() public view returns (uint256, uint256) {
        uint256 discount = (mintFee * referralDiscountPct) / 100; // 10% discount -> 0.0006 * 10 / 100 = 0.00006
        return (mintFee - discount, discount);
    }

    function _getNextTokenId() private view returns (uint256) {
        return _tokenIdCounter + 1;
    }

    function _incrementTokenId() private {
        _tokenIdCounter++;
    }

    function testUpgrade() external pure returns (string memory) {
        return "Upgraded";
    }

    // Ensure that only the owner can upgrade the contract
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
