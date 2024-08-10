import { ethers } from "hardhat";
import { getWallet, Deployer } from "../deploy/utils";

import path from 'path';

import fs from 'fs';

const abiPath = path.join(__dirname, '', 'abi.json');
console.log(abiPath);

function sleep(ms: number) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// npx hardhat run scripts/mintTransaction.ts --network zkSyncSepoliaTestnet   
async function main() {
    const contractABI = JSON.parse(fs.readFileSync(abiPath, 'utf8'));

    // Deployed contract address and ABI
    const contractAddress = "0xBC25a6EF4884A9FF0A8D7F637eb3441d62002F0b";

    // Connect to the contract
    const zkImagine = new ethers.Contract(contractAddress, contractABI, ethers.provider);
    // Transfer some ETH to each new wallet
    // const [deployer] = await ethers.getSigners();
    const deployerWallet = getWallet();
    // Fetch the current nonce for the deployer wallet
    let nonce = await ethers.provider.getTransactionCount(deployerWallet.address);
    console.log("Deployer wallet nonce:", nonce);

    console.log("deployer", deployerWallet.address);
    // Create 10 wallets
    const wallets = [];
    for (let i = 0; i < 10; i++) {
        let wallet = ethers.Wallet.createRandom().connect(ethers.provider);
        console.log(`Created wallet ${i + 1}:`, wallet.address);
        wallets.push(wallet);


        const tx = await deployerWallet.sendTransaction({
            to: wallet.address,
            value: ethers.parseEther("0.05"),
            nonce: nonce 
        });
        
        await sleep(1000); // sleep for 1000ms (1 second)
        await tx.wait();
        // Add a delay after each transfer
        await sleep(5000); // sleep for 1000ms (1 second)

        // Increment the nonce for the next transaction
        nonce++;
        console.log(`Transferred ETH to wallet ${i + 1}:`, wallet.address);
    }

    // Call the setValue function with each wallet
    for (let i = 0; i < wallets.length; i++) {
        const wallet = wallets[i];
        const zkImagineWithWallet = zkImagine.connect(wallet);
         
        // generate random number between 0 and 1
        const randomNumber = Math.floor(Math.random() * 2);
        console.log(`randomNumber: ${randomNumber}`);
        // secondary address is randomly pick from zero address or minter address
        const secondaryAddress = randomNumber === 0 ? ethers.ZeroAddress : wallet.address;


        // Call the setValue function
        const tx = await zkImagineWithWallet.mint(
            wallet.address,
            secondaryAddress,
            `model-id-${i + 1}`,
            `image-id-${i + 1}`,
            { value: ethers.parseEther("0.0001") });
        await tx.wait();


        await sleep(1000); // sleep for 1000ms (1 second)

        console.log(`Wallet ${i + 1} minted an NFT!`);
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});