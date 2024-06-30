import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Wallet } from "zksync-ethers";
import { getWallet, deployContract, LOCAL_RICH_WALLETS } from '../../deploy/utils';

describe("Timestamp Test - signatureFreeMint", function () {
    let nftContract: any;
    let ownerWallet: Wallet;
    let userWallet: Wallet;
    let anotherUserWallet: Wallet;
    let snapshotTime: number;

    before(async function () {
        ownerWallet = getWallet(LOCAL_RICH_WALLETS[0].privateKey);
        userWallet = getWallet(LOCAL_RICH_WALLETS[1].privateKey);
        anotherUserWallet = getWallet(LOCAL_RICH_WALLETS[2].privateKey);

        nftContract = await deployContract(
            "ZkImagine",
            ["MyNFTName", "MNFT", "https://mybaseuri.com/token/"],
            { wallet: ownerWallet, silent: true }
        );

        snapshotTime = Math.floor(Date.now() / 1000);
    });

    async function setDateTime(timestamp: number) {
        await ethers.provider.send('evm_setNextBlockTimestamp', [timestamp]);
        await ethers.provider.send('evm_mine'); // Mine the block with the set timestamp
    }

    it("Should not allow minting twice within 24 hours using the same signature", async function () {
        const userAddress = await anotherUserWallet.getAddress();
        const hash = ethers.solidityPackedKeccak256(["address"], [userAddress]);
        const signature = await ownerWallet.signMessage(ethers.getBytes(hash));

        // First mint
        await nftContract.connect(anotherUserWallet).signatureFreeMint(hash, signature, "model-id-4", "image-id-4");

        const block = await ethers.provider.getBlock('latest');
        // Save the timestamp of the first mint
        snapshotTime = block.timestamp;

        // Set time to just under 24 hours later
        const newTime = snapshotTime + (24 * 60 * 60 - 1000); // 1000 seconds before 24 hours
        await setDateTime(newTime);

        // Attempt second mint
        await expect(nftContract.connect(anotherUserWallet).signatureFreeMint(hash, signature, "model-id-5", "image-id-5"))
            .to.be.revertedWith("Already minted today");
    });

    it("Should allow minting again after 24 hours using the same signature", async function () {
        const userAddress = await anotherUserWallet.getAddress();
        const hash = ethers.solidityPackedKeccak256(["address"], [userAddress]);
        const signature = await ownerWallet.signMessage(ethers.getBytes(hash));

        // Set time to just over 24 hours later
        const newTime = snapshotTime + (24 * 60 * 60 + 1000); // 1000 seconds after 24 hours
        await setDateTime(newTime);

        const totalSupplyBefore = await nftContract.totalSupply();
        const tx = await nftContract.connect(anotherUserWallet).signatureFreeMint(hash, signature, "model-id-6", "image-id-6");
        await tx.wait();

        await expect(tx).to.emit(nftContract, 'SignatureFreeMint')
            .withArgs(userAddress, totalSupplyBefore + BigInt(1), "model-id-6", "image-id-6");

        const balance = await nftContract.balanceOf(userAddress);
        expect(balance).to.be.above(BigInt(1)); // Should be at least 2 now
    });
});