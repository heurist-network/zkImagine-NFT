import { getWallet } from "../utils";
import { Deployer } from '@matterlabs/hardhat-zksync';
import { HardhatRuntimeEnvironment } from "hardhat/types";

export default async function (hre: HardhatRuntimeEnvironment) {
    const wallet = getWallet();
    const deployer = new Deployer(hre, wallet);

    const proxyAddress = '0x0291715974a808f81DeEa4B35fe1522D70935E38';

    const contractV2Artifact = await deployer.loadArtifact('ZkImagine');
    const upgradedContract = await hre.zkUpgrades.upgradeProxy(deployer.zkWallet, proxyAddress, contractV2Artifact);
    console.log('Successfully upgraded ZkImagine to ZkImagine');

    upgradedContract.connect(deployer.zkWallet);
    // wait some time before the next call
    await new Promise((resolve) => setTimeout(resolve, 2000));



    // const initTx = await upgradedContract.initialize(name, symbol, baseTokenURI, mintFee.toString(), referralDiscount.toString(), cooldownWindow.toString(), timestamp.toString());
    // const receipt = await initTx.wait();

    // console.log('ZkImagineV2 initialized!', receipt.hash);
}
