const hre = require("hardhat");
const fs = require("fs"); // Added for logging

async function main() {
  const AetherNet = await hre.ethers.getContractFactory("AetherNet");
  const aetherNet = await AetherNet.deploy();
  await aetherNet.deployed();
  console.log("AetherNet deployed to:", aetherNet.address);

  // THIS LINE WILL BE UPDATED BY aether_net.sh with the actual phiScore
  const phiScore = 1000; // Initial placeholder value

  await aetherNet.setPhiScore(phiScore);
  console.log(`PhiScore set to: ${phiScore / 1000}`);

  const logFile = "/data/data/com.termux/files/home/Projects/AetherQuanta/Aether-Quanta-Project-/network_log.txt";
  const logMessage = `[${new Date().toISOString()}] AetherNet deployed to: ${aetherNet.address}, PhiScore: ${phiScore / 1000}\n`;
  fs.appendFileSync(logFile, logMessage);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

