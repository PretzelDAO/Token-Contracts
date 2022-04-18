const fs = require('fs')
const { NFTStorage, File } = require('nft.storage')
const dotenv = require('dotenv');
dotenv.config();

async function uploadData(baseFileName, isJPG) {

  let imgType
  if (isJPG)
    imgType = 'jpg'
  else
    imgType = 'png'

  const client = new NFTStorage({ token: process.env.NFT_STORAGE_API_KEY });

  console.log('Uploding image...');
  const imageData = fs.readFileSync(`./assets/${baseFileName}.${imgType}`)
  const imageFile = new File([imageData], `${baseFileName}.${imgType}`, { type: `image/${imgType}` });
  const imageCID = await client.storeBlob(imageFile);

  console.log('Uploding mp4...');
  const animationData = fs.readFileSync(`./assets/${baseFileName}.mp4`)
  const animationFile = new File([animationData], `${baseFileName}.mp4`, { type: ' video/mp4' });
  const animationCID = await client.storeBlob(animationFile);


  return {
    imageCID,
    animationCID
  }

}

async function main() {
  const { imageCID, animationCID } = await uploadData('active_members_badge', false)

  console.log('================================================');
  console.log(`Image CID: ${imageCID}`)
  console.log(`Animation CID: ${animationCID}`)
  console.log('Put those two hashes in the argument.js file');
  console.log('================================================');


}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });