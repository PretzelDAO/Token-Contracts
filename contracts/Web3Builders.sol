// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "../libraries/Base64.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract Web3Builders is
    ERC721,
    ERC721Enumerable,
    Pausable,
    Ownable,
    ERC721Burnable
{
    using Counters for Counters.Counter;
    using Base64 for bytes;
    using Strings for uint256;

    Counters.Counter private _tokenIdCounter;
    bytes32 public merkleRoot;
    mapping(address => bool) public whitelistClaimed;
    string public imageCID;
    string public animationCID;

    constructor(
        string memory _imageCID,
        string memory _animationCID,
        bytes32 _merkleRoot
    ) ERC721("Web3 Builders", "W3B") {
        imageCID = _imageCID;
        animationCID = _animationCID;
        merkleRoot = _merkleRoot;
    }

    function claim(bytes32[] calldata _merkleProof) external {
        require(!whitelistClaimed[msg.sender], "Address has already claimed.");
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProof.verify(_merkleProof, merkleRoot, leaf),
            "Proof invalid."
        );
        whitelistClaimed[msg.sender] = true;

        safeMint(msg.sender);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        string memory json = abi
            .encodePacked(
                '{"name": "OG W3B Badge #',
                tokenId.toString(),
                '",',
                '"description": "This token represents proof of early member status of the Web3 Builders community in Munich, which is now known as PretzelDAO", "image": "ipfs://',
                imageCID,
                '", "animation_url": "ipfs://',
                animationCID,
                '"}'
            )
            .encode(); // this encodes to Base64

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    function updateMerkleRoot(bytes32 newMerkleRoot) external onlyOwner {
        merkleRoot = newMerkleRoot;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function safeMint(address to) private {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
