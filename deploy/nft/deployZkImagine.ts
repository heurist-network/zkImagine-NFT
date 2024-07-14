import { deployContract } from "../utils";
import { ethers } from "hardhat";

// This script is used to deploy an NFT contract
// as well as verify it on Block Explorer if possible for the network
export default async function () {
  const name = "ZKImagine";
  const symbol = "IMAG";
  const baseTokenURI = "https://cdn.zkimagine.com/";
  const mintFee = ethers.parseEther("0.0001");
  console.log("Deploying ZkImagine NFT contract with mint fee of", mintFee.toString());
  const referralDiscount = 10;
  // time window for cooldown
  const cooldownWindow = 30; // 30  sec for test, would be 1 day in prod
  await deployContract("ZkImagine", [name, symbol, baseTokenURI, mintFee.toString(), referralDiscount.toString(),cooldownWindow.toString()]);
}
