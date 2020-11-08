// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

interface Operator {
    function deposit(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    // calls withdraw and getreward()
    function exit(uint256 _pid, uint256 _amount) external;

    // outstanding stbz
    function getReward(uint256 _pid) external;

    // How many LP/Stablecoin tokens the user has provided.
    function poolBalance(uint256 _pid, address _user)
        external
        view
        returns (uint256);
}
