// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "solmate/tokens/ERC20.sol";
import "./libraries/Math.sol";
import "./libraries/UQ112x112.sol";


error InsufficientLiquidityMinted();
error InsufficientLiquidityBurned();
error TransferFailed();
error InsufficientOutputAmount();
error InsufficientLiquidity();
error InvalidProduct();
error BalanceOverflow();

interface IERC20 {
    function balanceOf(address) external returns (uint256);

    function transfer(address to, uint256 amount) external;
}

contract Pair is ERC20, Math {

    uint256 constant MINIMUM_LIQUIDITY = 1000;

    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;

    uint32 private blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    event Burn(address indexed sender, uint256 amount0, uint256 amount1);
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Sync(uint256 reserve0, uint256 reserve1);

    // start working on constructor when you get back 
    constructor(address _token0, address _token1) ERC20("Coinswap Pair", "CSP", 18){
        token0 = _token0;
        token1 = _token1;
    }

    function mint() public {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0 - reserve0;
        uint256 amount1 = balance1 - reserve1;

        uint256 liquidity;

        if (totalSupply == 0){
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min((amount0 * totalSupply) / reserve0, (amount1 * totalSupply) / reserve1);
        } 
        
    }

    function burn() public {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 liquidity = balanceOf[msg.sender];

        uint256 amount0 = (liquidity * balance0) / totalSupply;
        uint256 amount1 = (liquidity * balance1) / totalSupply;

        if (amount0 <= 0 || amount1 <= 0) revert InsufficientLiquidityBurned();

        _burn(msg.sender, liquidity);
        _safeTransfer(token0, msg.sender, amount0);
        _safeTransfer(token1, msg.sender, amount1);

        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));

        _update(balance0, balance1);

        emit Burn(msg.sender, amount0, amount1);

    }


    function swap(uint256 amountOut0, uint256 amountOut1, address to) public {
        if (amountOut0 == 0 && amountOut1 == 0){
            revert InsufficientOutputAmount();
        }

        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();

        if (amountOut0 > _reserve0 || amountOut1 > _reserve1){
            revert InsufficientLiquidity();
        }

        uint256 balance0 = IERC20(token0).balanceOf(address(this)) - amountOut0;
        uint256 balance1 = IERC20(token1).balanceOf(address(this)) - amountOut1;

        if (balance0 * balance1 < uint256(_reserve0) * uint256(_reserve1)){
            revert InvalidProduct();
        }

        _update(balance0, balance1, _reserve0, _reserve1);

        if (amountOut0 > 0) {
            _safeTransfer(token0, to, amountOut0);
        }

        if (amountOut1 > 0){
            _safeTransfer(token1, to, amountOut1);
        }

        emit Swap(msg.sender, amountOut0, amountOut1, to);

    }

    function getReserves() public view returns (
        uint112,
        uint112,
        uint32
    )
    {
        return (reserve0, reserve1, 0);
    }

    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        
        if (balance0 > type(uint112).max || balance1 > type(uint112).max){
            revert BalanceOverflow();
        }

        unchecked {
            uint32 timeElapsed = uint32(block.timestamp) - blockTimestampLast;

            if (timeElapsed > 0 && _reserve0 > 0 && _reserve1 > 0){
                price0CumulativeLast += uint256(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
                price1CumulativeLast += uint256(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
            }
        }
        
        
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = uint32(block.timestamp);

        emit Sync(reserve0, reserve1);
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSignature("transfer(address,uint256)", to, value));

        if (!success || (data.length != 0 && !abi.decode(data, (bool)))){
            revert TransferFailed();
        }
    }

}

