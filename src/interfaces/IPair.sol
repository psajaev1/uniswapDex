// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface IPair {
    function initialize(address, address) external;

    function getReserves()
        external
        returns (
            uint112,
            uint112,
            uint32
        );

    function mint(address) external returns (uint256);
}