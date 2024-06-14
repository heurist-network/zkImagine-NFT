# zkImagine-NFT Smart Contract

## Overview
zkImagine-NFT is an ERC721-based non-fungible token (NFT) smart contract designed for deployment on the ZKsync layer 2 scaling solution for Ethereum. This contract includes features such as referral-based minting discounts, partner NFT whitelisting, and secure fee handling.

## Features
- **Minting**: Users can mint new NFTs by paying a mint fee.
- **Referral System**: Referrers can earn a percentage of the mint fee as a reward, and minters get a discount when using a referral.
- **Partner Whitelist**: Allows holders of partner NFTs to mint NFTs for free once per day.
- **Secure Fee Handling**: Referral fees are tracked and preserved, ensuring users can claim their earned fees even if the contract owner withdraws other funds.
- **Owner Functions**: The contract owner can manage the base URI, add/remove whitelisted NFTs, and claim mint fees.

## Deployment
This contract is designed for deployment on the ZKsync network.

## Contract Details

### State Variables
- `string private _baseTokenURI`: Base URI for token metadata.
- `uint256 constant mintFee`: Fixed mint fee (0.0005 ether).
- `uint256 constant referralDiscountPct`: Referral discount percentage (10%).
- `mapping(address => bool) public whitelistedNFTs`: Tracks whitelisted NFT contract addresses.
- `mapping(address => mapping(address => uint256)) public lastMinted`: Tracks the last minted timestamp for each holder of partner NFTs.
- `mapping(address => uint256) public referralFeesEarned`: Tracks the fees earned by referrals.
- `uint256 public totalReferralFees`: Total referral fees that need to be kept in the contract.

### Events
- `event WhitelistedNFTAdded(address nftAddress)`: Emitted when an NFT contract is added to the whitelist.
- `event WhitelistedNFTRemoved(address nftAddress)`: Emitted when an NFT contract is removed from the whitelist.
- `event FeeClaimed(address owner, uint256 amount)`: Emitted when mint or referral fees are claimed.
- `event Minted(address to, uint256 tokenId)`: Emitted when a new token is minted.
- `event ReferralFeeClaimed(address referer, uint256 amount)`: Emitted when a referral fee is claimed.

### Functions

#### Constructor
```solidity
constructor(string memory name, string memory symbol, string memory baseTokenURI) ERC721(name, symbol) {
    _baseTokenURI = baseTokenURI;
}
```
Initializes the contract with the token name, symbol, and base URI.

#### Minting Functions

##### `mint`
```solidity
function mint(address to, address referral) external payable nonReentrant
```
Mints a new token to the specified address. Applies a referral discount if a valid referral address is provided.

##### `partnerFreeMint`
```solidity
function partnerFreeMint(address to, address partnerNFTAddress) external
```
Allows holders of a whitelisted partner NFT to mint this NFT for free once per day.

#### Whitelist Management

##### `addWhitelistedNFT`
```solidity
function addWhitelistedNFT(address nftAddress) external onlyOwner
```
Adds a partner NFT contract address to the whitelist.

##### `removeWhitelistedNFT`
```solidity
function removeWhitelistedNFT(address nftAddress) external onlyOwner
```
Removes a partner NFT contract address from the whitelist.

#### Fee Management

##### `claimReferralFee`
```solidity
function claimReferralFee() external
```
Allows users to claim their earned referral fees.

##### `claimFee`
```solidity
function claimFee() external onlyOwner
```
Allows the contract owner to claim the collected mint fees, ensuring referral fees are preserved for later claims.

### Utility Functions

##### `setBaseURI`
```solidity
function setBaseURI(string calldata baseURI) external onlyOwner
```
Sets a new base URI for token metadata.

##### `tokenURI`
```solidity
function tokenURI(uint256 tokenId) public view virtual override returns (string memory)
```
Returns the full URI for the token metadata for a specified token ID.

##### `isERC721`
```solidity
function isERC721(address addr) internal returns (bool)
```
Checks if an address supports the ERC721 interface.

##### `isWhitelistedNFT`
```solidity
function isWhitelistedNFT(address nftAddress) public view returns (bool)
```
Checks if an NFT contract address is whitelisted.

## Custom Errors
- `error ZeroAddressNotAllowed()`
- `error NotAnERC721Contract()`
- `error NFTContractNotWhitelisted()`
- `error RecipientDoesNotOwnTheNFT()`
- `error AlreadyMintedToday()`
- `error ReferralCannotBeSameAsMinter()`
- `error InsufficientMintFee(uint256 required)`
- `error NoReferralFeeEarned()`

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.