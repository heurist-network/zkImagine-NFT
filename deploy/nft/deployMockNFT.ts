import { deployContract } from "../utils";
import { ethers } from "hardhat";

// This script is used to deploy an NFT contract
// as well as verify it on Block Explorer if possible for the network
export default async function () {
  const name = "PartnerNFT2";
  const symbol = "PNFT2";
  const baseTokenURI = "google.com/";

  await deployContract("MockPartnerNFT", [name, symbol, baseTokenURI]);
}
