#!/bin/bash
IMAGE_DIR='downloaded_images';

# You can set what the largest WIDTH or HEIGHT should be set at
# an image that is 1200x900 will get resized to 820x
MAX_WIDTH=820;
MAX_HEIGHT=820;

# 50 KB
MAX_SIZE=50000; 
LOG="logs/image_resize.log"

# WEBP Quality parameter allows you to set your image's quality when converting to WEBP.
# I reccomend 70 so that your images are not terribly pixelated with 820px being the largest dimension for your image.
WEBP_QUALITY=70

# Let's Log the total size of all the images if the IMAGE_DIR
totalDirectorySize="$(du -sh $IMAGE_DIR)"
echo "Directory Size Before Compression: $totalDirectorySize" >> "${LOG}";

# CD into the IMAGE_DIR
cd "${IMAGE_DIR}";

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

            echo "$file was resized and compressed successfully."

          else
            echo "$file is not resized because its dimensions are below ${MAX_WIDTH}w X ${MAX_HEIGHT}h"
          fi
        else
          echo "Error: Could not retrieve dimensions for $file. Skipping..."
        fi

        # Get the size of the image in bytes
        file_size=$(stat -f %z "$file")

        # Only proceed if the file is over MAX_SIZE or if the image isn't already a webp.
        if [ "$file_size" -gt $MAX_SIZE ] || [[ "$file" =~ \.(jpg|jpeg|png|gif|bmp|tiff)$ ]]; then

          # compress the image
          magick "${file}" -quality "${WEBP_QUALITY}" -define webp:lossless=false "${file_name}.webp"

          #let's trash the original image
          rm -rf "$file"
        else
          echo "$file is smaller than ${MAX_SIZE}KB and will not be resized."
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
totalDirectorySize="$(du -sh $IMAGE_DIR)"
echo "Directory Size After Compression: $totalDirectorySize" >> "${LOG}";