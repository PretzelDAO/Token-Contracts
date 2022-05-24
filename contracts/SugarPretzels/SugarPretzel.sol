// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./BasePretzel.sol";

contract SugarPretzel is BasePretzel {
    constructor(
        address trustedForwarder,
        address _link,
        address _oracle
    ) BasePretzel(trustedForwarder, _link, _oracle, "SugarPretzel", "SPRZL") {}

    function getRandomWords(address to)
        private
        view
        returns (uint256[] memory)
    {
        uint256[] memory randomWords = new uint256[](4);

        randomWords[0] = uint256(
            keccak256(
                abi.encode(
                    to,
                    tx.gasprice,
                    block.number,
                    block.timestamp,
                    block.difficulty,
                    blockhash(block.number - 1),
                    address(this),
                    totalSupply()
                )
            )
        );

        for (uint256 i = 1; i < NUM_WORDS; ) {
            randomWords[i] = uint256(keccak256(abi.encode(randomWords[i - 1])));
            unchecked {
                ++i;
            }
        }

        return randomWords;
    }

    function mint() internal override {
        handleMint(_msgSender(), getRandomWords(_msgSender()));
    }
}
