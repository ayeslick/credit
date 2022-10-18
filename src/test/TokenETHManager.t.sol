// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import "../ETH/eCreds.sol";
import "../ETH/ETHCredit.sol";
import "../ETH/TokenManagerETH.sol";

contract TokenETHManager is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    ECreds public creds;
    ETHCredit public credit;
    TokenManagerETH public tme;

    uint256 internal constant WITHDRAW_AMOUNT = 5 ether;

    Utilities internal utils;
    address payable[] internal users;

    address payable public alice;
    address payable public bob;
    address payable public steve;
    address payable public treasury;
    address public deployer = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84; //default deployer address

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);
        vm.label(alice, "Alice");
        alice = users[0];
        vm.label(bob, "Bob");
        bob = users[1];
        vm.label(steve, "Steve");
        steve = users[2];
        vm.label(treasury, "Treasury");
        treasury = users[3];
        creds = new ECreds();
        credit = new ETHCredit();

        //eCreds address, ETH address, Treasury address, global limit
        tme = new TokenManagerETH(
            ICREDS(address(creds)),
            ICREDIT(address(credit)),
            treasury,
            1000 ether
        );
        _helperTransferOwnership();
    }

    function testName() public view {
        console.log(creds.name());
        console.log(creds.decimals());
        console.log(credit.name());
    }

    function testEmptySend() public {
        vm.expectRevert(EmptySend.selector);
        vm.prank(bob);
        (bool sent, ) = address(tme).call("");
        require(sent, "");
    }

    /*if customers deposit passes ceiling it will be allowed
      when it was called it was under the ceiling
    */
    function testGlobalCeiling() public {
        vm.deal(alice, 1200 ether);
        vm.prank(alice);
        tme.deposit{value: 1100 ether}();
        vm.expectRevert(CeilingReached.selector);
        vm.prank(bob);
        tme.deposit{value: 10 ether}();
    }

    function testDeposit() public payable {
        //bob calls deposit
        _helperDeposit(bob);
        //check bob's balance
        assertEq(address(bob).balance, 90 ether);
        //check bob's NFT holdings
        assertEq(_checkNFTHoldings(bob), 1);
        //check bob's eCREDS Holdings
        assertEq(_checkCreds(bob), 95 * 1e17);
        //check fee value
        assertEq(tme.feeToTransfer(), 0.5 ether);
        //check total contract value
        assertEq(address(tme).balance, 10 ether);
    }

    function testPartialWithraw() public {
        _helperDeposit(bob);
        uint256 currentNFTValue = _checkNFTValue(1);
        uint256 currentCredsValue = _checkCreds(bob);
        assertEq(currentNFTValue, 95 * 1e17);
        assertEq(currentCredsValue, 95 * 1e17);
        vm.prank(bob);
        tme.partialWithdraw(1, WITHDRAW_AMOUNT);
        uint256 actualNFTValue = currentNFTValue - WITHDRAW_AMOUNT;
        uint256 actualCredsAmount = currentCredsValue - WITHDRAW_AMOUNT;
        assertEq(_checkNFTValue(1), actualNFTValue);
        assertEq(_checkCreds(bob), actualCredsAmount);
    }

    //if contract calls non-exsistant NFT it fails as Arithmetic over/underflow
    function testETHCreditNotCurrentHolder() public {
        _helperDeposit(bob);
        _helperDeposit(alice);
        vm.expectRevert(NotCurrentHolder.selector);
        vm.prank(bob);
        tme.partialWithdraw(2, 1 ether);
    }

    function testPartialWithrawTransfer() public {
        _helperDeposit(bob);
        _helperDeposit(alice);
        _helperTransferNFT(alice, steve, 2);
        vm.prank(alice);
        creds.transfer(steve, 5 ether);
        vm.prank(steve);
        tme.partialWithdraw(2, 1 ether);
    }

    function testclaimAllUnderlying() public {
        console.log(address(bob).balance);
        _helperDeposit(bob);
        console.log(address(bob).balance);
        vm.prank(bob);
        tme.claimAllUnderlying(1);
        uint256 currentNFTValue = _checkNFTValue(1);
        uint256 currentCredsValue = _checkCreds(bob);
        assertEq(currentNFTValue, 0);
        assertEq(currentCredsValue, 0);
        console.log(address(bob).balance);
    }

    //fails with error message: ERC721: owner query for nonexistent token
    function testFailclaimAllUnderlying() public {
        _helperDeposit(bob);
        _helperDeposit(alice);
        vm.prank(bob);
        tme.claimAllUnderlying(1);
        vm.prank(alice);
        tme.claimAllUnderlying(1);
    }

    //fuzz deposit
    //known error
    // function testDepositFuzz(uint96 _value) public {
    //     vm.assume(_value > 0.1 ether);
    //     vm.prank(bob);
    //     tme.deposit{value: _value}();
    //     uint256 adjustedFee = _calculateFee(_value);
    //     uint256 value = _value - adjustedFee;
    //     //check bob's NFT holdings
    //     assertEq(_checkNFTHoldings(bob), 1);
    //     //check bob's eCREDS Holdings
    //     assertEq(_checkCreds(bob), value);
    //     //check fee value
    //     assertEq(tme.feeToTransfer(), adjustedFee);
    //     //check total contract value
    //     assertEq(address(tme).balance, _value);
    // }

    //fails because pause is active: Reason: Pausable: paused
    function testFailPauseActive() public {
        _helperDeposit(bob);
        tme.pause();
        _helperDeposit(bob);
    }

    function testActivateEmergency() public {
        _helperActivateEmergency();
    }

    // this should fail because its called before pausing Pausable: not paused
    function testFailActivateEmergency() public {
        tme.activateEmergency();
    }

    function testDeactivateEmergency() public {
        _helperActivateEmergency();
        _helperDeactivateEmergency();
    }

    /* this should fail because its because emergency is not active and because it was
       called before pausing, Pausable: not paused
    */
    function testFailDeactivateEmergency() public {
        vm.expectRevert(EmergencyNotActive.selector);
        _helperDeactivateEmergency();
    }

    function testEmergencyWithdraw() public {
        _helperDeposit(bob);
        _helperActivateEmergency();
        vm.prank(bob);
        tme.emergencyWithdraw(1);
    }

    function testReceiveFunction() public {
        vm.prank(bob);
        (bool sent, ) = address(tme).call{value: 10 ether}("");
        assertTrue(sent);
        assertEq(_checkCreds(bob), 95 * 1e17);
        assertEq(_checkNFTHoldings(bob), 1);
    }

    function testSendToTreasury() public {
        _helperDeposit(bob);
        tme.sendToFeesTreasury();
        assertEq(tme.feeToTransfer(), 0);
        assertEq(address(treasury).balance, 10.05 * 1e19); // address has 10 ether by default
    }

    function testSetTreasuryAddress() public {
        tme.setTreasuryAddress(steve);
        assertEq(tme.treasury(), steve);
    }

    function testSetFeePercentage() public {
        console.log(tme.feePercentage());
        tme.setFeePercentage(3);
        console.log(tme.feePercentage());
    }

    function testAdjustCeiling() public {
        assertEq(tme.globalCeiling(), 1000 ether);
        tme.adjustCeiling(2000 ether);
        assertEq(tme.globalCeiling(), 2000 ether);
    }

    //change this to match basis points system
    function _calculateFee(uint256 msgValue) internal view returns (uint256) {
        uint256 adjustedMsgValue;
        if (tme.feePercentage() == 1) {
            adjustedMsgValue = msgValue / 100;
            return adjustedMsgValue;
        }
        adjustedMsgValue = (msgValue * tme.feePercentage()) / 100;
        return adjustedMsgValue;
    }

    function _checkNFTHoldings(address _holder)
        internal
        view
        returns (uint256)
    {
        return credit.balanceOf(_holder);
    }

    function _checkNFTOwner(address _caller, uint256 _tokenId) internal {
        address t = credit.ownerOf(_tokenId);
        assertEq(_caller, t);
    }

    function _checkNFTValue(uint256 _tokenId) internal view returns (uint256) {
        return credit.depositValue(_tokenId);
    }

    function _checkCreds(address _caller) internal view returns (uint256) {
        return creds.balanceOf(_caller);
    }

    //transfer ownership of creds and credit to tme
    function _helperTransferOwnership() internal {
        vm.startPrank(deployer);
        creds.transferOwnership(address(tme));
        credit.transferOwnership(address(tme));
        vm.stopPrank();
    }

    function _helperActivateEmergency() internal {
        tme.pause();
        tme.activateEmergency();
        assertEq(tme.emergencyStatus(), 2);
    }

    function _helperDeactivateEmergency() internal {
        tme.deactivateEmergency();
        tme.unpause();
        assertEq(tme.emergencyStatus(), 1);
    }

    function _helperDeposit(address _caller) internal {
        vm.prank(_caller);
        tme.deposit{value: 10 ether}();
    }

    function _helperTransferNFT(
        address _from,
        address _to,
        uint256 _tokenId
    ) internal {
        vm.prank(_from);
        credit.transferFrom(_from, _to, _tokenId);
    }

    function _helperTransferCreds(
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        creds.transferFrom(_from, _to, _amount);
    }
}
