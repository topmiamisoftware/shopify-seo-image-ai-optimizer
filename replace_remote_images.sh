#!/usr/local/bin/bash
. ./utility.sh

# CSV file and image folder
CSV_FILE="image_urls.txt"
IMAGE_FOLDER="renamed_images"
COMPLETION_LOG_FILE="logs/upload-logs.log"

DOWNLOADED_IMAGES_BACKUP="backup_renamed_compressed_resized_images"

echo "Starting SEO Image Optimizer...";
echo "Starting SEO Image Optimizer..." >> "$COMPLETION_LOG_FILE";

# Let's create a backup of our folder.
if [[ ! -d $DOWNLOADED_IMAGES_BACKUP ]]; then
    cp -r $IMAGE_FOLDER $DOWNLOADED_IMAGES_BACKUP
fi

# add counter, every 20 products done, stop the script and
# manually check if product names and handles match the new file name.
# I put this here so that you can check if your images are being replaced correctly.
# After a few runs were verified, I set this to a number larger than the total images I had.
counter=0;

# Read the input file CSV_FILE to delete and upload the new images
declare -a imageSrcArray

while IFS= read -r line; do
    imageSrcArray+=("$line")
done < "$CSV_FILE"

# Now let's uplaod the new images. We do this to make media placement easier
for i in "${!imageSrcArray[@]}"; do

  declare -a lineArray;

  # Let's split the array and save it to a local array
  IFS=',' read -ra lineArray <<< "${imageSrcArray[i]}"

  productID="${lineArray[0]}"
  productHandle="${lineArray[1]}"
  productImageURL="${lineArray[2]}"
  productMediaID="${lineArray[3]}"
  productImagePlacement="${lineArray[4]}"
  productImageOrderDirectory="${IMAGE_FOLDER}/${productHandle}/${productImagePlacement}"

  # If the productImageOrderDirectory directory does not exist is because we already processed it
  # in a different run or something else went wrong. Skip it.
  if  [[ ! -d  $productImageOrderDirectory ]]; then
    echo "Skipping ${productID}. ${productImageOrderDirectory} not found." >> "$COMPLETION_LOG_FILE";
    continue;
  fi

  # We are currently generating the alt text from the file name. However, we'll want to call Gemini to do this.
  # Rewrite the alt text
  fileName=$(ls ${productImageOrderDirectory} | head -n 1);

  alt_text=$fileName;
  # removes dashes -
  alt_text=${alt_text//-/' '};
  # removes underscores _
  alt_text=${alt_text//_/' '};
  # removes the forward slash
  alt_text=${alt_text//\/};
  # removes the file extension
  alt_text=${alt_text//.*};

  fileToReplace="{
    \"input\": [
      {
        \"filename\":\"${fileName}\",
        \"mimeType\":\"image/webp\",
        \"httpMethod\":\"PUT\",
        \"resource\":\"PRODUCT_IMAGE\"
      }
    ]
  }"

  echo "Generating Shopify staged upload request...";
  echo "Generating Shopify staged upload request..." >> "$COMPLETION_LOG_FILE"

  QUERY_DECODED=$(generateStagedUploadQuery)

  stagedUploadRequest=$(curl -X POST \
    https://${SHOPIFY_STORE}.myshopify.com/admin/api/2025-07/graphql.json \
    -H 'Content-Type: application/json' \
    -H "X-Shopify-Access-Token: ${ADMIN_API_TOKEN}" \
    -d "{ \"query\":\"${QUERY_DECODED}\", \"variables\": ${fileToReplace} }"
  )

  echo "Shopify Staged Upload Request Response... ${stagedUploadRequest}" >> "$COMPLETION_LOG_FILE"
  echo "Shopify Staged Upload Request Complete.";

  uploadUrl=$(echo $stagedUploadRequest | jq -r '.data.stagedUploadsCreate.stagedTargets[0].url');
  resourceUrl=$(echo $stagedUploadRequest | jq -r '.data.stagedUploadsCreate.stagedTargets[0].resourceUrl');

  echo "Upload URL ${uploadUrl} - " >> "$COMPLETION_LOG_FILE";
  echo "Upload Resource URL ${resourceUrl} - " >> "$COMPLETION_LOG_FILE";

  uploadProductImageRequest=$(curl -X PUT -T $productImageOrderDirectory/$fileName \
    -H 'content_type:image/webp' \
    -H 'acl:private' \
    $uploadUrl
  )

  echo "Image Uploaded using PUT Request: ${uploadProductImageRequest}" >> "$COMPLETION_LOG_FILE"

  # Now we need to create the image from the product.
  fileCreateRequest=$(
    curl -X POST \
    https://${SHOPIFY_STORE}.myshopify.com/admin/api/2025-10/graphql.json \
    -H 'Content-Type: application/json' \
    -H "X-Shopify-Access-Token: ${ADMIN_API_TOKEN}" \
    -d "{
      \"query\": \"mutation fileCreate(\$files: [FileCreateInput!]!) { fileCreate(files: \$files) { files { id fileStatus alt createdAt ... on MediaImage { image { width height } } } userErrors { field message } } }\",
      \"variables\": {
        \"files\": [
          {
            \"alt\": \"${alt_text}\",
            \"contentType\": \"IMAGE\",
            \"originalSource\": \"${resourceUrl}\"
          }
        ]
      }
    }"
  )

  echo "Created image media in Shopify: ${productID} with local image ${fileName}.";
  echo "Created image media in Shopify: ${productID} with local image ${fileName}."  >> "${COMPLETION_LOG_FILE}";
  echo "Created image media in Shopify: ${fileCreateRequest}." >> "${COMPLETION_LOG_FILE}";

  # Now that we are sure that we have uploaded the media to the product, let's attach it and delete the one we are no longer using.
  # First let's delete the exisitng image from the product. Note that we are not using fileUpdate requests because such requests require us
  # to use the same file extension type. Meaning that replacing JPGs or other formats for webp would not be allowed.

  fileCreateStatus=$(echo $fileCreateRequest | jq -r '.data.fileCreate.files[0].fileStatus');
  newFileID=$(echo $fileCreateRequest | jq -r '.data.fileCreate.files[0].id');

  STATUS_QUERY=$(echo 'query { node(id: \"'$newFileID'\") { id ... on MediaImage { status, image { url } } } }' | base64)
  STATUS_QUERY_DECODED=$(echo $STATUS_QUERY | base64 -d | tr -d '\n');

  # I wish there was a better way. I'm not sure why Media with "UPLOADED" Status cannot be attached to products.
  while [ $fileCreateStatus == 'UPLOADED' ] || [ $fileCreateStatus == 'PROCESSING' ]; do
    # Loop the request until media is marked as ready.
    fileStatusQuery=$(
      curl -X POST \
      https://${SHOPIFY_STORE}.myshopify.com/admin/api/2025-10/graphql.json \
      -H 'Content-Type: application/json' \
      -H "X-Shopify-Access-Token: ${ADMIN_API_TOKEN}" \
      -d "{
        \"query\": \"${STATUS_QUERY_DECODED}\"
      }"
    )

    fileCreateStatus=$(echo $fileStatusQuery | jq -r '.data.node.status');

    echo "File Status Request: ${fileCreateStatus} - ${fileStatusQuery}." >> "${COMPLETION_LOG_FILE}";

    if [[ $fileCreateStatus == 'READY' ]]; then
      break
    fi

    # Let's not overwhelm the API
    sleep 4
  done


  if [[ $fileCreateStatus == 'READY' ]]; then

    fileUpdateRequest=$(
      curl -X POST \
      https://${SHOPIFY_STORE}.myshopify.com/admin/api/2025-10/graphql.json \
      -H 'Content-Type: application/json' \
      -H "X-Shopify-Access-Token: ${ADMIN_API_TOKEN}" \
      -d "{
        \"query\": \"mutation fileUpdate(\$files: [FileUpdateInput!]!) { fileUpdate(files: \$files) { files { id alt fileStatus } userErrors { field message code } } }\",
        \"variables\": {
          \"files\": [
            {
              \"id\": \"${newFileID}\",
              \"referencesToAdd\": \"${productID}\"
            }
          ]
        }
      }"
    )

    echo "Attached image media for ${productID} with local image ${fileName}." >> "${COMPLETION_LOG_FILE}";
    echo "Attached image media in Shopify: ${fileUpdateRequest}." >> "${COMPLETION_LOG_FILE}";

    fileDeleteRequest=$(
      curl -X POST \
      https://${SHOPIFY_STORE}.myshopify.com/admin/api/2025-10/graphql.json \
      -H 'Content-Type: application/json' \
      -H "X-Shopify-Access-Token: ${ADMIN_API_TOKEN}" \
      -d "{
        \"query\": \"mutation fileDelete(\$fileIds: [ID!]!) { fileDelete(fileIds: \$fileIds) { deletedFileIds userErrors { field message code } } }\",
        \"variables\": {
            \"fileIds\": [
              \"${productMediaID}\"
            ]
        }
      }"
    )

    echo "Deleted image from Shopify: ${productMediaID} - Response: ${fileDeleteRequest}";
    echo "Deleted image from Shopify: ${productMediaID} - Response: ${fileDeleteRequest}" >> "${COMPLETION_LOG_FILE}";
  fi

  let counter++

  if [[ "$counter" -eq 40 ]]; then
    echo "Stopping... script completed." >> "$COMPLETION_LOG_FILE";
    echo "Stopping... script completed.";
    break
  fi
done