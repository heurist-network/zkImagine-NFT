# ZkImagine NFT Smart Contract

## Overview
ZkImagine is an upgradeable ERC721-based non-fungible token (NFT) smart contract. This contract includes features such as referral-based minting discounts, partner NFT whitelisting for free mints, signature-based free minting, and secure fee handling.

## Contract Address
[To be filled after deployment]

## Features
- **Standard Minting**: Users can mint new NFTs by paying a mint fee.
- **Referral System**: Referrers can earn a percentage of the mint fee as a reward, and minters get a discount when using a referral.
- **Partner Whitelist**: Allows holders of whitelisted partner NFTs to mint NFTs for free once per global time threshold for each partner NFT collection hold.
- **Signature-Based Free Minting**: Allows free minting based on owner-signed messages.
- **Secure Fee Handling**: Referral fees are tracked and preserved, ensuring users can claim their earned fees.
- **Owner Functions**: The contract owner can manage the base URI, add/remove whitelisted NFTs, claim accumulated fees, and adjust various parameters.
- **Upgradeable**: The contract is designed to be upgradeable using the UUPS pattern.

## Contract Details

### Key Functions

#### Initialization
- `initialize(string memory name, string memory symbol, string memory baseTokenURI, uint256 mint_fee, uint256 referralDiscount, uint256 cooldownWindow, uint256 startTimestamp) public initializer`
  - Initializes the contract with the given parameters.

#### Minting
1. `mint(address to, address referral, string memory modelId, string memory imageId) external payable nonReentrant`
   - Standard minting function with optional referral.
   - Applies referral discount if a valid referral is provided.

2. `partnerFreeMint(address to, address partnerNFTAddress, string memory modelId, string memory imageId) external`
   - Allows free minting for holders of whitelisted partner NFTs.
   - Limited by the global time threshold.

3. `signatureFreeMint(bytes32 hash, bytes memory signature, string memory modelId, string memory imageId) external`
   - Allows free minting based on owner-signed messages.
   - Limited by the global time threshold.

### State Variables
- `string private _baseTokenURI`: Base URI for token metadata.
- `uint256 public mintFee`: Current mint fee.
- `uint256 public referralDiscountPct`: Current referral discount percentage.
- `uint256 public freeMintCooldownWindow`: Cooldown window for free mints.
- `uint256 public globalTimeThreshold`: Global time threshold for free mints.
- `mapping(address => bool) public whitelistedNFTs`: Tracks whitelisted NFT contract addresses.
- `mapping(address => mapping(address => uint256)) public nextMint`: Tracks the next allowed mint timestamp for each holder of partner NFTs.
- `mapping(bytes => uint256) public nextSignatureMint`: Tracks the next allowed mint timestamp for each signature.
- `mapping(address => uint256) public referralFeesEarned`: Tracks the fees earned by referrals.
- `uint256 public totalReferralFees`: Total referral fees accumulated in the contract.

### Events
- `WhitelistedNFTAdded(address nftAddress)`
- `WhitelistedNFTRemoved(address nftAddress)`
- `FeeClaimed(address owner, uint256 amount)`
- `Minted(address to, address referral, uint256 tokenId, string modelId, string imageId)`
- `PartnerFreeMint(address to, address partnerNFTAddress, uint256 tokenId, string modelId, string imageId)`
- `ReferralFeeClaimed(address referer, uint256 amount)`
- `SignatureFreeMint(address to, uint256 tokenId, string modelId, string imageId)`
- `MintFeeChanged(uint256 fee)`
- `ReferralDiscountChanged(uint256 discount)`
- `FreeMintCooldownWindowChanged(uint256 cooldownWindow)`

### Whitelist Management
- `addWhitelistedNFT(address nftAddress) external onlyOwner`
- `removeWhitelistedNFT(address nftAddress) external onlyOwner`

### Fee Management
- `claimReferralFee() external` for referrers
- `claimFee() external onlyOwner` for the contract owner

### Parameter Management
- `setMintFee(uint256 fee) external onlyOwner`
- `setReferralDiscountPct(uint256 discount) external onlyOwner`
- `setFreeMintCooldownWindow(uint256 cooldownWindow) external onlyOwner`

### Utility Functions
- `setBaseURI(string calldata baseURI) external onlyOwner`
- `tokenURI(uint256 tokenId) public view virtual override returns (string memory)`
- `isWhitelistedNFT(address nftAddress) public view returns (bool)`
- `getDiscountedMintFee() public view returns (uint256, uint256)`
- `canMintForPartnerNFT(address to, address partnerNFTAddress) public view returns (MintStatus memory)`
- `canMintForSignature(bytes32 hash, bytes memory signature) public view returns (MintStatus memory)`

## Upgrades
The contract uses the UUPS (Universal Upgradeable Proxy Standard) pattern for upgrades. Only the contract owner can authorize upgrades.

## Security Considerations
- The contract uses OpenZeppelin's ReentrancyGuard to prevent reentrancy attacks.
- Free mints are rate-limited using a global time threshold mechanism.
- The contract owner has significant control over the contract parameters and can upgrade the contract. Users should trust the contract owner.

## Note
This README provides an overview of the main features and functions of the ZkImagine NFT contract. For detailed implementation and usage, please refer to the contract source code and comments.


## Development and Testing
- **Local Testing**: 
  Start the in-memory node: `yarn hardhat node-zksync`
  Run tests: `yarn hardhat test --network inMemoryNode`
- **Compilation**: 
  Always run `bun run clean` and `bun run compile` before deploying

## Deployment
- **Network**: Designed for deployment on the zkSync network

- **Deployment Script**:

- deploy uups upgradeable contract
`npx hardhat deploy-zksync --script deployZkImagineUUPS.ts --network zkSyncSepoliaTestnet`

- verify contract 
` npx hardhat verify <contract>`

- example for upgrade contract
`npx hardhat deploy-zksync --script upgradeUUPSZkImagine.ts --network zkSyncSepoliaTestnet`
## License
This project is licensed under the MIT License.