// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "../src/SwapFactory.sol";
import "../src/Pair.sol";
import "./mocks/ERC20Mintable.sol";

contract SwapFactoryTest is Test {
    SwapFactory factory;

    ERC20Mintable token0;
    ERC20Mintable token1;
    ERC20Mintable token2;
    ERC20Mintable token3;

    function setUp() public {
        factory = new SwapFactory();

        token0 = new ERC20Mintable("Token A", "TKNA");
        token1 = new ERC20Mintable("Token B", "TKNB");
        token2 = new ERC20Mintable("Token C", "TKNC");
        token3 = new ERC20Mintable("Token D", "TKND");
    }

    function encodeError(string memory error)
        internal
        pure
        returns (bytes memory encoded)
    {
        encoded = abi.encodeWithSignature(error);
    }

    function testCreatePair() public {
        address pairAddress = factory.createPairing(
            address(token1),
            address(token0)
        );

        Pair pair = Pair(pairAddress);

        assertEq(pair.token0(), address(token0));
        assertEq(pair.token1(), address(token1));
    }

    function testCreatePairZeroAddress() public {
        vm.expectRevert(encodeError("ZeroAddress()"));
        factory.createPairing(address(0), address(token0));

        vm.expectRevert(encodeError("ZeroAddress()"));
        factory.createPairing(address(token1), address(0));
    }

    function testCreatePairPairExists() public {
        factory.createPairing(address(token1), address(token0));

        vm.expectRevert(encodeError("PairExists()"));
        factory.createPairing(address(token1), address(token0));
    }

    function testCreatePairIdenticalTokens() public {
        vm.expectRevert(encodeError("IdenticalAddress()"));
        factory.createPairing(address(token0), address(token0));
    }
}