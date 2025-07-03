//require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.28",
};
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: "0.8.20", // Sticking to 0.8.20 as previously defined and compatible with 0.8.0 AetherNet.sol
  networks: {
    sepolia: {
      url: "https://sepolia.infura.io/v3/752a640d046e4ec98d08771219c64a66", // YOUR INFURA API KEY IS CORRECTLY PLACED HERE
      accounts: ["e94ab07ab42d4bed587e19f87160577956abf43198de12192320f7e6dcb8a1dd"] // YOUR EVM PRIVATE KEY IS CORRECTLY PLACED HERE
    }
  }
};


