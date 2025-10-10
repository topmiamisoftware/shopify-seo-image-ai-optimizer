# Shopify API credentials
SHOPIFY_STORE=""
ADMIN_API_TOKEN=""
GEMINI_API_KEY=""

# Product Image Query
generateQuery() {
    SELECTOR=$(echo "$1")

    QUERY=$(echo "query GetProducts { 
            products(${SELECTOR}) { 
                edges {
                    cursor
                }
                nodes { 
                    id 
                    title 
                    handle
                    onlineStoreUrl
                    media(first: 100) { 
                        edges {
                            node {
                                ... on MediaImage {
                                    image {
                                        url
                                    }
                                }
                            }
                        }
                    } 
                }
            }     
        }" | base64)

    QUERY_DECODED=$(echo $QUERY | base64 -d | tr -d '\n')

    echo $QUERY_DECODED;
}

_jq() {
    echo "$1" | base64 --decode | jq -r "$2"
}

next_product_list() {
    selector=$(echo "$1");
    productCount=$(echo "$2");

    QUERY_DECODED=$(generateQuery 'first: '$productCount', after: \"'$selector'\"')

    # create the GraphQL query
    response=$(curl -X POST \
        https://${SHOPIFY_STORE}.myshopify.com/admin/api/2025-07/graphql.json \
        -H 'Content-Type: application/json' \
        -H "X-Shopify-Access-Token: ${ADMIN_API_TOKEN}" \
        -d "{ \"query\": \"${QUERY_DECODED}\" }"
    )

    data=$(echo "$response" | jq -r '.data');
    productResponse=$(echo "$data" | jq -r '.products');

    # Let's save the product nodes & the product cursor list
    productList=$(echo $productResponse | jq -r '.nodes');
    productCursorList=$(echo $productResponse | jq -r '.edges[].cursor');

    # Save the last line of the cursor array into a variable.
    lastCursor=$(echo $(echo "${productCursorList}"| tail -1))

    echo "{ \"productList\": ${productList}, \"lastCursor\": \"${lastCursor}\" }";
}

writeProductToCsv() {
    product=$(echo "$1")
    outputFile=$(echo "$2")
    logFile=$(echo "$3")

    product_id=$(_jq $product '.id');
    product_handle=$(_jq $product '.handle')
    product_title=$(_jq $product '.title')
    online_store_url=$(_jq $product '.onlineStoreUrl')
    product_media_list=$(_jq $product '.media.edges[]')

    # Use for image placement.
    order=0
    for product_image in $(echo "$product_media_list" | jq -r '.node.image.url'); do
        line="$product_id,$product_handle,$product_image,$order"
        printf "$line\n" >> $outputFile;
        let order++
    done   

     printf "Total Images for product ${order} \n" >> $logFile;
}