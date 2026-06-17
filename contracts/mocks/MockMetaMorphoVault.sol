// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IMetaMorpho} from "../interfaces/morpho/IMetaMorpho.sol";
import {IMorpho, Id} from "morpho-blue/interfaces/IMorpho.sol";
import {MockERC20} from "./MockERC20.sol";

contract MockMetaMorphoVault is ERC20, ERC4626, IMetaMorpho {
    using SafeERC20 for IERC20;

    uint96 private _fee;
    uint256 private _timelock;
    uint256 private _lostAssets;

    constructor(
        IERC20 asset_
    ) ERC20("Mock MetaMorpho Share", "mMORPHO") ERC4626(asset_) {}

    function decimals()
        public
        view
        override(ERC20, ERC4626, IERC20Metadata)
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

    // forge-lint: disable-next-line(mixed-case-function)
    function MORPHO() external pure returns (IMorpho) {
        return IMorpho(address(0));
    }

    function fee() external view returns (uint96) {
        return _fee;
    }

    function timelock() external view returns (uint256) {
        return _timelock;
    }

    function setFee(uint96 newFee) external {
        _fee = newFee;
    }

    function setTimelock(uint256 newTimelock) external {
        _timelock = newTimelock;
    }

    function supplyQueue(uint256) external pure returns (Id) {
        return Id.wrap(bytes32(0));
    }

    function supplyQueueLength() external pure returns (uint256) {
        return 0;
    }

    function withdrawQueue(uint256) external pure returns (Id) {
        return Id.wrap(bytes32(0));
    }

    function withdrawQueueLength() external pure returns (uint256) {
        return 0;
    }

    function lastTotalAssets() external view returns (uint256) {
        return totalAssets();
    }

    function lostAssets() external view returns (uint256) {
        return _lostAssets;
    }
}
