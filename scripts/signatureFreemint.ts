import { ethers } from "hardhat";
import { getWallet } from "../deploy/utils";
import path from 'path';
import fs from 'fs';

const abiPath = path.join(__dirname, '', 'abi.json');
console.log(abiPath);

function sleep(ms: number) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// npx hardhat run scripts/signatureFreeMint.ts --network zkSyncSepoliaTestnet   
async function main() {
    const contractABI = JSON.parse(fs.readFileSync(abiPath, 'utf8'));

    // Deployed contract address
    const contractAddress = "0x0291715974a808f81DeEa4B35fe1522D70935E38";

    // Connect to the contract
    const zkImagine = new ethers.Contract(contractAddress, contractABI, ethers.provider);

    // Get the deployer wallet (owner)
    const deployerWallet = getWallet();
    console.log("Deployer wallet:", deployerWallet.address);

    // Create 3 wallets for testing
    const wallets = [];
    for (let i = 0; i < 2; i++) {
        let wallet = ethers.Wallet.createRandom().connect(ethers.provider);
        console.log(`Created wallet ${i + 1}:`, wallet.address);
        wallets.push(wallet);

        // Transfer some ETH to the new wallet
        const tx = await deployerWallet.sendTransaction({
            to: wallet.address,
            value: ethers.parseEther("0.08")
        });
        await tx.wait();
        console.log(`Transferred ETH to wallet ${i + 1}:`, wallet.address);

        await sleep(5000); // Sleep for 10 seconds between transfers
    }

    // Perform signature free mint for each wallet
    for (let i = 0; i < wallets.length; i++) {
        const wallet = wallets[i];
        const userAddress = await wallet.getAddress();

        // Create the hash
        const hash = ethers.solidityPackedKeccak256(["address"], [userAddress]);

        // Sign the hash with the deployer wallet (owner)
        const signature = await deployerWallet.signMessage(ethers.getBytes(hash));

        // Connect the contract to the user's wallet
        const zkImagineWithWallet = zkImagine.connect(wallet);

        // Call the signatureFreeMint function
        const tx = await zkImagineWithWallet.signatureFreeMint(
            hash,
            signature,
            `model-id-${i + 1}`,
            `image-id-${i + 1}`
        );
        await tx.wait();

        console.log(`Wallet ${i + 1} performed signature free mint!`);

        await sleep(10000); // Sleep for 10 seconds between mints
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});