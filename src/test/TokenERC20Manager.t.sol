// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import "../ERC20/Creds.sol";
import "../ERC20/Credit.sol";
import "../ERC20/TokenManager.sol";

contract TokenERC20Manager is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Creds public creds;
    Credit public credit;
    TokenManager public tme;

    Utilities internal utils;
    address payable[] internal users;

    address payable public alice;
    address payable public bob;
    address payable public steve;
    address payable public treasury;
    address public deployer = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84; //foundry's default deployer address

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
        creds = new Creds("DAIc", "DAI Creds", 18);
        credit = new Credit("DAIC", "DAI Credit");

        //How does Pool limit increase? Whats the process for this?
        //Creds address, Token address, Treasury address, pool limit
        // tme = new TokenManagerETH(
        //     ICREDS(address(creds)),
        //     ICREDIT(address(credit)),
        //     treasury,
        //     1000 ether
        // );
        // _helperTransferOwnership();
    }

    function testCredsName() public {
        emit log_named_string("Creds Name", creds.name());
        emit log_named_string("Creds Symbol", creds.symbol());
        emit log_named_uint("Creds Decimals", creds.decimals());
    }

    function testCreditName() public {
        emit log_named_string("Credit Name", credit.name());
        emit log_named_string("Credit Symbol", credit.symbol());
    }

    //test factory

    //there isnt any change between this and the ETH version
    //so focus on factory and making sure it works correctly

    //transfer ownership of creds and credit to tme
    function _helperTransferOwnership() internal {
        vm.startPrank(deployer);
        creds.transferOwnership(address(tme));
        credit.transferOwnership(address(tme));
        vm.stopPrank();
    }
}
