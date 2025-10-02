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
    echo "Error: File '$OUTPUT_FILE' already exists";
    exit 1
fi

# Declare from which product ID you want to start. Products with IDs greater than the FROM_ID
# are the only ones which will be processed.
FROM_ID=10039381622968

#Let's get the total products
echo "Total Products Request..." >> "$COMPLETION_LOG_FILE"
totalProductResponse=$(curl -X POST \
  https://${SHOPIFY_STORE}.myshopify.com/admin/api/2025-07/graphql.json \
  -H 'Content-Type: application/json' \
  -H "X-Shopify-Access-Token: ${ADMIN_API_TOKEN}" \
  -d '{ "query": "query { productsCount(query: \"id:>='$FROM_ID'\") { count } }" }'
)

TOTAL_PRODUCTS=$(echo $totalProductResponse | jq -r '.data.productsCount.count');

echo "Total Products: $TOTAL_PRODUCTS - Starting from Product ID: $FROM_ID" >> "$COMPLETION_LOG_FILE"
echo "-------------------------------" >> "$COMPLETION_LOG_FILE"
echo "-------------------------------" >> "$COMPLETION_LOG_FILE"

# Let's get the first product. We can use its cursor as a starting point.
# create the GraphQL query for first product depending of the FROM_ID value.
if [[ $FROM_ID -gt 0 ]]; then
    SELECTOR="first:1,query:\"id:>=${FROM_ID}\""
else
    SELECTOR='first:1'
fi;

QUERY_DECODED=$(generateQuery $SELECTOR)
QUERY_DECODED=$(echo "${QUERY_DECODED//\"/\\\"}")

echo "First Product Request..." >> "$COMPLETION_LOG_FILE"
firstProductQueryResponse=$(curl -X POST \
  https://${SHOPIFY_STORE}.myshopify.com/admin/api/2025-07/graphql.json \
  -H 'Content-Type: application/json' \
  -H "X-Shopify-Access-Token: ${ADMIN_API_TOKEN}" \
  -d "{ \"query\": \"${QUERY_DECODED}\" }"
)
echo "-------------------------------" >> "$COMPLETION_LOG_FILE"
echo "-------------------------------" >> "$COMPLETION_LOG_FILE"

# Let's track the current product in the batch and the current product overall.
CURRENT_BATCH_PRODUCT=1
CURRENT_PRODUCT=1

# The first product we'll need to retrieve manually to get a product cursor to start from.
FIRST_PRODUCT=$(echo $firstProductQueryResponse | jq -r '.data.products.nodes[0] | @base64');

LAST_CURSOR=$(echo $firstProductQueryResponse | jq -r '.data.products.edges[0].cursor');
echo "First Product Cursor... ${LAST_CURSOR}" >> "$COMPLETION_LOG_FILE"

echo "--------------------------------" >> "$COMPLETION_LOG_FILE"
echo "-- Writing Product Image Data --" >> "$COMPLETION_LOG_FILE"
echo "--------------------------------" >> "$COMPLETION_LOG_FILE"

echo "Writing data for batch product $CURRENT_BATCH_PRODUCT / $PRODUCTS_PER_BATCH - Total Products: $CURRENT_PRODUCT / $TOTAL_PRODUCTS" >> "$COMPLETION_LOG_FILE";

$(writeProductToCsv $FIRST_PRODUCT $OUTPUT_FILE $COMPLETION_LOG_FILE);

let CURRENT_PRODUCT++
let CURRENT_BATCH_PRODUCT++

# How many products are we fetching per batch? Beware Shopify limits this to 250 per GraphQL query for non-bulk queries.
PRODUCTS_PER_BATCH=250

# Now let's generate a list of products for the first 250 products. We will user the last cursor so we know where to start from.
productResponse=$(echo $(next_product_list "${LAST_CURSOR}" $PRODUCTS_PER_BATCH));

# Let's save the products and last cursor
PRODUCT_LIST=$(echo $productResponse | jq -r '.productList')
LAST_CURSOR=$(echo $productResponse | jq -r '.lastCursor')

# If the TOTAL_PRODUCTS is less than the PRODUCTS_PER_BATCH then set the Products Per Batch to equal
# the total products. This will allow for the batch to finalize since there are 
if [[ $TOTAL_PRODUCTS -lt $PRODUCTS_PER_BATCH ]]; then
    let PRODUCTS_PER_BATCH=$TOTAL_PRODUCTS
fi

# Order in which columnss will be written to the CSV (product ID, Handle, Image Src, Image Position)
startBatch() {
    productList=$(echo $1);

    # Loop through the products and save their data
    for product in $(echo "$productList" | jq -r '.[] | @base64'); do
        echo "Writing data for batch product $CURRENT_BATCH_PRODUCT / $PRODUCTS_PER_BATCH - Total Products: $CURRENT_PRODUCT / $TOTAL_PRODUCTS" >> "$COMPLETION_LOG_FILE";

        $(writeProductToCsv $product $OUTPUT_FILE $COMPLETION_LOG_FILE)

        if [[ $CURRENT_BATCH_PRODUCT -eq $PRODUCTS_PER_BATCH ]]; then
            # Now let's generate a list of products for the first 250 products. We will user the last cursor so we know where to start from.
            productResponse=$(echo $(next_product_list "${LAST_CURSOR}" $PRODUCTS_PER_BATCH));

            # Let's save the products and last cursor
            productList=$(echo $productResponse | jq -r '.productList')
            LAST_CURSOR=$(echo $productResponse | jq -r '.lastCursor')

            # Let's start the loop again to get the next product list
            let CURRENT_BATCH_PRODUCT=1
            
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

        let CURRENT_PRODUCT++
        let CURRENT_BATCH_PRODUCT++

    done
}

$(startBatch "${PRODUCT_LIST}")
echo "-------------------------------" >> "$COMPLETION_LOG_FILE";
echo "-------------------------------" >> "$COMPLETION_LOG_FILE";