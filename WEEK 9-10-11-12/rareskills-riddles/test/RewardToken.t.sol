// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../src/RewardToken.sol";

contract RewardTokenChallenge is Test {
    RewardToken public rewardToken;
    NftToStake public nft;
    Depositoor public deposito;
    Exploiter public exploiter;
    address player;

    function setUp() public {
        player = makeAddr("player");

        // Deploy the contracts
        nft = new NftToStake(player);
        deposito = new Depositoor(IERC721(address(nft)));
        rewardToken = new RewardToken(address(deposito));
        exploiter = new Exploiter(address(deposito), address(nft), address(rewardToken));

        // Initialize Depositoor with the reward token
        vm.prank(address(deposito));
        deposito.setRewardToken(IERC20(address(rewardToken)));

        // Transfer ownership of the NFT to the Depositoor
        vm.startPrank(player);
        nft.approve(address(exploiter), 42);
        nft.safeTransferFrom(player, address(exploiter), 42);
        exploiter.deposit(42);
        vm.stopPrank();

        // Fund Depositoor with reward tokens
        rewardToken.transfer(address(deposito), rewardToken.balanceOf(address(this)));

        // Ensure initial conditions
        assertEq(nft.ownerOf(42), address(deposito), "NFT ownership not transferred");
        assertEq(rewardToken.balanceOf(address(deposito)), 100e18, "Depositoor not funded");
    }

    function testExploit() public {
    uint256 currentTime = block.timestamp;
    uint256 timeToAdvance = 100 * 24 * 60 * 60;
    vm.warp(currentTime + timeToAdvance);
        vm.startPrank(player);

        exploiter.exploit();

        // Assert that all reward tokens are drained
        assertEq(rewardToken.balanceOf(player), 100e18, "Player did not drain all tokens");
        assertEq(rewardToken.balanceOf(address(deposito)), 0, "Depositoor still has tokens");

        vm.stopPrank();
    }
}
