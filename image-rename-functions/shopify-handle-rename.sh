#!/bin/bash

shopifyRename() {
    local file=$(echo "$1")
    local handle=$(echo "$2")
    local product_image_append=$(echo "$3")
    local product_image_prepend=$(echo "$4")
    local SHOPIFY_LOG_FILE=$(echo "$5")

    EXT="${file##*.}"  # Get file extension

    # Let's rename the file to the product handle in case that we did not find the correct product name.
    SAFE_NAME=$(echo "$handle" | tr ' /' '-' | tr ' ' '-' | tr -d '"' | tr -cd '[:alnum:]_-') # Sanitize filename
    NEW_NAME="${PRODUCT_IMAGE_PREPEND}${SAFE_NAME}${PRODUCT_IMAGE_APPEND}.$EXT"

    mv "$file" "$NEW_NAME"
    echo "Renamed to product handle: $file -> $NEW_NAME" >> $SHOPIFY_LOG_FILE
}