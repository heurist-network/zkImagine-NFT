// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title PartnerNFT
 * @dev Basic ERC721 token with auto-incrementing token IDs.
 * The owner can mint new tokens. Token URIs are autogenerated based on a base URI.
 */
contract MockPartnerNFT is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdTracker;
    string private _baseTokenURI;

    constructor(string memory name, string memory symbol, string memory baseTokenURI) ERC721(name, symbol) {
        _baseTokenURI = baseTokenURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Mints a new token to the specified address.
     * Only the owner can mint new tokens.
     * @param to The address that will receive the minted token.
     */
    function mint(address to) external onlyOwner {
        _tokenIdTracker.increment();
        _mint(to, _tokenIdTracker.current());
    }


    // Additional functions or overrides can be added here if needed.
}