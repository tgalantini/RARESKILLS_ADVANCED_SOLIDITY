// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@solady/tokens/ERC20.sol";
import "forge-std/Test.sol";
import "../src/TokenVestingOptimized.sol"; // adjust the path as needed


contract DummyToken is ERC20 {
    constructor() {
        _mint(msg.sender, 1e24);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

     function name() public view override returns (string memory){
        return "test";
    }

    function symbol() public view override returns (string memory){
        return "TEST";
    }
}

/// @dev Foundry test contract for TokenVesting.
contract TokenVestingTest is Test {
    DummyToken token;
    TokenVesting vesting;

    address beneficiary;
    // The deployer (this test contract) is the owner.
    address owner = address(this);

    uint256 startTime;
    uint256 cliffDuration = 10; // seconds
    uint256 duration = 100;     // seconds

    function setUp() public {
        // Create a deterministic beneficiary address.
        beneficiary = makeAddr("beneficiary");

        // Deploy DummyToken.
        token = new DummyToken();

        // Set the vesting start time to the current block time.
        startTime = block.timestamp;

        // Deploy TokenVesting with revocable enabled.
        vesting = new TokenVesting(beneficiary, startTime, cliffDuration, duration, true);

        // Transfer tokens to the vesting contract.
        token.transfer(address(vesting), 1e18);
    }

    function testViewFunctions() public {
        // Verify that view functions return the expected values.
        assertEq(vesting.beneficiary(), beneficiary, "Beneficiary mismatch");
        assertEq(vesting.cliff(), startTime + cliffDuration, "Cliff time mismatch");
        assertEq(vesting.start(), startTime, "Start time mismatch");
        assertEq(vesting.duration(), duration, "Duration mismatch");
        assertTrue(vesting.revocable(), "Revocable flag mismatch");
        assertEq(vesting.released(address(token)), 0, "Initially, released amount should be zero");
        assertFalse(vesting.revoked(address(token)), "Token should not be revoked initially");
    }

    function testRelease() public {
        // Warp time to after the cliff so that tokens are vested.
        vm.warp(startTime + cliffDuration + 1);

        // Capture beneficiary token balance before release.
        uint256 preBalance = token.balanceOf(beneficiary);

        // Call release to transfer vested tokens.
        vesting.release((address(token)));

        // Ensure that the beneficiary's token balance increased.
        uint256 postBalance = token.balanceOf(beneficiary);
        assertGt(postBalance, preBalance, "Beneficiary did not receive tokens on release");
    }

    function testReleaseRevert() public {
        // Ensure that we are before the cliff so that no tokens are vested.
        // This makes _releasableAmount return 0 and triggers the revert.
        vm.warp(startTime); // before cliff: startTime < startTime + cliffDuration

        // Expect revert with the custom error NoTokensDue.
        vm.expectRevert();
        vesting.release((address(token)));
    }

    function testRevoke() public {
        // Warp to after the cliff so that some tokens are vested.
        vm.warp(startTime + cliffDuration + 1);

        // Call release first so that some tokens have vested.
        vesting.release((address(token)));

        // Capture owner (msg.sender) token balance before revoke.
        uint256 ownerPreBalance = token.balanceOf(owner);

        // Call revoke; since the vesting is revocable, it should succeed.
        vesting.revoke((address(token)));

        // Verify that the owner received the refund.
        uint256 ownerPostBalance = token.balanceOf(owner);
        assertGt(ownerPostBalance, ownerPreBalance, "Owner did not receive refund on revoke");

        // Verify that the token is now marked as revoked.
        assertTrue(vesting.revoked(address(token)), "Token should be marked revoked");
    }

    function testEmergencyRevoke() public {
        // Capture owner token balance before emergency revoke.
        uint256 ownerPreBalance = token.balanceOf(owner);

        // Call emergencyRevoke; this should transfer the entire balance back to the owner.
        vesting.emergencyRevoke((address(token)));

        // Verify that the owner received the tokens.
        uint256 ownerPostBalance = token.balanceOf(owner);
        assertGt(ownerPostBalance, ownerPreBalance, "Owner did not receive tokens on emergency revoke");

        // Verify that the token is marked as revoked.
        assertTrue(vesting.revoked(address(token)), "Token should be marked revoked after emergency revoke");
    }
}
