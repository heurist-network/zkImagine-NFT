import { expect } from "chai";
import { ethers }  from "hardhat";
import { Contract, Wallet } from "zksync-ethers";
import { getWallet, deployContract, LOCAL_RICH_WALLETS } from '../../deploy/utils';

describe("ZkImagine - signatureFreeMint", function () {
    let nftContract: any;
    let ownerWallet: Wallet;
    let userWallet: Wallet;
    let anotherUserWallet: Wallet;
    let snapshotTime: number;

    this.beforeEach(async function () {
        ownerWallet = getWallet(LOCAL_RICH_WALLETS[0].privateKey);
        userWallet = getWallet(LOCAL_RICH_WALLETS[1].privateKey);
        anotherUserWallet = getWallet(LOCAL_RICH_WALLETS[2].privateKey);

        nftContract = await deployContract(
            "ZkImagine",
            ["MyNFTName", "MNFT", "https://mybaseuri.com/token/"],
            { wallet: ownerWallet, silent: true }
        );

    });

    it("Should allow minting with a valid signature", async function () {
        const userAddress = await userWallet.getAddress();
        const hash = ethers.solidityPackedKeccak256(["address"], [userAddress]);
        const signature = await ownerWallet.signMessage(ethers.getBytes(hash));

        const totalSupplyBefore = await nftContract.totalSupply();
        const tx = await nftContract.connect(userWallet).signatureFreeMint(hash, signature, "model-id-1", "image-id-1");
        await tx.wait();

        await expect(tx).to.emit(nftContract, 'SignatureFreeMint')
            .withArgs(userAddress, totalSupplyBefore + BigInt(1), "model-id-1", "image-id-1");

        const balance = await nftContract.balanceOf(userAddress);
        expect(balance).to.equal(BigInt(1));
    });

    it("Should not allow minting with an invalid hash", async function () {
        const userAddress = await userWallet.getAddress();
        const invalidHash = ethers.solidityPackedKeccak256(["uint"], [45]);
        const signature = await ownerWallet.signMessage(ethers.getBytes(invalidHash));

        await expect(nftContract.connect(userWallet).signatureFreeMint(invalidHash, signature, "model-id-2", "image-id-2"))
            .to.be.revertedWith("Invalid hash");
    });

    // it("Should not allow minting twice within 24 hours using the same signature", async function () {
    //     const userAddress = await anotherUserWallet.getAddress();
    //     const hash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(userAddress));
    //     const signature = await signMessage(ownerWallet, userAddress);

    //     // First mint
    //     await nftContract.connect(anotherUserWallet).signatureFreeMint(hash, signature, "model-id-4", "image-id-4");

    //     // Attempt second mint
    //     await expect(nftContract.connect(anotherUserWallet).signatureFreeMint(hash, signature, "model-id-5", "image-id-5"))
    //         .to.be.revertedWith("Already minted today");
    // });

    // it("Should allow minting again after 24 hours using the same signature", async function () {
    //     const userAddress = await anotherUserWallet.getAddress();
    //     const hash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(userAddress));
    //     const signature = await signMessage(ownerWallet, userAddress);

    //     // Advance time by 24 hours and 1 second
    //     await time.increase(24 * 60 * 60 + 1);

    //     const totalSupplyBefore = await nftContract.totalSupply();
    //     const tx = await nftContract.connect(anotherUserWallet).signatureFreeMint(hash, signature, "model-id-6", "image-id-6");
    //     await tx.wait();

    //     await expect(tx).to.emit(nftContract, 'SignatureFreeMint')
    //         .withArgs(userAddress, totalSupplyBefore + BigInt(1), "model-id-6", "image-id-6");

    //     const balance = await nftContract.balanceOf(userAddress);
    //     expect(balance).to.equal(BigInt(2));
    // });

    it("Should allow different users to mint with different signatures", async function () {
        const user1Address = await userWallet.getAddress();
        const user2Address = await anotherUserWallet.getAddress();

        const userAddress = await userWallet.getAddress();
        const hash1 = ethers.solidityPackedKeccak256(["address"], [user1Address]);
        const hash2 = ethers.solidityPackedKeccak256(["address"], [user2Address]);
        const signature1 = await ownerWallet.signMessage(ethers.getBytes(hash1));
        const signature2 = await ownerWallet.signMessage(ethers.getBytes(hash2));

        // User 1 mints
        await nftContract.connect(userWallet).signatureFreeMint(hash1, signature1, "model-id-7", "image-id-7");

        // User 2 mints
        await nftContract.connect(anotherUserWallet).signatureFreeMint(hash2, signature2, "model-id-8", "image-id-8");

        const balance1 = await nftContract.balanceOf(user1Address);
        const balance2 = await nftContract.balanceOf(user2Address);

        expect(balance1).to.be.above(BigInt(0));
        expect(balance2).to.be.above(BigInt(0));
    });

    it("Should not allow non-owner to sign valid minting messages", async function () {
        const userAddress = await userWallet.getAddress();
        const hash = ethers.solidityPackedKeccak256(["address"], [userAddress]);
        const signature = await anotherUserWallet.signMessage(ethers.getBytes(hash));

        await expect(nftContract.connect(userWallet).signatureFreeMint(hash, signature, "model-id-9", "image-id-9"))
            .to.be.revertedWith("Invalid signature");
    });
});