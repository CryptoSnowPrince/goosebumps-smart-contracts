// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

interface IGoosebumpsCallee {
    function goosebumpsCall(address sender, uint amount0, uint amount1, bytes calldata data) external;
}