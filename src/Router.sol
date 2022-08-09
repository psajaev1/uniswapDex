// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "./interfaces/ISwapFactory.sol";
import "./interfaces/IPair.sol";
import "./SwapLibrary.sol";

import "forge-std/console2.sol";


contract Router {



    ISwapFactory factory;


    error InsufficientAAmount();
    error InsufficientBAmount();
    error SafeTransferFailed();
    error InsufficientOutputAmount();


    constructor(address factoryAddress) {
        factory = ISwapFactory(factoryAddress);
    }

    function addLiquidity(address tokenA, address tokenB, uint256 amountDesiredA, 
        uint256 amountDesiredB, uint256 amountMinA, uint256 amountMinB, address to) 
        public returns ( uint256 amountA, uint256 amountB, uint256 liquidity) {

        if (factory.pairings(tokenA, tokenB) == address(0)){
            factory.createPairing(tokenA, tokenB);
        }


        (amountA, amountB) = _calculateLiquidity(
            tokenA,
            tokenB,
            amountDesiredA,
            amountDesiredB,
            amountMinA,
            amountMinB
        );

        address pairAddress = SwapLibrary.pairFor(
            address(factory),
            tokenA,
            tokenB
        );


        _safeTransferFrom(tokenA, msg.sender, pairAddress, amountA);
        _safeTransferFrom(tokenB, msg.sender, pairAddress, amountB);


        // this is where error is
        liquidity = IPair(pairAddress).mint(to);


    }

    function removeLiquidity(address tokenA, address tokenB, uint256 liquidity, uint256 amountMinA,
        uint256 amountMinB, address to) public returns (uint256 amountA, uint256 amountB) {
            address pair = SwapLibrary.pairFor(address(factory), tokenA, tokenB);
            IPair(pair).transferFrom(msg.sender, pair, liquidity);
            (amountA, amountB) = IPair(pair).burn(to);

            if (amountA < amountMinA)
                revert InsufficientAAmount();

            if (amountB < amountMinB)
                revert InsufficientBAmount();
    }

    function _swap(uint256[] memory amounts, address[] memory path, address _to) internal {
        for (uint256 i; i < path.length - 1; i++){
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = SwapLibrary.sortTokens(input, output);

            uint256 amountOut = amounts[i + 1];
            (uint256 amountOut0, uint256 amountOut1) = input == token0 
                ? (uint256(0), amountOut) : (amountOut, uint256(0));

            address to = i < path.length - 2 ? SwapLibrary.pairFor(address(factory), 
                output, path[i + 2]) : _to;
            
            IPair(SwapLibrary.pairFor(address(factory), input, output)).swap(
                amountOut0, amountOut1, to, "");
        }
    }

    function _calculateLiquidity(            
        address tokenA,
        address tokenB,
        uint256 amountDesiredA,
        uint256 amountDesiredB,
        uint256 amountMinA,
        uint256 amountMinB) internal returns (uint256 amountA, uint256 amountB) {
                
        (uint256 reserveA, uint256 reserveB) = SwapLibrary.getReserves(address(factory),
            tokenA, tokenB);



        if (reserveA == 0 && reserveB == 0){
            (amountA, amountB) = (amountDesiredA, amountDesiredB);
        } else {
            uint256 amountOptimalB = SwapLibrary.quote(amountDesiredA, reserveA, reserveB);


            if (amountOptimalB <= amountDesiredB){
                if (amountOptimalB <= amountMinB){
                    revert InsufficientBAmount();
                }
                (amountA, amountB) = (amountDesiredA, amountOptimalB);
            } else {

                uint256 amountOptimalA = SwapLibrary.quote(amountDesiredB, reserveB, reserveA);



                assert(amountOptimalA <= amountDesiredA);
                if (amountOptimalA <= amountMinA){
                    revert InsufficientAAmount();
                }
                (amountA, amountB) = (amountOptimalA, amountDesiredB);

            }

        }
                

    }


    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin,
        address[] calldata path, address to) public returns (uint256[] memory amounts) {

            amounts = SwapLibrary.getAmountsOut(address(factory), amountIn, path);

            if (amounts[amounts.length - 1] < amountOutMin)
                revert InsufficientOutputAmount();

            _safeTransferFrom(path[0], msg.sender,
                 SwapLibrary.pairFor(address(factory), path[0], path[1]), amounts[0]);
            
            _swap(amounts, path, to);
        }

    function _safeTransferFrom(address token, address from, address to, uint256 value) private {


        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                from,
                to,
                value
            )
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool))))
            revert SafeTransferFailed();    
    }

}
