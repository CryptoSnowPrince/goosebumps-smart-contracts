// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const _router = "0x31cB34991756FD1564b0DEBF2BFF3E522085EC02"; // bsc testnet goosebumps dex
  const _treasury = "0x821965C1fD8B60D4B33E23C5832E2A7662faAADC";
  const _swapFee = 10; // 0.1%
  const _swapFee0x = 5; // 0.05%
  const DEXManagement = await ethers.getContractFactory("DEXManagement");
  const dexManagement = await DEXManagement.deploy(_router, _treasury, _swapFee, _swapFee0x);

  await dexManagement.deployed();

  console.log("DEXManagement deployed to:", dexManagement.address);

  console.log("TREASURY address of DEXManagement:", await dexManagement.TREASURY());
  console.log("SWAP_FEE address of DEXManagement:", await dexManagement.SWAP_FEE());
  console.log("SWAP_FEE address of DEXManagement:", await dexManagement.SWAP_FEE_0X());
  console.log("router address of DEXManagement:", await dexManagement.dexRouter_());

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
