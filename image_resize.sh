#!/bin/bash
IMAGE_DIR='downloaded_images';
MAX_WIDTH=1920;
MAX_HEIGHT=1920;
MAX_SIZE=300000;
LOG="logs/image_resize.log"

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
        # Get the size of the image in bytes
        file_size=$(stat -f %z "$file")

        # Only proceed if the file is over 500 KB
        if [ "$file_size" -gt $MAX_SIZE ]; then
          # Get the dimensions of the image (width and height)
          dimensions=$(identify -format "%w %h" "$file" 2>/dev/null)

          # Check if dimensions are retrieved successfully
          if [[ -n "$dimensions" ]]; then
            width=$(echo $dimensions | cut -d' ' -f1)
            height=$(echo $dimensions | cut -d' ' -f2)
            
            echo "Image width: ${width}"
            echo "Image height: ${height}"

            # Check if the image dimensions are smaller than 1920px in either width or height
            if [ "$width" -gt $MAX_WIDTH ] || [ "$height" -gt $MAX_HEIGHT ]; then
              # Resize the image to 50% of its original size using magick
              echo "Resizing $file..."
              # TODO: Find a better way to resize the images so that their dimensions remain the highest possible without
              # going over 1920 pixels
              magick "$file" -resize 50% "$file"

              # I got this from https://www.smashingmagazine.com/2015/06/efficient-image-resizing-with-imagemagick/
              # I removed the thumbnail option since we already used magick to resize the image.
              mogrify -path "${file}" \
                      -filter Triangle \
                      -define filter:support=2 \
                      -unsharp 0.25x0.25+8+0.065 \
                      -dither None \
                      -posterize 136 \
                      -quality 82 \
                      -define jpeg:fancy-upsampling=off \
                      -define png:compression-filter=5 \
                      -define png:compression-level=9 \
                      -define png:compression-strategy=1 \
                      -define png:exclude-chunk=all \
                      -interlace none \
                      -colorspace sRGB

              echo "$file was resized and compressed successfully.";

            else
              echo "$file is not resized because its dimensions are above 1920px."
            fi
          else
            echo "Error: Could not retrieve dimensions for $file. Skipping..."
          fi
        else
          echo "$file is smaller than 500 KB and will not be resized."
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