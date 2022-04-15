// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/draft-ERC721Votes.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "../libraries/Base64.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract ChildActiveMembers is
    ERC721,
    ERC721Enumerable,
    AccessControl,
    EIP712,
    ERC721Votes
{
    using Counters for Counters.Counter;
    using Base64 for bytes;
    using Strings for uint256;

    // Stuff needed for Polygon mintable assets

    bytes32 public constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");
    mapping(uint256 => bool) public withdrawnTokens;

    // limit batching of tokens due to gas limit restrictions
    uint256 public constant BATCH_LIMIT = 20;

    event WithdrawnBatch(address indexed user, uint256[] tokenIds);
    // event TransferWithMetadata(
    //     address indexed from,
    //     address indexed to,
    //     uint256 indexed tokenId,
    //     bytes metaData
    // );

    // END

    string public constant NAME = "Active Members Badge";
    string public constant SYMBOL = "AMB";
    string public constant DESCRIPTION =
        "This NFT represents proof that the current owner is an active member of the PretzelDAO. LFB!";

    string public constant SIGNING_DOMAIN_VERSION = "1";

    Counters.Counter private _tokenIdCounter;
    bytes32 public merkleRoot;
    mapping(address => bool) public whitelistClaimed;
    string public imageCID;
    string public animationCID;

    constructor(
        string memory _imageCID,
        string memory _animationCID,
        bytes32 _merkleRoot
    ) ERC721(NAME, SYMBOL) EIP712(NAME, SIGNING_DOMAIN_VERSION) {
        imageCID = _imageCID;
        animationCID = _animationCID;
        merkleRoot = _merkleRoot;

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(DEPOSITOR_ROLE, _msgSender());
    }

    /**
     * @notice called when token is deposited on root chain
     * @dev Should be callable only by ChildChainManager
     * Should handle deposit by minting the required tokenId(s) for user
     * Should set `withdrawnTokens` mapping to `false` for the tokenId being deposited
     * Minting can also be done by other functions
     * @param user user address for whom deposit is being done
     * @param depositData abi encoded tokenIds. Batch deposit also supported.
     */
    function deposit(address user, bytes calldata depositData)
        external
        onlyRole(DEPOSITOR_ROLE)
    {
        // deposit single
        if (depositData.length == 32) {
            uint256 tokenId = abi.decode(depositData, (uint256));
            withdrawnTokens[tokenId] = false;
            _safeMint(user, tokenId);

            // deposit batch
        } else {
            uint256[] memory tokenIds = abi.decode(depositData, (uint256[]));
            uint256 length = tokenIds.length;
            for (uint256 i; i < length; i++) {
                withdrawnTokens[tokenIds[i]] = false;
                _safeMint(user, tokenIds[i]);
            }
        }
    }

    /**
     * @notice called when user wants to withdraw token back to root chain
     * @dev Should handle withraw by burning user's token.
     * Should set `withdrawnTokens` mapping to `true` for the tokenId being withdrawn
     * This transaction will be verified when exiting on root chain
     * @param tokenId tokenId to withdraw
     */
    function withdraw(uint256 tokenId) external {
        require(
            _msgSender() == ownerOf(tokenId),
            "ChildMintableERC721: INVALID_TOKEN_OWNER"
        );
        withdrawnTokens[tokenId] = true;
        _burn(tokenId);
    }

    /**
     * @notice called when user wants to withdraw multiple tokens back to root chain
     * @dev Should burn user's tokens. This transaction will be verified when exiting on root chain
     * @param tokenIds tokenId list to withdraw
     */
    function withdrawBatch(uint256[] calldata tokenIds) external {
        uint256 length = tokenIds.length;
        require(
            length <= BATCH_LIMIT,
            "ChildMintableERC721: EXCEEDS_BATCH_LIMIT"
        );

        // Iteratively burn ERC721 tokens, for performing
        // batch withdraw
        for (uint256 i; i < length; i++) {
            uint256 tokenId = tokenIds[i];

            require(
                _msgSender() == ownerOf(tokenId),
                string(
                    abi.encodePacked(
                        "ChildMintableERC721: INVALID_TOKEN_OWNER ",
                        tokenId
                    )
                )
            );
            withdrawnTokens[tokenId] = true;
            _burn(tokenId);
        }

        // At last emit this event, which will be used
        // in MintableERC721 predicate contract on L1
        // while verifying burn proof
        emit WithdrawnBatch(_msgSender(), tokenIds);
    }

    /**
     * @notice called when user wants to withdraw token back to root chain with token URI
     * @dev Should handle withraw by burning user's token.
     * Should set `withdrawnTokens` mapping to `true` for the tokenId being withdrawn
     * This transaction will be verified when exiting on root chain
     *
     * @param tokenId tokenId to withdraw
     */
    function withdrawWithMetadata(uint256 tokenId) external {
        require(
            _msgSender() == ownerOf(tokenId),
            "ChildMintableERC721: INVALID_TOKEN_OWNER"
        );
        withdrawnTokens[tokenId] = true;

        // this is not needed because our metadata gets generated on the contract
        // still I keep function for compatability

        // Encoding metadata associated with tokenId & emitting event
        // emit TransferWithMetadata(
        //     ownerOf(tokenId),
        //     address(0),
        //     tokenId,
        //     this.encodeTokenMetadata(tokenId)
        // );

        _burn(tokenId);
    }

    // Also we don't need this function! (see above)
    /*
     * @notice This method is supposed to be called by client when withdrawing token with metadata
     * and pass return value of this function as second paramter of `withdrawWithMetadata` method
     *
     * It can be overridden by clients to encode data in a different form, which needs to
     * be decoded back by them correctly during exiting
     *
     * @param tokenId Token for which URI to be fetched
     */

    // function encodeTokenMetadata(uint256 tokenId)
    //     external
    //     view
    //     virtual
    //     returns (bytes memory)
    // {
    //     // You're always free to change this default implementation
    //     // and pack more data in byte array which can be decoded back
    //     // in L1
    //     return abi.encode(tokenURI(tokenId));
    // }

    function claim(bytes32[] calldata _merkleProof) external {
        // require(
        //     !withdrawnTokens[tokenId],
        //     "ChildMintableERC721: TOKEN_EXISTS_ON_ROOT_CHAIN"
        // );
        require(
            !whitelistClaimed[_msgSender()],
            "Address has already claimed."
        );
        bytes32 leaf = keccak256(abi.encodePacked(_msgSender()));
        require(
            MerkleProof.verify(_merkleProof, merkleRoot, leaf),
            "Proof invalid."
        );
        whitelistClaimed[_msgSender()] = true;

        safeMint(_msgSender());

        // let's directly delegate the vote to the minter for convenience
        delegate(_msgSender());
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721URIStorage: URI query for nonexistent token"
        );
        string memory json = abi
            .encodePacked(
                '{"name": "',
                NAME,
                " #",
                tokenId.toString(),
                '",',
                '"description": "',
                DESCRIPTION,
                '", "image": "ipfs://',
                imageCID,
                '", "animation_url": "ipfs://',
                animationCID,
                '"}'
            )
            .encode(); // this encodes to Base64

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    function updateMerkleRoot(bytes32 newMerkleRoot)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        merkleRoot = newMerkleRoot;
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
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Votes) {
        super._afterTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
