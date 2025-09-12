#!/bin/bash
. ./utility.sh

# where are we saving the downloaded product data
OUTPUT_FILE="image_urls.txt"

# Log file
COMPLETION_LOG_FILE="logs/extract-images.log"

if [ ! -d "logs" ]; then
    mkdir "logs"
fi

if [ ! -f "${COMPLETION_LOG_FILE}" ]; then
    touch "${COMPLETION_LOG_FILE}"
fi

# Ensure OUTPUT_FILE does not exist
if [ -f "$OUTPUT_FILE" ]; then
    echo "Error: File '$OUTPUT_FILE' already exists!" >> "$COMPLETION_LOG_FILE"
    exit 1
fi

#Let's get the total products
echo "Total Products Request..." >> "$COMPLETION_LOG_FILE"
totalProductResponse=$(curl -X POST \
  https://${SHOPIFY_STORE}.myshopify.com/admin/api/2025-07/graphql.json \
  -H 'Content-Type: application/json' \
  -H "X-Shopify-Access-Token: ${ADMIN_API_TOKEN}" \
  -d '{ "query": "query { productsCount(query: \"id:>=0\") { count } }" }'
)
TOTAL_PRODUCTS=$(echo $totalProductResponse | jq -r '.data.productsCount.count');
echo "Total Products: $TOTAL_PRODUCTS" >> "$COMPLETION_LOG_FILE"
echo "-------------------------------" >> "$COMPLETION_LOG_FILE"
echo "-------------------------------" >> "$COMPLETION_LOG_FILE"

# Let's get the first product. We can use its cursor as a starting point.
# create the GraphQL query for first product.
QUERY_DECODED=$(generateQuery 'first:1')

echo "First Product Request..." >> "$COMPLETION_LOG_FILE"
firstProductQueryResponse=$(curl -X POST \
  https://${SHOPIFY_STORE}.myshopify.com/admin/api/2025-07/graphql.json \
  -H 'Content-Type: application/json' \
  -H "X-Shopify-Access-Token: ${ADMIN_API_TOKEN}" \
  -d "{ \"query\": \"${QUERY_DECODED}\" }"
)
echo "-------------------------------" >> "$COMPLETION_LOG_FILE"
echo "-------------------------------" >> "$COMPLETION_LOG_FILE"

FIRST_PRODUCT=$(echo $firstProductQueryResponse | jq -r '.data.products.nodes[0] | @base64');

$(writeProductToCsv $FIRST_PRODUCT $OUTPUT_FILE);

LAST_CURSOR=$(echo $firstProductQueryResponse | jq -r '.data.products.edges[0].cursor');

echo "First Product Cursor... ${LAST_CURSOR}" >> "$COMPLETION_LOG_FILE"

# How many products are we fetching per batch? Beware Shopify limits this to 250 per GraphQL query for non-bulk queries.
PRODUCTS_PER_BATCH=250

# Now let's generate a list of products for the first 250 products. We will user the last cursor so we know where to start from.
productResponse=$(echo $(next_product_list "${LAST_CURSOR}" $PRODUCTS_PER_BATCH));

# Let's save the products and last cursor
PRODUCT_LIST=$(echo $productResponse | jq -r '.productList')
LAST_CURSOR=$(echo $productResponse | jq -r '.lastCursor')

# Order in which columnss will be written to the CSV (product ID, Handle, Image Src, Image Position)
CURRENT_BATCH_PRODUCT=0
CURRENT_PRODUCT=1

startBatch() {
    productList=$(echo $1);

    # Loop through the products and save their data
    for product in $(echo "$productList" | jq -r '.[] | @base64'); do
        echo "Writing data for batch product $CURRENT_BATCH_PRODUCT / $PRODUCTS_IN_BATCH - Total Products: $CURRENT_PRODUCT / $TOTAL_PRODUCTS" >> "$COMPLETION_LOG_FILE";

        $(writeProductToCsv $product $OUTPUT_FILE)

        let CURRENT_PRODUCT++
        let CURRENT_BATCH_PRODUCT++

        if [[ $CURRENT_BATCH_PRODUCT -eq $PRODUCTS_PER_BATCH ]]; then
            # Now let's generate a list of products for the first 250 products. We will user the last cursor so we know where to start from.
            productResponse=$(echo $(next_product_list "${LAST_CURSOR}" $PRODUCTS_PER_BATCH));

            # Let's save the products and last cursor
            productList=$(echo $productResponse | jq -r '.productList')
            LAST_CURSOR=$(echo $productResponse | jq -r '.lastCursor')

            # Let's start the loop again to get the next product list
            let CURRENT_BATCH_PRODUCT=0
            
            echo "Batch Completed...."  >> "$COMPLETION_LOG_FILE";
            echo "-------------------------------" >> "$COMPLETION_LOG_FILE";
            echo "-------------------------------" >> "$COMPLETION_LOG_FILE";

            if [[ $CURRENT_PRODUCT -eq $TOTAL_PRODUCTS ]]; then
                echo "Product Image URLs were extracted to $OUTPUT_FILE." >> "$COMPLETION_LOG_FILE";
                break;
            fi

            #start the loop again
            echo "Next Product List Query......" >> "$COMPLETION_LOG_FILE";
            echo "Starting Cursor: $LAST_CURSOR" >> "$COMPLETION_LOG_FILE";
            $(startBatch "${productList}")
            echo "-------------------------------" >> "$COMPLETION_LOG_FILE";
            echo "-------------------------------" >> "$COMPLETION_LOG_FILE";
        fi
    done
}

echo "Next Product List Query......" >> "$COMPLETION_LOG_FILE";
echo "Starting Cursor: $LAST_CURSOR" >> "$COMPLETION_LOG_FILE";
$(startBatch "${PRODUCT_LIST}")
echo "-------------------------------" >> "$COMPLETION_LOG_FILE";
echo "-------------------------------" >> "$COMPLETION_LOG_FILE";