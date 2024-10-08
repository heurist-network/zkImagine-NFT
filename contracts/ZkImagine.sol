// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

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
 * @title zkImagine
 */
contract zkImagine is
    Initializable,
    ERC721EnumerableUpgradeable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using Strings for uint256;

    /// STORAGE ///
    string private _baseTokenURI;

    uint256 public mintFee;

    // fee discount for referral mint
    uint256 public referralDiscountPct;

    // free mint cooldown window
    uint256 public freeMintCooldownWindow;

    // Counter for Token IDs
    uint256 private _tokenIdCounter; // New counter for Token IDs

    // mapping for whitelisted NFT contract addresses
    mapping(address => bool) public whitelistedNFTs;

    // next minted timestamp for each token id of partner NFT
    mapping(address => mapping(uint256 => uint256)) public nextMint;

    // next minted timestamp for each signature
    mapping(bytes => uint256) public nextSignatureMint;

    // Tracks the fees earned by referrals for users
    mapping(address => uint256) public referralFeesEarned;

    // Total referral fees that need to be kept in the contract
    uint256 public totalReferralFees;

    // global time threshold for free mint
    uint256 public globalTimeThreshold;

    // signature signer address
    address public signer;

    // gap for upgradeability
    uint256[128] __gap;

    /// STRUCT ///
    struct MintStatus {
        bool canMint;
        string reason;
    }

    /// EVENT ///
    event WhitelistedNFTAdded(address nftAddress);
    event WhitelistedNFTRemoved(address nftAddress);
    event FeeClaimed(address owner, uint256 amount);
    event Minted(address to, address referral, uint256 tokenId, string modelId, string imageId);
    event PartnerFreeMint(
        address to,
        address partnerNFTAddress,
        uint256 partnerNFTtokenId,
        uint256 tokenId,
        string modelId,
        string imageId
    );
    event ReferralFeeClaimed(address referer, uint256 amount);
    event SignatureFreeMint(address to, uint256 tokenId, string modelId, string imageId);
    event MintFeeChanged(uint256 fee);
    event ReferralDiscountChanged(uint256 discount);
    event FreeMintCooldownWindowChanged(uint256 cooldownWindow);
    event BaseURIChanged(string baseURI);
    event SignerChanged(address signer);

    using SignatureChecker for address;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initialize functions for upgradeable contract.
     */

    function initialize(
        string memory name,
        string memory symbol,
        string memory baseTokenURI,
        uint256 mint_fee,
        uint256 referralDiscount,
        uint256 cooldownWindow,
        uint256 startTimestamp,
        address _signer
    ) public initializer {
        __ERC721_init(name, symbol);
        __Ownable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _beforeIntialize(baseTokenURI, mint_fee, referralDiscount, cooldownWindow, startTimestamp);

        _baseTokenURI = baseTokenURI;
        mintFee = mint_fee;
        referralDiscountPct = referralDiscount;
        freeMintCooldownWindow = cooldownWindow;
        globalTimeThreshold = startTimestamp + cooldownWindow;
        signer = _signer;
    }

    /// BASE URI ///
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
        emit BaseURIChanged(baseURI);
    }

    /// WHITELIST OPERATIONS ///

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

    /// MINT OPERATIONS ///

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
        _incrementTokenId();
        _safeMint(to, tokenId);

        emit Minted(to, referral, tokenId, modelId, imageId);
    }

    /**
     * @dev Allows the holder of a partner NFT to mint this NFT for free once per globalTimeThreshold.
     */
    function partnerFreeMint(
        address to,
        address partnerNFTAddress,
        uint256 partnerNFTtokenId,
        string memory modelId,
        string memory imageId
    ) external nonReentrant {
        MintStatus memory status = canMintForPartnerNFT(to, partnerNFTAddress, partnerNFTtokenId);
        require(status.canMint, status.reason);

        _updateGlobalTimeThreshold();
        nextMint[partnerNFTAddress][partnerNFTtokenId] = globalTimeThreshold;

        uint256 tokenId = _getNextTokenId();
        _incrementTokenId();
        _safeMint(to, tokenId);

        emit PartnerFreeMint(to, partnerNFTAddress, partnerNFTtokenId, tokenId, modelId, imageId);
    }

    /**
     * @dev Allows the owner to mint a token for free using a signature.
     */
    function signatureFreeMint(
        address to,
        bytes32 hash,
        bytes memory signature,
        string memory modelId,
        string memory imageId
    ) external nonReentrant {
        MintStatus memory status = canMintForSignature(hash, signature,to);
        require(status.canMint, status.reason);

        _updateGlobalTimeThreshold();

        nextSignatureMint[signature] = globalTimeThreshold;

        uint256 tokenId = _getNextTokenId();
        _incrementTokenId();
        _safeMint(to, tokenId);

        emit SignatureFreeMint(to, tokenId, modelId, imageId);
    }

    /**
     * @dev Checks if an NFT contract address is whitelisted.
     */
    function isWhitelistedNFT(address nftAddress) public view returns (bool) {
        return whitelistedNFTs[nftAddress];
    }

    /// CLAIM OPERATIONS ///

    /**
     * @dev Allows the referrer to claim the referral fee.
     */
    function claimReferralFee() external nonReentrant {
        uint256 fee = referralFeesEarned[msg.sender];
        require(fee > 0, "No referral fee earned");

        referralFeesEarned[msg.sender] = 0;
        totalReferralFees -= fee;
        (bool success, ) = msg.sender.call{ value: fee }("");
        require(success, "Transfer failed");

        emit ReferralFeeClaimed(msg.sender, fee);
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

    /// HELPER FUNCTIONS ///
    function _recoverSigner(bytes32 _hash, bytes memory _signature, address _signer) internal view returns (bool) {
        bytes32 messageDigest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _hash));
        return _signer.isValidSignatureNow(messageDigest, _signature);
    }

    // check if address can mint for partner NFT
    function canMintForPartnerNFT(
        address to,
        address partnerNFTAddress,
        uint256 tokenId
    ) public view returns (MintStatus memory) {
        if (!isWhitelistedNFT(partnerNFTAddress)) {
            return MintStatus(false, "NFT contract not whitelisted");
        }

        IERC721 partnerNFT = IERC721(partnerNFTAddress);
        if (partnerNFT.ownerOf(tokenId) != to) {
            return MintStatus(false, "Recipient does not own the token id of NFT");
        }

        if (!checkValidTime(nextMint[partnerNFTAddress][tokenId])) {
            return MintStatus(false, "Next mint time not reached for the token id");
        }

        return MintStatus(true, "");
    }

    // check if address can mint for signature
    function canMintForSignature(bytes32 hash, bytes memory signature, address minter) public view returns (MintStatus memory) {
        if (hash != keccak256(abi.encodePacked(minter))) {
            return MintStatus(false, "Invalid hash");
        }

        if (!_recoverSigner(hash, signature, signer)) {
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

    function _beforeIntialize(
        string memory baseTokenURI,
        uint256 mint_fee,
        uint256 referralDiscount,
        uint256 cooldownWindow,
        uint256 startTimestamp
    ) internal pure {
        require(bytes(baseTokenURI).length > 0, "Base URI is empty");
        require(mint_fee > 0, "Mint fee must be greater than 0");
        require(referralDiscount >= 0 && referralDiscount <= 100, "Referral discount must be between 0 and 100");
        require(cooldownWindow > 0, "Cooldown window must be greater than 0");
        require(startTimestamp > 0, "Start timestamp must be greater than 0");
    }

    function _updateGlobalTimeThreshold() internal {
        // triggered by user free mint
        if (block.timestamp > globalTimeThreshold) {
            // Calculate the number of periods that have passed
            uint256 periodsPassed = (block.timestamp - globalTimeThreshold) / freeMintCooldownWindow;

            // Add one more period to ensure it's greater than the current timestamp
            periodsPassed++;

            // Update the globalTimeThreshold in one step
            globalTimeThreshold += periodsPassed * freeMintCooldownWindow;
        }
    }

    function _incrementTokenId() private {
        _tokenIdCounter++;
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
     * @dev Allows the contract to receive Ether.
     */
    receive() external payable {}

    /// SETTER FUNCTIONS ///

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

    function setSigner(address _signer) external onlyOwner {
        require(_signer != address(0), "Zero address not allowed");
        signer = _signer;
        emit SignerChanged(_signer);
    }

    /// GETTER FUNCTIONS ///
    function getDiscountedMintFee() public view returns (uint256, uint256) {
        uint256 discount = (mintFee * referralDiscountPct) / 100; // 10% discount -> 0.0006 * 10 / 100 = 0.00006
        return (mintFee - discount, discount);
    }

    function _getNextTokenId() private view returns (uint256) {
        return _tokenIdCounter + 1;
    }

    /// ONWER FUNCTIONS ///
    function renounceOwnership() public view override onlyOwner {
        revert("renounceOwnership is disabled");
    }

    // Ensure that only the owner can upgrade the contract
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
