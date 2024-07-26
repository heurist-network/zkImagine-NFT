import { getWallet } from "../utils";
import { Deployer } from '@matterlabs/hardhat-zksync';
import { ethers } from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";

export default async function (hre: HardhatRuntimeEnvironment) {
    const wallet = getWallet();
    const deployer = new Deployer(hre, wallet);

    const contractArtifact = await deployer.loadArtifact("ZkImagine");
    const name = "ZKImagine";
    const symbol = "IMAG";
    const baseTokenURI = "https://cdn.zkimagine.com/";
    const mintFee = ethers.parseEther("0.0001");
    console.log("Deploying ZkImagine NFT contract with mint fee of", mintFee.toString());
    const referralDiscount = 10;
    // time window for cooldown
    const cooldownWindow = 60; // 60  sec for test, would be 1 day in prod
    // current timestamp as input 
    const timestamp = Math.floor(Date.now() / 1000);

    // await deployContract("ZkImagine", [name, symbol, baseTokenURI, mintFee.toString(), referralDiscount.toString(), cooldownWindow.toString(), timestamp.toString()]);
    const ZkImagine = await hre.zkUpgrades.deployProxy(
        getWallet(),
        contractArtifact,
        [name, symbol, baseTokenURI, mintFee.toString(), referralDiscount.toString(), cooldownWindow.toString(), timestamp.toString()],
        { initializer: 'initialize' }
    );

    await ZkImagine.waitForDeployment();
}
