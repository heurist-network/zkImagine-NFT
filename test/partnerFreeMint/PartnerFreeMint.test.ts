import { expect } from "chai";
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

describe("ZkImagine - partnerFreeMint", function () {
    let nftContract: any;
    let ownerWallet: Wallet;
    let partnerNFTAddress: string;
    let partnerNFTContract: any;
    let partnerNFTHolderWallet: Wallet;
    let nonPartnerWallet: Wallet;

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
    });

    it("Should not allow minting for non-whitelisted NFT contract", async function () {
        const nonWhitelistedNFTContract = await deployContract("MockPartnerNFT", ["NonWhitelistedNFT", "NWNFT", "https://mybaseuri.com/token/"], { wallet: ownerWallet, silent: true });
        await nonWhitelistedNFTContract.mint(nonPartnerWallet.getAddress());

        const args: PartnerFreeMintArgs = {
            to: await nonPartnerWallet.getAddress(),
            partnerNFTAddress: await nonWhitelistedNFTContract.getAddress(),
            modelId: 'model-id-4',
            imageId: 'image-id-4'
        };

        await expect(callPartnerFreeMint(nftContract, args, nonPartnerWallet))
            .to.be.revertedWith("NFT contract not whitelisted");
    });

    it("Should not allow minting for non-holder of partner NFT", async function () {
        const args: PartnerFreeMintArgs = {
            to: await nonPartnerWallet.getAddress(),
            partnerNFTAddress: partnerNFTAddress,
            modelId: 'model-id-5',
            imageId: 'image-id-5'
        };

        await expect(callPartnerFreeMint(nftContract, args, nonPartnerWallet))
            .to.be.revertedWith("Recipient does not own the NFT");
    });

    it("Should allow owner to add and remove whitelisted NFT contracts", async function () {
        const newPartnerNFTContract = await deployContract("MockPartnerNFT", ["NewPartnerNFT", "NPNFT", "https://mybaseuri.com/token/"], { wallet: ownerWallet, silent: true });
        const newPartnerNFTAddress = await newPartnerNFTContract.getAddress();

        await expect(nftContract.connect(ownerWallet).addWhitelistedNFT(newPartnerNFTAddress))
            .to.emit(nftContract, 'WhitelistedNFTAdded')
            .withArgs(newPartnerNFTAddress);

        expect(await nftContract.isWhitelistedNFT(newPartnerNFTAddress)).to.be.true;

        await expect(nftContract.connect(ownerWallet).removeWhitelistedNFT(newPartnerNFTAddress))
            .to.emit(nftContract, 'WhitelistedNFTRemoved')
            .withArgs(newPartnerNFTAddress);

        expect(await nftContract.isWhitelistedNFT(newPartnerNFTAddress)).to.be.false;
    });

    it("Should not allow non-owner to add or remove whitelisted NFT contracts", async function () {
        const newPartnerNFTContract = await deployContract("MockPartnerNFT", ["NewPartnerNFT2", "NPNFT2", "https://mybaseuri.com/token/"], { wallet: ownerWallet, silent: true });
        const newPartnerNFTAddress = await newPartnerNFTContract.getAddress();

        await expect(nftContract.connect(nonPartnerWallet).addWhitelistedNFT(newPartnerNFTAddress))
            .to.be.revertedWith("Ownable: caller is not the owner");

        await expect(nftContract.connect(nonPartnerWallet).removeWhitelistedNFT(partnerNFTAddress))
            .to.be.revertedWith("Ownable: caller is not the owner");
    });
});