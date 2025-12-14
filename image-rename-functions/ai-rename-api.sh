#!/bin/bash
aiRename() {
    local file=$(echo "$1")
    local API_URL=$(echo "$2")
    local GEMINI_API_KEY=$(echo "$3")
    local GEMINI_PROMPT=$(echo "$4")
    local productHandle=$(echo "$5")
    local PRODUCT_IMAGE_APPEND=$(echo "$6")
    local PRODUCT_IMAGE_PREPEND=$(echo "$7")
    local LOG_FILE=$(echo "$8")
    local NO_PRODUCT_STRING=$(echo "$9")

    # Convert image to base64
    BASE64_IMAGE=$(base64 -i "$file")
    echo "Log this image: $file" >> "${LOG_FILE}"

    # Send request using multipart form-data
    RESPONSE=$(curl -s -X POST "$API_URL" \
        -H "x-goog-api-key: $GEMINI_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "contents": [
            {
                "parts": [
                {
                    "text": "'"$GEMINI_PROMPT"'"
                },
                {
                    "inlineData": {
                    "mimeType": "image/webp",
                    "data": "'"$BASE64_IMAGE"'"
                    }
                }
                ]
            }
            ],
            "generationConfig": {
            "temperature": 0.0,
            "topP": 0.1,
            "maxOutputTokens": 300
            }
        }')

    # Log the raw API response
    echo "Response for $file: $RESPONSE" >> "${LOG_FILE}" 

    # Extract the response text and handle potential errors
    PRODUCT_NAME=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text' 2>/dev/null)

    # We are dealing with 2 cases here.
    # 1. If the product name is equal to the "no product found string".
    # 2. If the product_name is NULL type -z or "null" string representation when returned from the API.
    if [[ "$PRODUCT_NAME" == "$NO_PRODUCT_STRING" || -z "$PRODUCT_NAME" || "$PRODUCT_NAME" == "null" ]]; then
        # Let's rename the file to the product handle in case that we did not find the correct product name.
        SAFE_NAME=$(echo "$productHandle" | tr ' /' '-' | tr ' ' '-' | tr -d '"' | tr -cd '[:alnum:]_-') # Sanitize filename
        NEW_NAME="${PRODUCT_IMAGE_PREPEND}${SAFE_NAME}${PRODUCT_IMAGE_APPEND}.$EXT"
        echo "No product detected in: $file" | tee -a "${LOG_FILE}" 

        mv "$file" "$NEW_NAME"
        echo "Renamed to product handle: $file -> $NEW_NAME" | tee -a "${LOG_FILE}"
    fi

    # Log the null response from the API.
    if [[ -z "$PRODUCT_NAME" || "$PRODUCT_NAME" == "null" ]]; then
        echo "Error: No valid response from API for $file" | tee -a "${LOG_FILE}";

        # Increment the counter
        ((counter++))

        # Throttle every 5 requests (to avoid hitting the rate limit)
        if ((counter % 5 == 0)); then
            echo "Sleeping for 60 seconds to avoid API rate limit..."
            sleep 60
        fi

        continue;
    fi

    EXT="${file##*.}"  # Get file extension

    # Rename the file if a product name is detected
    if [[ "$PRODUCT_NAME" != "$NO_PRODUCT_STRING" ]]; then
        SAFE_NAME=$(echo "$PRODUCT_NAME" | tr ' /' '-' | tr ' ' '-' |  tr -d '"' | tr -cd '[:alnum:]_-') # Sanitize filename
        NEW_NAME="${PRODUCT_IMAGE_PREPEND}${SAFE_NAME}${PRODUCT_IMAGE_APPEND}.$EXT"

        # Rename the file if it's different
        if [ "$file" != "$NEW_NAME" ]; then
            mv "$file" "$NEW_NAME"
            echo "Renamed: $file -> $NEW_NAME" | tee -a "${LOG_FILE}" 
        fi
    fi
}