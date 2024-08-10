import { getWallet } from "../utils";
import { Deployer } from '@matterlabs/hardhat-zksync';
import { ethers } from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";

export default async function (hre: HardhatRuntimeEnvironment) {
    const wallet = getWallet();
    const deployer = new Deployer(hre, wallet);
    const deployerAddress = await wallet.getAddress();

    const contractArtifact = await deployer.loadArtifact("zkImagine");
    const name = "zkImagine";
    const symbol = "ZKIMAG";
    const baseTokenURI = "https://test.com/"; // change to your base token URI when in mainnet
    const mintFee = ethers.parseEther("0.0001");
    console.log("Deploying zkImagine NFT contract with mint fee of", mintFee.toString());
    const referralDiscount = 10;
    // time window for cooldown
    const cooldownWindow = 60; // 60  sec for test, would be 1 day in prod
    // current timestamp as input 
    const timestamp = Math.floor(Date.now() / 1000);

    // await deployContract("zkImagine", [name, symbol, baseTokenURI, mintFee.toString(), referralDiscount.toString(), cooldownWindow.toString(), timestamp.toString()]);
    const zkImagine = await hre.zkUpgrades.deployProxy(
        getWallet(),
        contractArtifact,
        [name, symbol, baseTokenURI, mintFee.toString(), referralDiscount.toString(), cooldownWindow.toString(), timestamp.toString(),deployerAddress],
        { initializer: 'initialize' }
    );

    await zkImagine.waitForDeployment();
}
