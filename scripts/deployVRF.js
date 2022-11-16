const hre = require("hardhat");

async function main() {

  const VRF = await hre.ethers.getContractFactory("VRF");
  const vrf = await VRF.deploy("0xBafc298a54c972febe01bfC1371406E1D7e46E7F");

  await vrf.deployed();

  console.log(
    `VRF deployed to ${vrf.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});