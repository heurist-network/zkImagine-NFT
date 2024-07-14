# ZkImagine NFT Smart Contract

## Overview
ZkImagine is an ERC721-based non-fungible token (NFT) smart contract designed for deployment on the zkSync network. This contract includes features such as referral-based minting discounts, partner NFT whitelisting for free mints, signature-based free minting, and secure fee handling.

## Contract Address
[To be filled after deployment]

## Features
- **Standard Minting**: Users can mint new NFTs by paying a mint fee.
- **Referral System**: Referrers can earn a percentage of the mint fee as a reward, and minters get a discount when using a referral.
- **Partner Whitelist**: Allows holders of whitelisted partner NFTs to mint NFTs for free once per day.
- **Signature-Based Free Minting**: Allows free minting based on owner-signed messages.
- **Secure Fee Handling**: Referral fees are tracked and preserved, ensuring users can claim their earned fees.
- **Owner Functions**: The contract owner can manage the base URI, add/remove whitelisted NFTs, and claim accumulated fees.

## Contract Details

### Key Functions

#### Minting
1. `mint(address to, address referral, string memory modelId, string memory imageId) external payable nonReentrant`
   - Standard minting function with optional referral.
   - Applies referral discount if a valid referral is provided.

2. `partnerFreeMint(address to, address partnerNFTAddress, string memory modelId, string memory imageId) external`
   - Allows free minting for holders of whitelisted partner NFTs.
   - Limited to once per 24 hours per partner NFT.

3. `signatureFreeMint(bytes32 hash, bytes memory signature, string memory modelId, string memory imageId) external`
   - Allows free minting based on owner-signed messages to specify the minter address same as the msg.sender.
   - Limited to once per 24 hours per signature.


### State Variables
- `string private _baseTokenURI`: Base URI for token metadata.
- `uint256 constant mintFee`: Fixed mint fee (0.0006 ether).
- `uint256 constant referralDiscountPct`: Referral discount percentage (10%).
- `mapping(address => bool) public whitelistedNFTs`: Tracks whitelisted NFT contract addresses.
- `mapping(address => mapping(address => uint256)) public lastMinted`: Tracks the last minted timestamp for each holder of partner NFTs.
- `mapping(bytes => uint256) public lastSignatureUsed`: Tracks the last used timestamp for each signature.
- `mapping(address => uint256) public referralFeesEarned`: Tracks the fees earned by referrals.
- `uint256 public totalReferralFees`: Total referral fees accumulated in the contract.

### Events
- `WhitelistedNFTAdded(address nftAddress)`
- `WhitelistedNFTRemoved(address nftAddress)`
- `FeeClaimed(address owner, uint256 amount)`
- `Minted(address to, uint256 tokenId, string modelId, string imageId)`
- `PartnerFreeMint(address to, address partnerNFTAddress, uint256 tokenId, string modelId, string imageId)`
- `ReferralFeeClaimed(address referer, uint256 amount)`
- `SignatureFreeMint(address to, uint256 tokenId, string modelId, string imageId)`



#### Whitelist Management
- `addWhitelistedNFT(address nftAddress) external onlyOwner`
- `removeWhitelistedNFT(address nftAddress) external onlyOwner`

#### Fee Management
- `claimReferralFee() external` for referrers
- `claimFee() external onlyOwner` for the contract owner

#### Utility Functions
- `setBaseURI(string calldata baseURI) external onlyOwner`
- `tokenURI(uint256 tokenId) public view virtual override returns (string memory)`
- `isWhitelistedNFT(address nftAddress) public view returns (bool)`

### Security Considerations
- Uses OpenZeppelin's `ReentrancyGuard` for protection against reentrancy attacks.
- Implements checks to prevent self-referrals and duplicate minting within time limits.
- Uses `onlyOwner` modifier for sensitive operations.
- Implements signature verification for free minting to prevent unauthorized use.

## Development and Testing
- **Local Testing**: 
  Start the in-memory node: `yarn hardhat node-zksync`
  Run tests: `yarn hardhat test --network inMemoryNode`
- **Compilation**: 
  Always run `bun run clean` and `bun run compile` before deploying

## Deployment
- **Network**: Designed for deployment on the zkSync network

- **Deployment Script**: `deployZkImagine.ts` on testnet 
`npx hardhat deploy-zksync --script deployZkImagine.ts --network zkSyncSepoliaTestnet`
## License
This project is licensed under the MIT License.