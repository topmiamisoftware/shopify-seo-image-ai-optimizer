#!/usr/local/bin/bash

# CSV file and image folder
CSV_FILE="shopify_title_handle.csv"
IMAGE_FOLDER="downloaded_images"
COMPLETION_LOG_FILE="logs/completion-logs.log"

# Shopify API credentials
SHOPIFY_STORE=""
ADMIN_API_TOKEN=""

DOWNLOADED_IMAGES_BACKUP="backup_renamed_compressed_resized_images"


echo "Starting SEO Image Optimizer...";
echo "Starting SEO Image Optimizer..." >> "$COMPLETION_LOG_FILE";

if [[ ! -d $DOWNLOADED_IMAGES_BACKUP ]]; then
    cp -r $IMAGE_FOLDER $DOWNLOADED_IMAGES_BACKUP
fi

# add counter, every 20 products done, stop the script and
# manually check if product names and handles match the new file name.
product_counter=1;

# Let's go into the image_dir folder
cd $IMAGE_FOLDER;

for productHandle in */; do
  # Let's go into the product handle
  cd $productHandle;

  # First, we'll grab the PRODUCT ID
  cleanHandle=$(echo $productHandle | tr -d "/");
  response=$(
    curl -s -X GET "https://${SHOPIFY_STORE}/admin/api/2025-04/products.json?handle=${cleanHandle}" \
     -H "X-Shopify-Access-Token: ${ADMIN_API_TOKEN}"
  )

  # Let's save the product id and handle
  shopify_product_id=$(echo "$response" | jq -r '.products[0].id')
  shopify_product_handle=$(echo "$response" | jq -r '.products[0].title')

  # Fetch Shopify images for the product.
  response=$(curl -s -X GET "https://${SHOPIFY_STORE}/admin/api/2025-01/products/${shopify_product_id}/images.json" -H "X-Shopify-Access-Token: ${ADMIN_API_TOKEN}")

  for image in $(echo "$response" | jq -r '.images[] | @base64'); do
    # Decode the base64-encoded image object to access its fields
    _jq() {
      echo "$image" | base64 --decode | jq -r "$1"
    }

    # Access the attributes within the image object
    image_id=$(_jq '.id')

    # Delete existing Shopify image
    curl -s -X DELETE "https://${SHOPIFY_STORE}/admin/api/2025-01/products/${shopify_product_id}/images/${image_id}.json" \
      -H "X-Shopify-Access-Token: ${ADMIN_API_TOKEN}"
  done

  for imageOrder in */; do

    # Let's go into the image order dir
    cd $imageOrder;

    for file in *; do
      # Let's upload the image and delete the previous one
      echo "Generating image alt text for shopify product listing...";

      # Rewrite the alt text
      alt_text=$file;
      # removes dashes -
      alt_text=${alt_text//-/' '};
      # removes underscores _
      alt_text=${alt_text//_/' '};
      # removes the forward slash
      alt_text=${alt_text//\/};
      # removes the file extension
      alt_text=${alt_text//.*};

      # add exception handling for above curl request
      echo "Alt text generated... \"$alt_text\"";

      echo "Replacing image...";

      # Upload new image, catch and exit script if there was an error.
      curl --output >(cat >> "../../../$COMPLETION_LOG_FILE") -s --progress-bar -X POST "https://${SHOPIFY_STORE}/admin/api/2025-01/products/${shopify_product_id}/images.json" \
        -H "X-Shopify-Access-Token: ${ADMIN_API_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"image\": {\"attachment\": \"$(base64 -i "$file")\", \"filename\": \"$file\", \"alt\": \"$alt_text\", \"position\": \"$(echo $imageOrder | tr -d "/")\"}}";

      echo -e "🔄 Replaced image from Shopify handle: ${shopify_product_handle} id: ${shopify_product_id} with local image (${productHandle}${imageOrder}${file})"
    done

    # Leave the imageOrder folder
    cd ..
  done
  
  # Leave the productHandle folder
  cd ..

  # remove the the product folder since all images were already optimized. Next time you run through the script, you won't have to
  # go through all the products again. If you lose a product image set, you can recover it from the backup folder we created the first time we ran
  # this script.
  rm -rf $productHandle

  let product_counter++

  if [[ "$product_counter" -eq 20 ]]; then
    echo "Stopping... script completed." >> "$COMPLETION_LOG_FILE";
    echo "Stopping... script completed. Check your product images and re-run the script.";
    break
  fi
done