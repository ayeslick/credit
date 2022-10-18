// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

//CREDIT NFT

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Credit is ERC721, Ownable {
    error NotCurrentHolder();
    error AmountExceedsOrEqualsDepositValue();

    uint256 public _tokenId;

    struct CreditValue {
        uint256 depositValue;
        uint256 creationTime;
    }

    //mapping(uint256 => uint256) public depositValue;
    mapping(uint256 => CreditValue) public creditValue;

    event SubtractValue(
        address indexed customer,
        uint256 tokenId,
        uint256 amount
    );
    event Deleted(address indexed customer, uint256 tokenId, uint256 value);

    constructor(string memory names, string memory symbols)
        ERC721(names, symbols)
    {}

    //core
    function createCREDIT(address customer, uint256 amount) public onlyOwner {
        //depositValue[_tokenId] = amount;
        creditValue[_tokenId].depositValue = amount;
        creditValue[_tokenId].creationTime = block.number;
        _mint(customer, _tokenId);
        unchecked {
            ++_tokenId;
        }
    }

    function subtractValueFromCREDIT(
        address customer,
        uint256 tokenId,
        uint256 amount
    ) public onlyOwner {
        address currentHolder = ERC721.ownerOf(tokenId);
        if (currentHolder != customer) revert NotCurrentHolder();
        if (amount >= creditValue[tokenId].depositValue)
            revert AmountExceedsOrEqualsDepositValue();
        creditValue[tokenId].depositValue -= amount;
        emit SubtractValue(customer, tokenId, amount);
    }

    function deleteCREDIT(address customer, uint256 tokenId)
        public
        onlyOwner
        returns (uint256 value)
    {
        address currentHolder = ERC721.ownerOf(tokenId);
        if (currentHolder != customer) revert NotCurrentHolder();
        value = balanceOfCredit(tokenId);
        delete creditValue[tokenId];
        _burn(tokenId);
        emit Deleted(customer, tokenId, value);
        return value;
    }

    function balanceOfCredit(uint256 tokenId) public view returns (uint256) {
        return creditValue[tokenId].depositValue;
    }
}
