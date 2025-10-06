<h1>Shopify Technical SEO AI Image Optimizer (Compressor, Resizer, AI Renamer, and Alt Text Generator)</h1>

<p>
    Welcome to Shopify Image Technical SEO AI Image Optimizer tool.
</p>

<p>
    This Optimizer will:
</p>
<ul>
    <li>Query products from your Shopify Store saving the IDS, handles, image URLs (for the product, not its variants), and placement of the image. Save into a CSV.</li>
    <li>Download all your images from said URLs and shard them using the unique product handles that your shopify store uses.</li>
    <li>Resize, compress, and save said images to webp format.</li>
    <li>Make calls to Google Gemini to figure out what's in each image, with a custom prompt, and rename your image according to what's in them, adhering to technical SEO strandards.</li>
    <li>Re-upload the images by replacing the previous ones with the correct product image placement from Shopify. While uploading, it will also use the file name to generate the Alt Text for the product image. Looking to use Gemini in this step as well in order to generate the ALT text.</li>
</ul>

<p>
    DISCLAIMER: This source code is to be used AS IS. While I have personally ran this in 2 different production Shopify Stores and replaced over 500 images, I'm still not sure what could go wrong while running the image replacement script.
</p>

<p>
    My suggestion is to first run the image replacement script for 10 prodcuts at the time, checking if anything has gone wrong with your products, and then letting it run for a greater amount of products at the time. For example, I did batches of 20 at first, and once I saw it was replacing images correctly, I let it run until it finished all the 500+ images.
</p>

<h2>
    How to use the Shopify Technical SEO Image Optimizer Tool
</h2>

<h3>1. Download the Product Image Data from Shopify GraphQL</h3>
<ol>
    <li>The first thing we'll do is <b>download the products in your Shopify Store into a CSV file.</b></li>
    <p>
        <ol>
            <li>Grab your shop URL and API Key from your Shopify App.</li>
            <li>Replace the SHOPIFY_STORE and ADMIN_API_TOKEN values in the `utility.sh` file.</li>
            <li>Now you can run `extract_images_urls.sh` script.</li>
            <li>This will download all the required product information into a CSV file named 'image_urls.txt'.</li>
        </ol>
    </p>
    <p>
        <strong>NOTE</strong>: If you want to optimize products starting from a specific product ID instead of all of your products, then simply change the FROM_ID variable to the product ID you want to start from. This will download products starting FROM that ID to the latest one you created. Currently, the script does not handle dates, instead it uses IDs to specify which products will get processed. In other words, updated products will not get processed if their ID is less tha the specified FROM_ID.
    </p>
    <p>
        You can watch <a href="https://www.youtube.com/watch?v=YZ9oVx2GzwU" target="_blank">this VIDEO if you're wondering how to change the FROM_ID and how the product image saving process works overall.</a> 
    </p>
</ol>

<h3>2. Download Product Images from the Shopify CDN</h3>
<ol>
    <li>
        Now we can download the Images from the <b>image_urls.txt</b> file into a local folder from the Shopify CDN.
    </li>
    <p>
        <ul>
            <li>To achieve this, we'll use the <b>download_product_images.sh</b> shell script.</li>
            <li>It will create the downloaded_images folder, and download the images from the Shopify CDN using the wget tool.</li>
            <li>Once downloaded, it will store each image into its respective folder dictated by the ${ProductHandle}/${ImagePlacement}/${FileName} directory scheme.</li>
            <li>Note that Product Handles cannot be duplicated. Therefore, we use Product Handles to shard the downloaded_images folders appropiately. We will also use the product handles when replacing the images.</li>
            <ol>
                <li>
                    To download the images, run the `./download_product_images.sh` command from your CLI and you will see the "Download complete! Images are saved in downloaded_images" if the images are downloaded correctly. This will take a while. You should see output on your console as images are being downloaded.
                </li>
            </ol>
        </ul>
    </p>
</ol>
<p>
    You can watch <a href="https://www.youtube.com/watch?v=KASFE9usE4k" target="_blank">this VIDEO if you're wondering how the product image download process works.</a> 
</p>

