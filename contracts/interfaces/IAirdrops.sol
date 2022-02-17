// SPDX-License-Identifier: UNLICENSED



pragma solidity ^0.8.4;

/**
 * @title IStaking.
 * @dev interface for staking
 * with params enum and functions.
 */
interface IAirdrops {
    function depositAssets(address, uint256, uint256) external payable;
    function setShareForBNBReward(address) external;
    function userPendingBNB(address user) external;
    function pushEBSCAmount(uint _amount) external;
    function withdrawEBSC(address user,uint _amount) external;
    function setShareForEBSCReward (address user) external; 
    function userPendingEBSC(address user) external;
    function setTotalBNB(uint _amount) external;
}
