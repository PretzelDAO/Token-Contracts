// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

import "../../interfaces/Polygon/IChildMintableERC721.sol";

contract SugarPretzels is
    ERC721,
    ERC721Enumerable,
    IChildMintableERC721,
    Ownable,
    ERC2771Context
{
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    string public baseURI = "";
    mapping(address => bool) public hasMinted;

    constructor(address trustedForwarder)
        ERC721("SugarPretzels", "SPS")
        ERC2771Context(trustedForwarder)
    {}

    function safeMint() external {
        require(
            !hasMinted[_msgSender()],
            "Only one mint per wallet is allowed."
        );

        hasMinted[_msgSender()] = true;
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // interactions
        _safeMint(_msgSender(), tokenId);
    }

    function setBaseURI(string calldata uri) external onlyOwner {
        baseURI = uri;
    }

    // The following functions are overrides required by Solidity.

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function _msgSender()
        internal
        view
        virtual
        override(Context, ERC2771Context)
        returns (address sender)
    {
        return ERC2771Context._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(Context, ERC2771Context)
        returns (bytes calldata)
    {
        return ERC2771Context._msgData();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, IChildMintableERC721)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