<h3>3. Compress and Resize the Shopify Product Images</h3>
<ol>
    <li>
        Before we upload the images through the Gemini API to get the file names, let's compress them and resize them. This will not only optimize the images for the best web performance, it will also reduce the payload on the Gemini API calls.<br/>
        <b>!!!WARNING!!!:</b> You should manually backup the `downloaded_images` folder at this point to create a backup of your Shopify Store Images.
    </li>
    <ul>
        Once you created your backup from the downloaded_images folder, you can take a look at the current hard-coded settings for image resizing and compression. Opening the <b>image_resize.sh</b> script will allow you to customize the MAX_WIDTH, MAX_HEIGHT, and MAX_SIZE variable thresholds.
    </ul>
    <ul>
        Once you are satisfied with the thresholds, run the <b>image_resize.sh</b> script.
    </ul>
    <ul>
        This will run the `magick` command on each image and reduce their size if they meet the threshold.
    </ul>
    <ul>
        It will also run `magick` command on each image to compress and convert the images to webp format.
    </ul>
</ol>

<h3>4. Replace the Optimized Images</h3>
<ol>
    <li>
        Now it's time to rename the downloaded images using the `rename_images.sh` script. This will rename your image files so that they're named according to what's in the image itself.
    </li>
    <ul>
        <li>
            To do this, we'll use the Gemini API, prompt it to analyze the image and
            rename the file according to the prompt plus some pre-defined text that we'll hardcode in order to match your Shopify's store's targeted SEO keywords.
        </li>
        <li>
            If you open the script file, you will notice it doing a couple of things;
            It will find the "downloaded_images" directory, then it will make CURL requests to the Gemini API with a prompt and the image itself encoded in BASE64.
        </li>
        <li>
            The Gemini API will then reply with a JSON object from which we will want the `candidates[0].content.parts[0].text` portion of.
        </li>
        <li>What you'll need to make this happen is the following:</li>
        <ol>
            <li>
                Gemini Config:
            </li>
            <ul>
                <li>
                    API KEY from Google Gemini. Get that from <a href=''>Google Gemini's official API dashboard.</a>.
                </li>
                <li>
                    Prompt for the Gemini API; since in the demo here I was dealing with perfumes, my prompt was: "Analyze the image and tell me the **exact full name of the perfume** in the image. If there is no perfume, respond with '$NO_PRODUCT_STRING'."
                </li>
            </ul>
            <li>
                The PRODUCT_IMAGE_APPEND variable to fit your use case. This variable will store what each image file name will get appended with. For example, my product images were for a Perfume shop who sells online and in the miami area. So my append text was "perfumes-online-and-in-miami". The script will then name images as so: "Shop-for-Yves-Saint-Laurent-MYSLF-Eau-de-Parfum-perfume-in-miami-and-online.webp". Notice that for the time being the "Shop-for-" portion of the file name is hardcoded. You can change that.
            </li>
            <li>
                Change the GEMINI_PROMPT variable to fit your use case.
            </li>
            <li>
                Finally, let's run the script by invoking `./rename_images.sh` from the command prompt. This will take a while. Notice the script sleeps every 15 requests to avoid hitting the APIs rate limit. If any errors occur, they will be logged in the logs folder which the script creates. Look in your "downloaded-images", and you will see your images being renamed accordingly as the script runs.
            </li>
            <li>
                If your script stops midway, make sure to remove your already renamed files from the downloaded_folder, or, you could also re-run the script starting from the beginning... However you'll be taking more tokens than needed. Maybe in the future we can make something better that moves the images to a new folder entirely.
            </li>
            <li>
                Another note is that if the product has no associted name and "NO_PRODUCT_STRING" is returned from the prompt, then the filename is derived from the product-handle.
            </li>
        </ol>
    </ul>
    <li>
        NOTE: This needs to be updated to use the GraphQL API. You will only be able to run this if you have a valid REST API key from an app which you created before the deprecation of the REST API. I'm working on getting this to use the GraphQL API.
        Finally... it's time to upload the images to the store and delete the current ones. I've added a backup method to the script which clones the current images in the downloaded_images to a backup folder. You should have manually backed this folder up before resizing or renaming any images.
    </li>
    <li>
        !!!WARNING!!!: If you haven't done so, make a backup of you downloaded_images folder at this point. If you need to re-downloaded all the original images again, then do so with the `download_product_images.sh` script. This next step is hihgly destructive and can have consequences on your Shopify Store.
    </li>
    <ul>
        <li>
            You will have update your correct API tokens from Shopify.
        </li>
        <li>
            and run the `./replace_remote_images.sh` script.
        </li>
        <li>
            this will replace your product images by using the product handles and image placements, then getting the product id and image ids, it will delete the images, then upload the new ones in their respective placements.
        </li>
        <li>
            You can set the stop point for the script earlier so that you can check that your images are being uploaded correctly. Then you can continue by re-running the script, it'll pick up where you left off.
        </li>
        <li>
            The backup folder is there with the renamed and compressed images.
        </li>
    </ul>
</ol>
