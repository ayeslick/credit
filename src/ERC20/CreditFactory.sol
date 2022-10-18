// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import {CREATE3} from "solmate/utils/CREATE3.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import "../ERC20/Creds.sol";
import "../ERC20/Credit.sol";
import "../ERC20/TokenManager.sol";

contract CreditFactory is Ownable {
    error AlreadyRegistered();
    //ignore tokens transferred to this contract except to transfer them to the treasury

    struct CREDIT {
        address TokenManager;
        address Creds;
        address Credit;
    }

    address payable private treasury;
    uint256 public poolCeiling; // set default global ceiling for a given CREDIT
    //address public tokenAddress;

    //how to register a token for credit?
    //function registerCredit() public {} transfer token, if mapping == 0 create else revert
    //then pulls name, symbol and decimal from contract if any fails revert
    //calls run
    //verifies that everything deployed properly and that token maps to CREDIT struct
    //and that CREDIT struct

    //how to deal with rebase tokens and fee on transfer tokens
    //may already be dealt with fee on transfer
    //how to deal with interest bearing tokens?

    mapping(address => CREDIT) public CreditMapping;
    address[] public registeredAddresses;
    string private constant CREDITPOOLNAME = "";
    string private constant CREDSPOOLNAME = "";

    // registerToken, call run which creates creds, credit and tokenmanager
    //then transfer ownership of tokens to tokenmanager
    //verify ownership is factory for tokenmanager else transfer to factory

    function registerCreditPool(address tokenAddress) external {
        if (CreditMapping[tokenAddress].TokenManager != address(0))
            revert AlreadyRegistered();
        //how to Credit or Creds to these?
        //how to add string 'c' to this?
        string memory credsName = ERC20(tokenAddress).name();
        string memory credsSymbol = ERC20(tokenAddress).symbol();
        uint8 credsDecimal = ERC20(tokenAddress).decimals();
        //how to add string 'C' to this?
        string memory creditName = ERC20(tokenAddress).name(); //fix
        string memory creditSymbol = ERC20(tokenAddress).symbol(); //fix
        run(
            credsName,
            credsSymbol,
            credsDecimal,
            creditName,
            creditSymbol,
            tokenAddress
        );
    }

    function run(
        string memory credsName,
        string memory credsSymbol,
        uint8 credsDecimal,
        string memory creditName,
        string memory creditSymbol,
        address tokenAddress
    ) internal {
        address creds = createCreds(
            credsName,
            credsSymbol,
            credsDecimal,
            tokenAddress
        );
        address credit = createCredit(creditName, creditSymbol, tokenAddress);

        createTokenManager(
            ICREDS(creds),
            ICREDIT(credit),
            treasury,
            tokenAddress,
            poolCeiling
        );

        //transfer ownership of tokens to TokenManager
        //check to make sure it transferred properly?
    }

    function createCreds(
        string memory credsName,
        string memory credsSymbol,
        uint8 credsDecimal,
        address tokenAddress
    ) internal returns (address) {
        //Creds creds = new Creds(credsName, credsSymbol, credsDecimal);
        address local = address(
            new Creds(credsName, credsSymbol, credsDecimal)
        );
        require(local != address(0), "Creds Deployment Failed");
        CreditMapping[tokenAddress].Creds = local;
        return local;
    }

    function createCredit(
        string memory creditName,
        string memory creditSymbol,
        address tokenAddress
    ) internal returns (address) {
        //Credit credit = new Credit(creditName, creditSymbol);
        address local = address(new Credit(creditName, creditSymbol));
        require(local != address(0), "Credit Deployment Failed");
        CreditMapping[tokenAddress].Credit = local;
        return local;
    }

    function createTokenManager(
        ICREDS _creds,
        ICREDIT _credit,
        address payable _treasury,
        address _tokenAddress,
        uint256 _poolCeiling
    ) internal {
        // TokenManager tokenmanager = new TokenManager(
        //     _creds,
        //     _credit,
        //     _treasury,
        //     _tokenAddress,
        //     _poolCeiling
        // );
        address local = address(
            new TokenManager(
                _creds,
                _credit,
                _treasury,
                _tokenAddress,
                _poolCeiling
            )
        );
        require(local != address(0), "TokenManager Deployment Failed");
        CreditMapping[_tokenAddress].TokenManager = address(local);
    }

    //function for looping over the registeredAddresses[]

    //have a function to sweep tokens sent to this contract into the treasury

    //function to set the default poolCeiling

    //helper function to join strings together

    function setTreasuryAddress(address payable _newTreasuryAddress)
        external
        onlyOwner
    {
        treasury = _newTreasuryAddress;
    }
}
