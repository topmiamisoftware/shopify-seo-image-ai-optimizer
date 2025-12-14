#!/bin/bash
. ./utility.sh
. ./image-rename-functions/ai-rename-api.sh
. ./image-rename-functions/shopify-handle-rename.sh

# Configuration
IMAGE_DIR="resized_images"
RENAMED_DIR="renamed_images"
LOG_DIR="logs"
LOG_FILE="$LOG_DIR/image_rename.log"
SHOPIFY_LOG_FILE="$LOG_DIR/shopify_handle_image_rename.log"
AI_LOG_FILE="$LOG_DIR/image_rename.log"

# Returned from AI when image cannot be described correctly.
NO_PRODUCT_STRING="NO_PRODUCT_FOUND_IN_IMAGE"

# Variables you will need to adjust for your program to run correctly.
GEMINI_PROMPT="Analyze the image and tell me the **exact full name of the perfume** in the image. If you cannot find the perfume in the image, respond with '$NO_PRODUCT_STRING'."
PRODUCT_IMAGE_APPEND="perfume-fragrance-online-and-in-miami"
PRODUCT_IMAGE_PREPEND="Shop-for-"

API_URL="https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent"

# Setting this to 1 will override the AI functionality and use the Shopify store handle to rename your images.
# Use this if you have an emergency and you cannot use AI for whatever reason.
USE_SHOPIFY_HANDLE_OVERRIDE=0

usage()
{
  echo "Usage: $(basename $0) -ush useShopifyHandles"
  exit
}

get_opts()
{
    while [[ $# -gt 0 ]]
    do
        key="$1"
        case $key in
            -ush|-useShopifyHandles)
              shift
              USE_SHOPIFY_HANDLE_OVERRIDE="$1"
              shift
              ;;
            *)
              usage
              ;;
        esac
    done
}

# Validate USE_SHOPIFY_HANDLE_OVERRIDE Input
get_opts $*

if [[ -z $USE_SHOPIFY_HANDLE_OVERRIDE ]]; then
  echo "useShopifyHandles must have a value."
  exit;
fi

if [[ $USE_SHOPIFY_HANDLE_OVERRIDE != 1 && $USE_SHOPIFY_HANDLE_OVERRIDE != 0 ]]; then
  echo "useShopifyHandles must be set to 1 or 0";
  exit;
fi

# Ensure necessary directories exist
if [ ! -d "$IMAGE_DIR" ]; then
    echo "Error: Directory '$IMAGE_DIR' not found!"
    exit 1
fi

# Log Directory
if [ ! -d "$LOG_DIR" ]; then
  mkdir -p "$LOG_DIR"
fi

# Create a backup folder of the resized images
if [ -d "$RENAMED_DIR" ]; then
  echo "${RENAMED_DIR} already exsists. Delete your ${RENAMED_DIR} to start again.";
  exit 0;
fi

# Create a backup folder of the resized images
cp -R "${IMAGE_DIR}/." "$RENAMED_DIR";

# Counter to track requests
counter=0

# Start logging
echo "Starting image processing - $(date)" >> $LOG_FILE

cd $RENAMED_DIR;

# Process each image
for productHandle in */; do

    # First CD into the product handle directory
    echo "The product handle direcotry name: ${productHandle}";
    cd "${productHandle}";

    # Then, CD into each sub-directory, in this case, each sub dir would be the image order
    for subDir in */; do

      # CD into image order sub-dir
      cd "${subDir}";

      for file in *; do
        # Ensure the file exists and is a valid image
        [ -f "$file" ] || continue

        echo "Processing: ${productHandle}/${subDir}/${file}" >> "../../../${LOG_FILE}"

        # Processing
        if [[ $USE_SHOPIFY_HANDLE_OVERRIDE == 1 ]]; then
          shopifyRename $file "${productHandle}" "${PRODUCT_IMAGE_APPEND}" "${PRODUCT_IMAGE_PREPEND}" "../../../${SHOPIFY_LOG_FILE}"
        elif [[ $USE_SHOPIFY_HANDLE_OVERRIDE == 0 ]]; then
          aiRename $file $API_URL $GEMINI_API_KEY "${GEMINI_PROMPT}" "${productHandle}" "${PRODUCT_IMAGE_APPEND}" "${PRODUCT_IMAGE_PREPEND}" "../../../${AI_LOG_FILE}" "${NO_PRODUCT_STRING}"

          # Increment the counter
          ((counter++))

          # Throttle every 5 requests (to avoid hitting the rate limit)
          if ((counter % 5 == 0)); then
            echo "Sleeping for 60 seconds to avoid API rate limit..."
            sleep 60
          fi
        fi
      done;

      # CD back into product handle dir
      cd ".."
    done

    # CD back into $RENAMED_DIR
    cd ".."
done

echo "Processing complete! Log file: $LOG_FILE"