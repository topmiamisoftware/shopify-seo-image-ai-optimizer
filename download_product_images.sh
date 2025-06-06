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

# Let's skip the first line from the Image URLs file since it contains column names
# then loop through the image URLs and save them into our array
counter=0
for i in "${!imageSrcArray[@]}"; do
    
    declare -a lineArray;

    # Increment the counter
    ((counter++))

    if ((counter == 1)); then
      continue;
    fi

    # Let's split the array and save it to a local array
    IFS=',' read -ra lineArray <<< "${imageSrcArray[i]}"

    # We might get one of these products that just have no images, so let's skip over them.
    if [[ -z "${lineArray[1]}" ]]; then
        continue;
    fi

    # First we create a folder for the handle
    if [ ! -d "$lineArray[0]" ]; then
        mkdir -p "${lineArray[0]}";
    fi
    
    # CD into the product handle folder where we will create the image order directories.
    cd "${lineArray[0]}";

    # then, we'll create a folder for the image order inside that product handle
    if [ ! -d "$lineArray[2]" ]; then
        mkdir -p "${lineArray[2]}";
    fi

    # cd into the folder where we will save the image (sharded by product image order)
    cd "${lineArray[2]}";

    # If the file already exists, let's skip the download
    if [ $(ls -1 | wc -l) -gt 0 ]; then
        # Backout to output dir
        echo "Skipping...Image already downloaded.";
        cd "../..";
        continue;
    fi

    # finally, we'll save the image in that product-handle/order folder.
    # Download the image using wget
    echo "${counter} - Starting download for: - ${lineArray[1]} to save @ ${OUTPUT_DIR}/${lineArray[0]}/${lineArray[2]}";
    wget "${lineArray[1]}";

    # Remove the Cache Version for the file name.
    for file in ./*; do
        mv $file $(echo "$file" | sed 's/\?v=[0-9]*//');
        echo "Cleaned Cache Version.";
    done

    # Backout to output dir
    cd "../..";
done

echo "Download complete! Images are saved in '$OUTPUT_DIR'"