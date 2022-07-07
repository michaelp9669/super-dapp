// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ConstantProductAMM {
    IERC20 public immutable token0Contract;
    IERC20 public immutable token1Contract;

    uint256 public reserve0;
    uint256 public reserve1;

    uint256 public totalShares;
    mapping(address => uint256) public sharesOf;

    constructor(address _token0Contract, address _token1Contract) {
        token0Contract = IERC20(_token0Contract);
        token1Contract = IERC20(_token1Contract);
    }

    function _mintShares(address to, uint256 amount) private {
        sharesOf[to] += amount;
        totalShares += amount;
    }

    function _asmMintShares(address to, uint256 amount) private {
        assembly {
            mstore(0x0, to)
            mstore(0x20, sharesOf.slot)
            let location := keccak256(0x0, 64)
            sstore(location, add(sload(location), amount))
        }

        assembly {
            sstore(totalShares.slot, add(sload(totalShares.slot), amount))
        }
    }

    function _burnShares(address to, uint256 amount) private {
        sharesOf[to] -= amount;
        totalShares -= amount;
    }

    function _updateReserves(uint256 _reserve0, uint256 _reserve1) private {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }

    function _asmUpdateReserves(uint256 _reserve0, uint256 _reserve1) private {
        assembly {
            sstore(reserve0.slot, _reserve0)
            sstore(reserve1.slot, _reserve1)
        }
    }

    function swap(address _tokenIn, uint256 _amountIn)
        external
        returns (uint256 amountOut)
    {
        require(
            _tokenIn == address(token0Contract) ||
                _tokenIn == address(token1Contract),
            "ConstantProductAMM: invalid token"
        );

        bool isToken0 = _tokenIn == address(token0Contract);

        (
            IERC20 tokenIn,
            IERC20 tokenOut,
            uint256 reserveIn,
            uint256 reserveOut
        ) = isToken0
                ? (token0Contract, token1Contract, reserve0, reserve1)
                : (token1Contract, token0Contract, reserve1, reserve0);

        tokenIn.transferFrom(msg.sender, address(this), _amountIn);
        uint256 amountIn = tokenIn.balanceOf(address(this)) - reserveIn;

        /// @notice the amount of tokens out is
        // dy = y * dx / (x + dx)
        uint256 amountInWithFee = (amountIn * 997) / 1000;
        amountOut =
            (reserveOut * amountInWithFee) /
            (reserveIn + amountInWithFee);

        // update reserves
        (uint256 res0, uint256 res1) = isToken0
            ? (reserveIn + amountIn, reserveOut - amountOut)
            : (reserveOut - amountOut, reserveIn + amountIn);

        _updateReserves(res0, res1);

        // transfer tokenOut to user
        tokenOut.transfer(msg.sender, amountOut);
    }

    function addLiquidity() external returns (uint256 shares) {}

    function removeLiquidity()
        external
        returns (uint256 amount0, uint256 amount1)
    {}
}
