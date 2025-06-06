#!/bin/bash

OUTPUT_FILE="image_urls.txt"

# Check if a CSV file is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <shopify_product_list.csv>"
    exit 1
fi

CSV_FILE="$1"

# Ensure OUTPUT_FILE does not exist
if [ -f "$OUTPUT_FILE" ]; then
    echo "Error: File '$OUTPUT_FILE' already exists!"
    exit 1
fi

# In a CSV File, 1,29, 30 are the column numbers for the Handle, Image Src, Image Position columns,
csvcut -c 1,28,29 "$CSV_FILE" >> "$OUTPUT_FILE"

echo "Image URLs extracted to $OUTPUT_FILE"
