import fs from 'fs'
import path from 'path'
import { NFTStorage, File } from 'nft.storage'
import dotenv from 'dotenv';
dotenv.config();

async function main() {
  const storage = new NFTStorage({ token: process.env.NFT_STORAGE_API_KEY });

  const directory = [];

  for (const id of Array.from(Array(5).keys())) {
    const fileData = fs.readFileSync(`./assets/og_token.gif`)
    const imageFile = new File([fileData], `W3B_OG_TOKEN-${id}.gif`, { type: 'image/gif'});
    const image = await storage.storeBlob(imageFile);

    const metadata = {
      name: `Web3 Builders Munich Early Member #${id}`,
      description: "This token represents proof of early member status of the Web3 Builders Munich community",
      image: `ipfs://${image}`,
    }

    directory.push(
      new File([JSON.stringify(metadata, null, 2)], `${id}`)
    )
  }

  const pinnedDir = await storage.storeDirectory(directory);
  console.warn(pinnedDir)

}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });