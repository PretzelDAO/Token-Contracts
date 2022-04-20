// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../IMintableERC721.sol";

abstract contract IRootMintableERC721 is
    ERC721,
    IMintableERC721,
    AccessControl
{
    // Stuff needed for Polygon mintable assets
    bytes32 public constant PREDICATE_ROLE = keccak256("PREDICATE_ROLE");

    // END

    constructor() {
        _grantRole(PREDICATE_ROLE, _msgSender());
    }

    /**
     * @dev See {IMintableERC721-mint}.
     */
    function mint(address user, uint256 tokenId)
        external
        override
        onlyRole(PREDICATE_ROLE)
    {
        _safeMint(user, tokenId);
    }

    /**
     * @dev See {IMintableERC721-mint}.
     *
     * If you're attempting to bring metadata associated with token
     * from L2 to L1, you must implement this method
     */
    function mint(
        address user,
        uint256 tokenId,
        bytes calldata metaData
    ) external override onlyRole(PREDICATE_ROLE) {
        _safeMint(user, tokenId);
        setTokenMetadata(tokenId, metaData);
    }

    /*
     * If you're attempting to bring metadata associated with token
     * from L2 to L1, you must implement this method, to be invoked
     * when minting token back on L1, during exit
     */
    function setTokenMetadata(uint256 tokenId, bytes memory data)
        internal
        virtual;

    // {
    //     // This function should decode metadata obtained from L2
    //     // and attempt to set it for this `tokenId`
    //     //
    //     // Following is just a default implementation, feel
    //     // free to define your own encoding/ decoding scheme
    //     // for L2 -> L1 token metadata transfer
    //     string memory uri = abi.decode(data, (string));

    //     _setTokenURI(tokenId, uri);
    // }

    /**
     * @dev See {IMintableERC721-exists}.
     */
    function exists(uint256 tokenId) external view override returns (bool) {
        return _exists(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
