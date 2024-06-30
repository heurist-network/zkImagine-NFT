import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Wallet } from "zksync-ethers";
import { getWallet, deployContract, LOCAL_RICH_WALLETS } from '../../deploy/utils';

describe("ZkImagine - Minting and Fee Functions", function () {
    let nftContract: any;
    let ownerWallet: Wallet;
    let userWallet: Wallet;
    let referrerWallet: Wallet;

    const mintFee = ethers.parseEther("0.0006") as ethers.BigNumber;
    const referralDiscountPct = 10;

    before(async function () {
        ownerWallet = getWallet(LOCAL_RICH_WALLETS[0].privateKey);
        userWallet = getWallet(LOCAL_RICH_WALLETS[1].privateKey);
        referrerWallet = getWallet(LOCAL_RICH_WALLETS[2].privateKey);

        nftContract = await deployContract(
            "ZkImagine",
            ["MyNFTName", "MNFT", "https://mybaseuri.com/token/"],
            { wallet: ownerWallet, silent: true }
        );
    });

    describe("mint function", function () {
        it("should mint an NFT without referral", async function () {
            const tx = await nftContract.connect(userWallet).mint(
                userWallet.address,
                ethers.ZeroAddress,
                "model-id-1",
                "image-id-1",
                { value: mintFee }
            );
            await tx.wait();

            expect(await nftContract.balanceOf(userWallet.address)).to.equal(1);
            // Add more assertions as needed
        });

        it("should mint an NFT with referral", async function () {
            const discountedFee = mintFee * (BigInt(100) - BigInt(referralDiscountPct))/(BigInt(100));
            const tx = await nftContract.connect(userWallet).mint(
                userWallet.address,
                referrerWallet.address,
                "model-id-2",
                "image-id-2",
                { value: discountedFee }
            );
            await tx.wait();

            expect(await nftContract.balanceOf(userWallet.address)).to.equal(2);
            // Check referral fee accrual
            expect(await nftContract.referralFeesEarned(referrerWallet.address)).to.be.above(0);
        });

        it("should revert if insufficient fee is paid", async function () {
            await expect(nftContract.connect(userWallet).mint(
                userWallet.address,
                ethers.ZeroAddress,
                "model-id-3",
                "image-id-3",
                { value: mintFee - BigInt(1) }
            )).to.be.revertedWith("Insufficient mint fee");
        });
    });

    describe("claimReferralFee function", function () {
        it("should allow referrer to claim accrued fees", async function () {
            const initialBalance = await referrerWallet.getBalance();
            const accruedFees = await nftContract.referralFeesEarned(referrerWallet.address);

            const tx = await nftContract.connect(referrerWallet).claimReferralFee();
            await tx.wait();

            const finalBalance = await referrerWallet.getBalance();
            expect(finalBalance - initialBalance).to.be.closeTo(accruedFees, ethers.parseEther("0.0001")); // Allow for gas costs
            expect(await nftContract.referralFeesEarned(referrerWallet.address)).to.equal(0);
        });

        it("should revert if no fees are available to claim", async function () {
            await expect(nftContract.connect(referrerWallet).claimReferralFee())
                .to.be.revertedWith("No referral fee earned");
        });
    });

    describe("claimFee function", function () {
        it("should allow owner to claim accumulated fees", async function () {
            const initialBalance = await ownerWallet.getBalance();
            const contractBalance = await ethers.provider.getBalance(await nftContract.getAddress());
            const totalReferralFees = await nftContract.totalReferralFees();

            const tx = await nftContract.connect(ownerWallet).claimFee();
            await tx.wait();

            const finalBalance = await ownerWallet.getBalance();
            const expectedClaim = contractBalance - totalReferralFees;
            expect(finalBalance- initialBalance).to.be.closeTo(expectedClaim, ethers.parseEther("0.0001")); // Allow for gas costs
        });

        it("should revert if non-owner tries to claim fees", async function () {
            await expect(nftContract.connect(userWallet).claimFee())
                .to.be.revertedWith("Ownable: caller is not the owner");
        });
    });

    describe("Integrated tests", function () {
        it("should correctly handle minting, referral, and fee distribution", async function () {
            // Mint with referral
            const discountedFee = mintFee * (BigInt(100) - BigInt(referralDiscountPct))/BigInt(100);
            await nftContract.connect(userWallet).mint(
                userWallet.address,
                referrerWallet.address,
                "model-id-4",
                "image-id-4",
                { value: discountedFee }
            );

            // Check referral fee accrual
            const referralFee = await nftContract.referralFeesEarned(referrerWallet.address);
            expect(referralFee).to.be.above(0);

            // Referrer claims fee
            const referrerInitialBalance = await referrerWallet.getBalance();
            await nftContract.connect(referrerWallet).claimReferralFee();
            const referrerFinalBalance = await referrerWallet.getBalance();
            expect(referrerFinalBalance - referrerInitialBalance).to.be.closeTo(referralFee, ethers.parseEther("0.0001"));

            // Owner claims remaining fees
            const ownerInitialBalance = await ownerWallet.getBalance();
            await nftContract.connect(ownerWallet).claimFee();
            const ownerFinalBalance = await ownerWallet.getBalance();
            expect(ownerFinalBalance - ownerInitialBalance).to.be.above(0);

            // Verify contract balance is correct (should only have unclaimed referral fees)
            const contractFinalBalance = await ethers.provider.getBalance(await nftContract.getAddress());
            const totalReferralFees = await nftContract.totalReferralFees();
            expect(contractFinalBalance).to.equal(totalReferralFees);
        });
    });
});