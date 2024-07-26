import { getWallet } from "../utils";
import { Deployer } from '@matterlabs/hardhat-zksync';
import { HardhatRuntimeEnvironment } from "hardhat/types";

export default async function (hre: HardhatRuntimeEnvironment) {
    const wallet = getWallet();
    const deployer = new Deployer(hre, wallet);

    const proxyAddress = '0xBC25a6EF4884A9FF0A8D7F637eb3441d62002F0b';

    const contractV2Artifact = await deployer.loadArtifact('ZkImagineV2');
    const upgradedContract = await hre.zkUpgrades.upgradeProxy(deployer.zkWallet, proxyAddress, contractV2Artifact);
    console.log('Successfully upgraded ZkImagine to ZkImagineV2');

    upgradedContract.connect(deployer.zkWallet);
    // wait some time before the next call
    await new Promise((resolve) => setTimeout(resolve, 2000));



    // const initTx = await upgradedContract.initialize(name, symbol, baseTokenURI, mintFee.toString(), referralDiscount.toString(), cooldownWindow.toString(), timestamp.toString());
    // const receipt = await initTx.wait();

    // console.log('ZkImagineV2 initialized!', receipt.hash);
}
