
import { expect } from "chai";
import { ethers }  from "hardhat";
import { Contract, Wallet } from "zksync-ethers";
import { getWallet, deployContract, LOCAL_RICH_WALLETS } from '../../deploy/utils';



interface PartnerFreeMintArgs {
    to: string;
    partnerNFTAddress: string;
    modelId: string;
    imageId: string;
}

async function callPartnerFreeMint(contract: any, args: PartnerFreeMintArgs, signer: Wallet) {
    return contract.connect(signer).partnerFreeMint(args.to, args.partnerNFTAddress, args.modelId, args.imageId);
}

async function setDateTime(timestamp: number) {
    await ethers.provider.send('evm_setNextBlockTimestamp', [timestamp]);
    await ethers.provider.send('evm_mine'); // Mine the block with the set timestamp
}

describe("Timestamp Test - partnerFreeMint", function () {
    let nftContract: any;
    let ownerWallet: Wallet;
    let partnerNFTAddress: string;
    let partnerNFTContract: any;
    let partnerNFTHolderWallet: Wallet;
    let nonPartnerWallet: Wallet;
    let snapshotTime: number;


    before(async function () {
        ownerWallet = getWallet(LOCAL_RICH_WALLETS[0].privateKey);
        partnerNFTHolderWallet = getWallet(LOCAL_RICH_WALLETS[1].privateKey);
        nonPartnerWallet = getWallet(LOCAL_RICH_WALLETS[2].privateKey);

        partnerNFTContract = await deployContract("MockPartnerNFT", ["PartnerNFT", "PNFT", "https://mybaseuri.com/token/"], { wallet: ownerWallet, silent: true });
        partnerNFTAddress = await partnerNFTContract.getAddress();

        nftContract = await deployContract(
            "ZkImagine",
            ["MyNFTName", "MNFT", "https://mybaseuri.com/token/"],
            { wallet: ownerWallet, silent: true }
        );

        await nftContract.addWhitelistedNFT(partnerNFTAddress);
        await partnerNFTContract.mint(partnerNFTHolderWallet.getAddress());
        snapshotTime = Math.floor(Date.now() / 1000);
    });


    it("Should allow partner NFT holder to mint a new NFT", async function () {

        const args: PartnerFreeMintArgs = {
            to: await partnerNFTHolderWallet.getAddress(),
            partnerNFTAddress: partnerNFTAddress,
            modelId: 'model-id-1',
            imageId: 'image-id-1'
        };

        const totalSupplyBefore = await nftContract.totalSupply();
        const tx = await callPartnerFreeMint(nftContract, args, partnerNFTHolderWallet);
        await tx.wait();

        await expect(tx).to.emit(nftContract, 'PartnerFreeMint')
            .withArgs(args.to, args.partnerNFTAddress, totalSupplyBefore + BigInt(1), args.modelId, args.imageId);

        const balance = await nftContract.balanceOf(partnerNFTHolderWallet.getAddress());
        expect(balance).to.equal(BigInt(1));

        const block = await ethers.provider.getBlock('latest');
        console.log("Current Block Timestamp after mint:", block.timestamp);

        // update snapshotTime
        snapshotTime = block.timestamp;
    });

    it("Should not allow minting twice within 24 hours", async function () {
        const startDate = snapshotTime + (24 * 60 * 60 - 1000); // Advance time within 24 hours by 1000 second
        await setDateTime(startDate);

        const args: PartnerFreeMintArgs = {
            to: await partnerNFTHolderWallet.getAddress(),
            partnerNFTAddress: partnerNFTAddress,
            modelId: 'model-id-3',
            imageId: 'image-id-3'
        };

        await expect(callPartnerFreeMint(nftContract, args, partnerNFTHolderWallet))
            .to.be.revertedWith("Already minted today");
    });

    it("should set the correct timestamp and not revert", async function () {

        const startDate = snapshotTime + (24 * 60 * 60 + 1000); // Advance time by 24 hours and 1000 second
        await setDateTime(startDate);

        const args: PartnerFreeMintArgs = {
            to: await partnerNFTHolderWallet.getAddress(),
            partnerNFTAddress: partnerNFTAddress,
            modelId: 'model-id-3',
            imageId: 'image-id-3'
        };

        const tx = await callPartnerFreeMint(nftContract, args, partnerNFTHolderWallet);
        await tx.wait();

        const balance = await nftContract.balanceOf(partnerNFTHolderWallet.getAddress());
        expect(balance).to.equal(BigInt(2));

    });
});