#!/bin/bash

# Define the input file and output folder
URL_FILE="image_urls.txt"
OUTPUT_DIR="downloaded_images"
declare -a imageSrcArray

# Check if the URL file exists
if [ ! -f "$URL_FILE" ]; then
    echo "Error: $URL_FILE not found!"
    exit 1
fi

# Create the output directory for the downloaded product images
if [ ! -d "$OUTPUT_DIR" ]; then
    mkdir -p "${OUTPUT_DIR}"
fi

cd "$OUTPUT_DIR";

while IFS= read -r line; do
    imageSrcArray+=("$line")
done < "../$URL_FILE"

counter=0
for i in "${!imageSrcArray[@]}"; do

    declare -a lineArray;

    # Let's split the array and save it to a local array
    IFS=',' read -ra lineArray <<< "${imageSrcArray[i]}"

    productHandle="${lineArray[1]}"
    productImageURL="${lineArray[2]}"
    productImagePlacement="${lineArray[4]}"

    # We might get one of these products that just have no images, so let's skip over them.
    # I'm not sure if this is still true after switching to the GraphQL API
    if [[ -z "${productImageURL}" ]]; then
        continue;
    fi

    # First we create a folder for the handle
    if [ ! -d "$productHandle" ]; then
        mkdir -p "${productHandle}";
    fi
    
    # CD into the product handle folder where we will create the image order directories.
    cd "${productHandle}";

    # then, we'll create a folder for the image order inside that product handle
    if [ ! -d "$productImagePlacement" ]; then
        mkdir -p "${productImagePlacement}";
    fi

    # cd into the folder where we will save the image (sharded by product image order)
    cd "${productImagePlacement}";

    # If the file already exists, let's skip the download
    if [ $(ls -1 | wc -l) -gt 0 ]; then
        # Backout to output dir
        echo "Skipping...Image already downloaded.";
        cd "../..";
        continue;
    fi

    # finally, we'll save the image in that product-handle/order folder.
    # Download the image using wget
    echo "${counter} - Starting download for: - ${productHandle} to save @ ${OUTPUT_DIR}/${productHandle}/${productImagePlacement}";
    wget "${productImageURL}";

    # Remove the Cache Version for the file name.
    for file in ./*; do
        mv $file $(echo "$file" | sed 's/\?v=[0-9]*//');
        echo "Cleaned Cache Version.";
    done

    # Increment the counter
    ((counter++))

    # Backout to output dir
    cd "../..";
done

echo "Download complete! Images are saved in '$OUTPUT_DIR'"