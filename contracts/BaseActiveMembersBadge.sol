// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/draft-ERC721Votes.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "../libraries/Base64.sol";

contract BaseActiveMembersBadge is
    ERC721,
    Pausable,
    ERC721Enumerable,
    AccessControl,
    EIP712,
    ERC721Votes
{
    using Base64 for bytes;
    using Strings for uint256;

    // ==== stuff for token metadata
    string public constant NAME = "Active Members Badge";
    string public constant SYMBOL = "AMB";
    string public constant DESCRIPTION =
        "This NFT represents proof that the current owner is an active member of the PretzelDAO. LFB!";
    string public imageCID;
    string public animationCID;
    // END

    // for voting
    string public constant SIGNING_DOMAIN_VERSION = "1";

    // for pausing general token transfers
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // for pausing membership of a particular member
    mapping(address => uint256) public pausedMembershipTokens;

    constructor(string memory _imageCID, string memory _animationCID)
        ERC721(NAME, SYMBOL)
        EIP712(NAME, SIGNING_DOMAIN_VERSION)
    {
        imageCID = _imageCID;
        animationCID = _animationCID;

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(PAUSER_ROLE, _msgSender());
    }

    /**
     * @notice this assumes that address only ever have one badge
     * @param member address of the member to pause the membership for
     */
    function pauseMembership(address member) external {
        require(
            _msgSender() == member || hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "The sender needs to be either an Admin or own the membership badge."
        );
        // token ids start at 1 so an id of 0 means that the member does not have a paused token.
        require(
            pausedMembershipTokens[member] == 0,
            "Membership already ended."
        );

        uint256 tokenId = tokenOfOwnerByIndex(member, 0);
        pausedMembershipTokens[member] = tokenId;

        // interactions
        // use internal transfer function because only that allows us to "steal" from the owner.
        _transfer(member, address(this), tokenId);
    }

    function unpauseMembership(address previousMember)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            pausedMembershipTokens[previousMember] > 0,
            "The address already/still is a Member."
        );

        uint256 tokenId = pausedMembershipTokens[previousMember];
        pausedMembershipTokens[previousMember] = 0;

        // interactions
        safeTransferFrom(address(this), previousMember, tokenId);
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

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
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
