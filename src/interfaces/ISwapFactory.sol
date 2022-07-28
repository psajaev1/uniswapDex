
// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface ISwapFactory {
    function pairings(address, address) external pure returns (address);

    function createPairing(address, address) external returns (address);
}