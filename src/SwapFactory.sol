
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "./Pair.sol";
import "./interfaces/IPair.sol";


contract SwapFactory {
    
    error IdenticalAddress();
    error PairExists();
    error ZeroAddress();

    event PairCreated(address indexed token0, address indexed token1, address pairing, uint256);

    mapping(address => mapping(address => address)) public pairings;
    address[] public allPairings;

    function createPairing(address tokenA, address tokenB) public returns (address pairing) {
        if (tokenA == tokenB){
            revert IdenticalAddress();
        }

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        if (token0 == address(0)) {
            revert ZeroAddress();
        }

        if (pairings[token0][token1] != address(0)){
            revert PairExists();
        }

        bytes memory bytecode = type(Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pairing := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        IPair(pairing).initialize(token0, token1);

        pairings[token0][token1] = pairing;
        pairings[token1][token0] = pairing;
        allPairings.push(pairing);

        emit PairCreated(token0, token1, pairing, allPairings.length);

    }
}