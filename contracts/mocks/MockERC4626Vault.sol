// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MockERC20} from "./MockERC20.sol";

contract MockERC4626Vault is ERC20, ERC4626 {
    using SafeERC20 for IERC20;

    uint256 private _lostAssets;

    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) ERC4626(asset_) {}

    function decimals()
        public
        view
        override(ERC20, ERC4626)
        returns (uint8)
    {
        return super.decimals();
    }

    function mintYield(uint256 amount) external {
        MockERC20(asset()).mint(address(this), amount);
    }

    function burnLiquidity(uint256 amount) external {
        IERC20(asset()).safeTransfer(address(0xdead), amount);
        _lostAssets += amount;
    }

    function lostAssets() external view returns (uint256) {
        return _lostAssets;
    }
}
