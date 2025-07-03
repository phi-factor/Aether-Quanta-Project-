nano ~/Projects/AetherQuanta/Aether-Quanta-Project-/scripts/deploy.js
nano ~/Projects/AetherQuanta/Aether-Quanta-Project-/hardhat.config.js// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AetherNet {
    address public owner;
    uint256 public phiScore;
    uint256 public timestamp;
    string public mission;

    event PhiScoreUpdated(uint256 phiScore, uint256 timestamp);

    constructor() {
        owner = msg.sender;
        mission = "GoldenGravity";
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    function setPhiScore(uint256 _phiScore) external onlyOwner {
        phiScore = _phiScore;
        timestamp = block.timestamp;
        emit PhiScoreUpdated(_phiScore, timestamp);
    }

    function getPhiScore() external view returns (uint256, uint256, string memory) {
        return (phiScore, timestamp, mission);
    }
}
