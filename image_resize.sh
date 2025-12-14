#!/bin/bash
IMAGE_DIR='downloaded_images';
NEW_FOLDER='resized_images';

LOG="logs/image_resize.log"

# You can set what the largest WIDTH or HEIGHT should be set at
# an image that is 1200x900 will get resized to 820x520
# an image that is 900x1200 will get resized to 520x820
# an image that is 1200x1200 will get resized to 820x820
MAX_WIDTH=900;
MAX_HEIGHT=900;

# 50 KB, Images over 50KB will be resized
MAX_SIZE=50000; 

# WEBP Quality parameter allows you to set your image's quality when converting to WEBP.
# I reccomend 75 so that your images are not terribly pixelated with 820px being the largest dimension for your image.
WEBP_QUALITY=77

# Let's Log the total size of all the images if the IMAGE_DIR
totalDirectorySize="$(du -sh $IMAGE_DIR)"
echo "Directory Size Before Compression: $totalDirectorySize" >> "${LOG}";

# Backup the downloaded_images folder before beginning resize
if [ -d "${NEW_FOLDER}" ]; then
  echo "Delete your backup directory ${NEW_FOLDER} and try again.";
  exit 0;
fi
# backup
cp -R "${IMAGE_DIR}/." "${NEW_FOLDER}"

# CD into the NEW_FOLDER
cd "${NEW_FOLDER}";

for productHandle in ./*; do
  # Let's go into the product handle folder.
  cd "${productHandle}";

  for imageOrder in ./*; do

    # CD into the imageOrder subDirectory
    cd "${imageOrder}";

    for file in *; do
      # Check if it's an image (including webp)
      if [[ "$file" =~ \.(jpg|jpeg|png|gif|bmp|tiff|webp)$ ]]; then

        # Get the dimensions of the image (width and height)
        dimensions=$(identify -format "%w %h" "$file" 2>/dev/null)
        file_name="${file%.*}"

        # Check if dimensions are retrieved successfully
        if [[ -n "$dimensions" ]]; then
          width=$(echo $dimensions | cut -d' ' -f1)
          height=$(echo $dimensions | cut -d' ' -f2)

          # Check if the image dimensions are smaller than max_width || max_height in either width or height
          if [ "$width" -gt $MAX_WIDTH ] || [ "$height" -gt $MAX_HEIGHT ]; then
            # Resize the image to 50% of its original size using magick
            echo "Resizing $file..."

            if [ "$width" -gt "$height" ]; then
              magick "$file" -resize "${MAX_WIDTH}"x "$file"
            fi;

            if [ "$height" -gt "$width" ]; then
              magick "$file" -resize x"${MAX_HEIGHT}" "$file"
            fi;

            if [ "$width" -eq "$height" ]; then
              magick "$file" -resize "${MAX_WIDTH}"x"${MAX_HEIGHT}" "$file"
            fi;

            echo "$file was resized successfully."

          else
            echo "$file is not resized because its dimensions are below ${MAX_WIDTH}w X ${MAX_HEIGHT}h"
          fi
        else
          echo "Error: Could not retrieve dimensions for $file. Skipping..."
        fi

        # Convert to webp if it isn't already in WEBP format.
        if ! [[ "$file" =~ \.(webp)$ ]]; then
          magick "${file}" -quality 100 -define webp:lossless=false "${file_name}.webp"

          # let's trash the original image
          rm -rf "$file"
        fi

        webpFile="${file_name}.webp"

        # Get the size of the new image in bytes
        file_size=$(stat -f %z "$webpFile")

        # Only proceed if the file is over MAX_SIZE.
        if [ "$file_size" -gt $MAX_SIZE ]; then
          # compress the image
          magick "${webpFile}" -quality "${WEBP_QUALITY}" -define webp:lossless=false "${file_name}.webp"
        else
          echo "$file is smaller than ${MAX_SIZE} bytes and will not be compressed."
        fi
      else
        echo "$file is not an image file."
      fi
    done
  
    # CD back into the project-handle
    cd ..
  done

  # CD back into the images dir from the product handle
  cd ..
done

#CD Back into the root project
cd .. 

# Let's log the total size of all the images after we compress & resize them
totalDirectorySize="$(du -sh $NEW_FOLDER)"
echo "Directory Size After Compression: $totalDirectorySize" >> "${LOG}";