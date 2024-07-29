import { expect } from "chai";
import { ethers } from "hardhat";
import * as hre from "hardhat";
import { Wallet, Contract } from "zksync-ethers";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { getWallet, deployContract, LOCAL_RICH_WALLETS } from '../../deploy/utils';

// yarn hardhat node-zksync
// npx hardhat test  ./test/signatureFreeMint/newSignatureFreemint.test.ts --network inMemoryNode
describe("ZkImagine Contract", function () {
  let zkImagine: any;
  let owner: Wallet;
  let user1: Wallet;
  let user2: Wallet;
  let signer: Wallet;
  const COOLDOWN_WINDOW = 60; // 60 seconds for test

  beforeEach(async function () {
    // const [ownerSigner, user1Signer, user2Signer] = await ethers.getSigners();
    // owner = new Wallet(ownerSigner.privateKey);
    // user1 = new Wallet(user1Signer.privateKey);
    // user2 = new Wallet(user2Signer.privateKey);


    owner = getWallet(LOCAL_RICH_WALLETS[0].privateKey);
    user1 = getWallet(LOCAL_RICH_WALLETS[1].privateKey);
    user2 = getWallet(LOCAL_RICH_WALLETS[2].privateKey);
    signer = getWallet(LOCAL_RICH_WALLETS[3].privateKey);

    const signerAddress = await signer.getAddress();
    

    const deployer = new Deployer(hre, owner);
    const artifact = await deployer.loadArtifact("ZkImagine");

    const name = "ZKImagine";
    const symbol = "IMAG";
    const baseTokenURI = "https://cdn.zkimagine.com/";
    const mintFee = ethers.parseEther("0.0001");
    const referralDiscount = 10;
    const timestamp = Math.floor(Date.now() / 1000);


    zkImagine = await hre.zkUpgrades.deployProxy(
      owner,
      artifact,
      [name, symbol, baseTokenURI, mintFee.toString(), referralDiscount.toString(), COOLDOWN_WINDOW.toString(), timestamp.toString(),signerAddress],
      { initializer: 'initialize', kind: 'uups' }
    );

    await zkImagine.waitForDeployment();
  });

  it("Should set the initial values correctly", async function () {
    expect(await zkImagine.name()).to.equal("ZKImagine");
    expect(await zkImagine.symbol()).to.equal("IMAG");
    expect(await zkImagine.mintFee()).to.equal(ethers.parseEther("0.0001"));
    expect(await zkImagine.referralDiscountPct()).to.equal(10);
    expect(await zkImagine.freeMintCooldownWindow()).to.equal(COOLDOWN_WINDOW);
    expect(await zkImagine.signer()).to.equal(await signer.getAddress());
  });

  it("Should allow minting with a valid signature", async function () {
    const userAddress = await user1.getAddress();
    const hash = ethers.solidityPackedKeccak256(["address"], [userAddress]);
    const signature = await signer.signMessage(ethers.getBytes(hash));

    const totalSupplyBefore = await zkImagine.totalSupply();
    const tx = await zkImagine.connect(user1).signatureFreeMint(userAddress, hash, signature, "model-id-1", "image-id-1");
    await tx.wait();

    await expect(tx).to.emit(zkImagine, 'SignatureFreeMint')
      .withArgs(userAddress, totalSupplyBefore + BigInt(1), "model-id-1", "image-id-1");

    const balance = await zkImagine.balanceOf(userAddress);
    expect(balance).to.equal(BigInt(1));
  });

  it("Should not allow minting with an invalid hash", async function () {
    const userAddress = await user1.getAddress();
    const invalidHash = ethers.solidityPackedKeccak256(["uint"], [45]);
    const signature = await signer.signMessage(ethers.getBytes(invalidHash));

    await expect(zkImagine.connect(user1).signatureFreeMint(userAddress, invalidHash, signature, "model-id-2", "image-id-2"))
      .to.be.revertedWith("Invalid hash");
  });

  it("Should not allow minting twice within cooldown window using the same signature", async function () {
    const userAddress = await user2.getAddress();
    const hash = ethers.solidityPackedKeccak256(["address"], [userAddress]);
    const signature = await signer.signMessage(ethers.getBytes(hash));

    // First mint
    await zkImagine.connect(user2).signatureFreeMint(userAddress, hash, signature, "model-id-4", "image-id-4");

    // Attempt second mint
    await expect(zkImagine.connect(user2).signatureFreeMint(userAddress, hash, signature, "model-id-5", "image-id-5"))
      .to.be.revertedWith("Next signature mint time not reached");
  });

  //   it("Should allow minting again after cooldown window using the same signature", async function () {
  //     const userAddress = await user2.getAddress();
  //     const hash = ethers.solidityPackedKeccak256(["address"], [userAddress]);
  //     const signature = await owner.signMessage(ethers.getBytes(hash));

  //     // First mint
  //     await zkImagine.connect(user2).signatureFreeMint(hash, signature, "model-id-6", "image-id-6");

  //     // Advance time by cooldown window + 1 second
  //     await time.increase(COOLDOWN_WINDOW + 1);

  //     const totalSupplyBefore = await zkImagine.totalSupply();
  //     const tx = await zkImagine.connect(user2).signatureFreeMint(hash, signature, "model-id-7", "image-id-7");
  //     await tx.wait();

  //     await expect(tx).to.emit(zkImagine, 'SignatureFreeMint')
  //       .withArgs(userAddress, totalSupplyBefore + BigInt(1), "model-id-7", "image-id-7");

  //     const balance = await zkImagine.balanceOf(userAddress);
  //     expect(balance).to.equal(BigInt(2));
  //   });

  it("Should not allow non-signer to sign valid minting messages", async function () {
    const userAddress = await user1.getAddress();
    const hash = ethers.solidityPackedKeccak256(["address"], [userAddress]);
    const signature = await user2.signMessage(ethers.getBytes(hash));

    await expect(zkImagine.connect(user1).signatureFreeMint(userAddress, hash, signature, "model-id-10", "image-id-10"))
      .to.be.revertedWith("Invalid signature");
  });

  it("Should not allow reinitialization", async function () {
    await expect(zkImagine.initialize(
      "AnotherName",
      "ANFT",
      "https://anotheruri.com/token/",
      ethers.parseEther("0.2"),
      20,
      COOLDOWN_WINDOW * 2,
      Math.floor(Date.now() / 1000),
      await signer.getAddress()
    )).to.be.revertedWith("Initializable: contract is already initialized");
  });
});