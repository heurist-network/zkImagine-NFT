import { ethers } from 'ethers';
import * as fs from 'fs';
import * as csv from 'csv-parse/sync';
import dotenv from 'dotenv';
import path from 'path';


//  npx ts-node ./generateSignatures.ts
// Load environment variables
// Load environment variables
const SIGNER_PRIVATE_KEY="<input your private key here>";

// console.log('SIGNER_PRIVATE_KEY:', process.env.SIGNER_PRIVATE_KEY);

// Get the signer's private key from .env file
// const SIGNER_PRIVATE_KEY = process.env.SIGNER_PRIVATE_KEY;

// if (!SIGNER_PRIVATE_KEY) {
//   throw new Error('SIGNER_PRIVATE_KEY is not set in the .env file');
// }

// Input and output file paths
const INPUT_CSV = 'zkimagine-whitelist.csv';
const OUTPUT_JSON = 'output_signatures.json';

interface AddressEntry {
  walletAddress: string;
  whiteListType: string;
  signature: string;
  hash: string;
}

// const userAddress = await user1.getAddress();
// const hash = ethers.solidityPackedKeccak256(["address"], [userAddress]);
// const signature = await signer.signMessage(ethers.getBytes(hash));

async function generateSignatureAndHash(walletAddress: string, signer: ethers.Wallet): Promise<{ signature: string; hash: string }> {
    const hash = ethers.solidityPackedKeccak256(['address'], [walletAddress]);
    const signature = await signer.signMessage(ethers.getBytes(hash));
    return { signature, hash };
  }

  async function processCsvAndGenerateJson(inputCsv: string, outputJson: string, signerPrivateKey: string) {
    const signer = new ethers.Wallet(signerPrivateKey);
    const fileContent = fs.readFileSync(inputCsv, 'utf-8');
    const records = csv.parse(fileContent, { columns: true, skip_empty_lines: true });

    const seenAddresses = new Set<string>();
    const result: AddressEntry[] = [];
    let validAddressCount = 0;

    for (const record of records) {
      // Remove whitespace, quotes, commas, and other non-alphanumeric characters except for 'x'
      const cleanedAddress = record.walletAddress.replace(/[^a-zA-Z0-9x]/g, '').toLowerCase();
      
      // Check if it's a valid Ethereum address
      if (!ethers.isAddress(cleanedAddress)) {
        console.warn(`Skipping invalid address: ${cleanedAddress} (original: ${record.walletAddress})`);
        continue;
      }

      // Check for duplicates
      if (seenAddresses.has(cleanedAddress)) {
        console.warn(`Skipping duplicate address: ${cleanedAddress}`);
        continue;
      }

      seenAddresses.add(cleanedAddress);
      validAddressCount++;

      const { signature, hash } = await generateSignatureAndHash(cleanedAddress, signer);
      result.push({
        walletAddress: cleanedAddress,
        whiteListType: record.whiteListType,
        signature,
        hash,
      });
    }

    fs.writeFileSync(outputJson, JSON.stringify(result, null, 2));
    return validAddressCount;
  }
processCsvAndGenerateJson(INPUT_CSV, OUTPUT_JSON, SIGNER_PRIVATE_KEY)
  .then((count) => {
    console.log(`Processed CSV and generated JSON file: ${OUTPUT_JSON}`);
    console.log(`Total valid addresses signed: ${count}`);
  })
  .catch(console.error);