// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "solmate/tokens/ERC20.sol";
import "./libraries/Math.sol";
import "./libraries/UQ112x112.sol";
import "./interfaces/ISwapCallee.sol";
import "forge-std/console2.sol";



error InsufficientLiquidityMinted();
error InsufficientLiquidityBurned();
error TransferFailed();
error InsufficientOutputAmount();
error InsufficientInputAmount();
error InsufficientLiquidity();
error InvalidProduct();
error BalanceOverflow();
error AlreadyInitialized();

interface IERC20 {
    function balanceOf(address) external returns (uint256);

    function transfer(address to, uint256 amount) external;
}

contract Pair is ERC20, Math {
    using UQ112x112 for uint224;

    uint256 constant MINIMUM_LIQUIDITY = 1000;

    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;

    uint32 private blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    bool private isEntered;

    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address to);
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Sync(uint256 reserve0, uint256 reserve1);
    event Swap(address indexed sender, uint256 amountOut0, uint256 amountOut1, address indexed to);

    modifier nonReentrant() {
        require(!isEntered);
        isEntered = true;
        _;
        isEntered = false;
    }

    constructor() ERC20("Coinswap Pair", "CSP", 18){}

    function initialize(address _token0, address _token1) public {

        if (token0 != address(0) || token1 != address(0)){
            revert AlreadyInitialized();
        }

        token0 = _token0;
        token1 = _token1;


    }

    function mint(address to) public returns (uint256 liquidity) {
       (uint112 reserve0_, uint112 reserve1_, ) = getReserves();
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0 - reserve0_;
        uint256 amount1 = balance1 - reserve1_;

        if (totalSupply == 0){
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min((amount0 * totalSupply) / reserve0_, (amount1 * totalSupply) / reserve1_);
        } 


        if (liquidity <= 0)
            revert InsufficientLiquidityMinted();

        _mint(to, liquidity);

        _update(balance0, balance1, reserve0_, reserve1_);

        emit Mint(to, amount0, amount1);

    }

    function burn(address to) public returns (uint256 amount0, uint256 amount1) {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 liquidity = balanceOf[address(this)];

        amount0 = (liquidity * balance0) / totalSupply;
        amount1 = (liquidity * balance1) / totalSupply;

        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidityBurned();

        _burn(address(this), liquidity);
        _safeTransfer(token0, to, amount0);
        _safeTransfer(token1, to, amount1);

        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));

        (uint112 reserve0_, uint112 reserve1_, ) = getReserves();
        _update(balance0, balance1, reserve0_, reserve1_);

        emit Burn(msg.sender, amount0, amount1, to);

    }


    function swap(uint256 amountOut0, uint256 amountOut1, address to, bytes calldata data)
     public nonReentrant {

        if (amountOut0 == 0 && amountOut1 == 0)
            revert InsufficientOutputAmount();

        (uint112 reserve0_, uint112 reserve1_, ) = getReserves();

        if (amountOut0 > reserve0_ || amountOut1 > reserve1_)
            revert InsufficientLiquidity();     

        if (amountOut0 > 0)
            _safeTransfer(token0, to, amountOut0);
        
        if (amountOut1 > 0)
            _safeTransfer(token1, to, amountOut1);

        if (data.length > 0)
            SwapCallee(to).swapCall(msg.sender, amountOut0, amountOut1, data);

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amountIn0 = balance0 > reserve0 - amountOut0 ? balance0 - (reserve0 - amountOut0)
             : 0;
        uint256 amountIn1 = balance1 > reserve1 - amountOut1 ? balance1 - (reserve1 - amountOut1)
            : 0;

        if (amountIn0 == 0 && amountIn1 == 0)
            revert InsufficientInputAmount();

        uint256 balanceAdjusted0 = (balance0 * 1000) - (amountIn0 * 3);
        uint256 balanceAdjusted1 = (balance1 * 1000) - (amountIn1 * 3);

        if (balanceAdjusted0 * balanceAdjusted1 < uint256(reserve0) * uint256(reserve1) * 1000**2)
            revert InvalidProduct();

        _update(balance0, balance1, reserve0, reserve1);
        emit Swap(msg.sender, amountOut0, amountOut1, to);

        
    }

    function sync() public {
        (uint112 reserve0_, uint112 reserve1_, ) = getReserves();
        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this)),
            reserve0_,
            reserve1_
        );
    }

    function getReserves() public view returns (
        uint112,
        uint112,
        uint32
    )
    {
        return (reserve0, reserve1, blockTimestampLast);
    }

    function _update(uint256 balance0, uint256 balance1, uint112 reserve0_, uint112 reserve1_) private {
        
        if (balance0 > type(uint112).max || balance1 > type(uint112).max){
            revert BalanceOverflow();
        }

        unchecked {
            uint32 timeElapsed = uint32(block.timestamp) - blockTimestampLast;

            if (timeElapsed > 0 && reserve0_ > 0 && reserve1_ > 0){
                price0CumulativeLast += uint256(UQ112x112.encode(reserve1_).uqdiv(reserve0_)) * timeElapsed;
                price1CumulativeLast += uint256(UQ112x112.encode(reserve0_).uqdiv(reserve1_)) * timeElapsed;
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

