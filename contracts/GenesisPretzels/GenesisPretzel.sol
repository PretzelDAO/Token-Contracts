// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "erc721a/contracts/ERC721A.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract GenesisPretzel is ERC721A, Ownable {
    using Strings for uint256;

    bool public revealed = false;
    uint256 public metadataOffset;
    uint256 public constant PRICE_PER_MINT = 0.1 ether;
    uint256 public constant MAX_MINT_PER_TX = 5;

    string private constant METADATA_CID = "metadata";
    string private constant UNREVEALED_CID = "unrevealed";
    uint256 public constant MAX_SUPPLY = 30;

    constructor() ERC721A("GenesisPretzel", "GPRZL") {}

    function mint(uint256 quantity) external payable {
        require(
            _totalMinted() + quantity <= MAX_SUPPLY,
            "Trying to mint too many tokens."
        );
        require(
            quantity <= MAX_MINT_PER_TX,
            "Trying to mint too many tokens in one transaction."
        );
        require(
            msg.value >= quantity * PRICE_PER_MINT,
            "Not enough ether send to complete purchase"
        );
        _safeMint(msg.sender, quantity);
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal pure override returns (string memory) {
        return string(abi.encodePacked("ipfs://", METADATA_CID, "/"));
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();
        if (!revealed) {
            return string(abi.encodePacked("ipfs://", UNREVEALED_CID));
        }
        return
            string(
                abi.encodePacked(
                    _baseURI(),
                    tokenToMetadataId(tokenId).toString()
                )
            );
    }

    function tokenToMetadataId(uint256 tokenId) public view returns (uint256) {
        require(revealed, "Metadata must be revealed first.");
        unchecked {
            return ((tokenId + metadataOffset) % MAX_SUPPLY);
        }
    }

    function reveal() external onlyOwner {
        require(!revealed, "Can only reveal once.");
        revealed = true;
        metadataOffset = getRandomOffset();
    }

    function getRandomOffset() private view returns (uint256) {
        require(
            tx.origin == msg.sender,
            "Contracts are not allowed to reveal."
        );

        uint256 randomWord = uint256(
            keccak256(
                abi.encode(
                    tx.gasprice,
                    block.number,
                    block.timestamp,
                    block.difficulty,
                    blockhash(block.number - 1),
                    address(this),
                    _totalMinted()
                )
            )
        );
        return randomWord % MAX_SUPPLY;
    }

    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}
