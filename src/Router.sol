pragma solidity ^0.8.9;

import "./interfaces/ISwapFactory.sol";
import "./interfaces/IPair.sol";


contract Router {

    error InsufficientAAmount();
    error InsufficientBAmount();
    error SafeTransferFailed();

    ISwapFactory factory;

    constructor(address factoryAddress) {
        factory = ISwapFactory(factoryAddress);
    }

    function addLiquidity(address tokenA, address tokenB, uint256 amountDesiredA, 
    uint256 amountDesiredB, uint256 amountMinA, uint256 amountMinB, address to) public returns (
        uint256 amountA, uint256 amountB, uint256 liquidity
    ) {

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

        address pairAddress = ZuniswapV2Library.pairFor(
            address(factory),
            tokenA,
            tokenB
        );
        _safeTransferFrom(tokenA, msg.sender, pairAddress, amountA);
        _safeTransferFrom(tokenB, msg.sender, pairAddress, amountB);
        liquidity = IZuniswapV2Pair(pairAddress).mint(to);

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

}
