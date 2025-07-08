<h1>Shopify Technical SEO AI Image Optimizer (Compressor, Resizer, AI Renamer, and AI Alt Text)</h1>

<p>
    Welcome to this <b>basic</b> Shopify Image Technical SEO AI Image Optimizer tool.
    Notice that I've written <b>basic</b> in bold and this is because the optimizer is still quite rudementary. For example,
    you will notice some manual steps such as downloading the CSV file from your Shopify store. This is because I haven't found the time to work on that yet.
</p>

<p>
    DISCLAIMER: This source code is to be used AS IS. While I have personally ran this in 2 different production Shopify Stores and replaced over 500 images, I'm still not sure what could go wrong while running the image replacement script.
</p>
<p>
    My suggestion is to first run the image replacement script for 10 prodcuts at the time, checking if anything has gone wrong with your products, and then letting it run for a greater amount of products at the time. For example, I did batches of 20 at first, and once I saw it was replacing images correctly, I let it run until it finished all the 500+ images. I used it on these two websites: <a href="https://jeansmellgood.com" target="_blank">jeansmellgood.com</a> & <a href="https://bwmcosmetics.com" target="_blank">bwmcosmetics.com</a>
</p>

<h2>
    How to use the Shopify Technical SEO Image Optimizer Tool
</h2>

<ol>
    <li>The first thing we'll do is <b>export the CSV file for all your products in your Shopify Store.</b></li>
    <ol>
        <li>Navigate to your Shopify Store Admin Page</li>
        <li>Products > Export</li>
        <li>Choose All Products and Choose Export as Plain CSV File</li>
        <li>Click Export Products</li>
        <li>You will receive a copy of your export to your e-mail.</li>
    </ol>
    <li>Next, <b>we'll extract all the product handles, image URLS, and image placements from the products CSV file we just downloaded.</b></li>
    <ol>
        <li>To do this, we'll use the <b>extract_images_urls.sh script</b></li>
        <li>
            Drop the products' CSV you just downloaded into the project's root directory. 
        </li>
        <!-- <li>
            If you open your CSV file, you might notice lines that have multiple commas one after the other ",,,,," . This means
            that the product is still draft and some of the fields have not been filled out.
        </li> -->
        <li>
            Now, let's extract the Image URLs from the product list. If you open the <b>extract_images_urls.sh</b> file, you will notice that the output file is hardcoded to <b>image_urls.txt</b> file. This is where your product image URLs, Image Order, and Product IDs will be stored after we run this script.
        </li>
        <ol>
            <li>CD into the project root directory in your CLI. <br/><b>cd shopify_product_image_seo_optimizer</b></li>
            <li>Run the extract images shell script with <br/><b>./extract_images_urls.sh demo_files/products_export.csv</b></li>
            <li>Now you will see the "Image URLs extracted to image_urls.txt" output after running that command.</li>
            <li>You will also see the <b>image_urls.txt</b> file generated in the project's root directory.</li>
        </ol>
    </ol>
    <li>
        Now we'll procceed to download the Image URLs from the <b>image_urls.txt</b> file into a local folder from the shopify CDN.
    </li>
    <ul>
        <li>To achieve this, we'll use the <b>download_product_images.sh</b> shell script.</li>
        <li>It will create the downloaded_images folder, and download the images from the Shopify CDN using the wget tool.</li>
        <li>Once downloaded, it will store each image in its respective folder declared by ${ProductHandle}/${ImagePlacement}/${FileName}</li>
        <li>Note that Product Handles cannot be duplicated. Therefore, we just use the Product Handles to shard the downloaded_images folders appropiately.</li>
        <ol>
            <li>
                To download the images, run the `./download_product_images.sh` command from your CLI and you will see the "Download complete! Images are saved in downloaded_images" if the images are downloaded correctly.
            </li>
        </ol>
    </ul>
    <li>
        Before we upload the images through the Gemini API to get the file names, let's compress them and resize them. This will not only optimize the images for the best web performance, it will also reduce the payload on the Gemini API calls.<br/>
        <b>WARNING:</b> You should manually duplicate the `downloaded_images` folder at this point to create a backup.
    </li>
        <ul>
            Once you created your backup, you can take a loot at the current hard-coded settings for the Image resize and compression. Opening the <b>image_resize.sh</b> script will allow you to customize the MAX_WIDTH, MAX_HEIGHT, and MAX_SIZE variable thresholds.
        </ul>
        <ul>
            Once you are satisfied with the thresholds, run the <b>image_resize.sh</b> script.
        </ul>
        <ul>
            This will also run the command to `mogrify` the image and further reduce their size. The script uses the command found in this <a href="https://www.smashingmagazine.com/2015/06/efficient-image-resizing-with-imagemagick/">blog post.</a> If you want to learn more about image resizing and compression, I highly reccomend it.
        </ul>
    <li>
        Now it's time to rename the downloaded images using the `rename_images.sh` script. This will rename your images so that they're named according to what's in the image itself. This an SEO reccommended technique in order to relate image content to the file name, simplifiying the work that Search Engines have to do, and giving your page content meaning through media content.
    </li>
    <ul>
        <li>
            To do this, we'll use the Gemini API, prompt it to analyze the image and
            rename the file according to the prompt plus some pre-defined text that we'll hardcode in order to match your website's page's SEO keywords.
        </li>
        <li>
            If you open the script file, you will notice it doing a couple of things;
            It will find the "downloaded_images" directory that got created above when we downloaded the images, then it will make CURL requests to the Gemini API with a prompt and the image itself encoded in BASE64.
        </li>
        <li>
            The Gemini API will then reply with a JSON object from which we will want the `candidates[0].content.parts[0].text` portion of.
        </li>
        <li>What you'll need to make this happen is the following variables:</li>
        <ol>
            <li>
                API KEY from Google Gemini. Get that from <a href=''>Google Gemini's official API dashboard.</a>.
            </li>
            <li>
                Prompt for the Gemini API; since in the demo here I was dealing with perfumes, my prompt was: "Analyze the image and tell me the **exact full name of the perfume** in the image. If there is no perfume, respond with '$NO_PRODUCT_STRING'."
            </li>
            <li>
                The PRODUCT_IMAGE_APPEND variable to fit your use case. This variable will store what each image name will get appended with. For example, my product images were for a Perfume shop who sells online and in the miami area. So my prepend text was "perfumes-online-and-in-miami". The script will then name images as so: "Shop-for-Yves_Saint_Laurent_MYSLF_Eau_de_Parfum-perfume-in-miami-and-online.jpg"
            </li>
        </ol>
        <li>
            Open the rename_images.sh file and change the API_KEY to yours.
        </li>
        <li>
            Also change the GEMINI_PROMPT variable to fit your use case.
        </li>
        <li>
            Finally, let's run the script by invoking `./rename_images.sh` from the command prompt. This will take a while. Notice the script sleeps every 15 requests to avoid hitting the APIs rate limit. If any errors occur, they will be logged in the logs folder which the script creates. Look in your "downloaded-images", and you will see your images being renamed accordingly as the script runs.
        </li>
        <li>
            If your script stops midway, make sure to remove your already named files from the folder, or, you could also re-run the script, however you'll be taking more tokens than needed. Maybe in the future we can make something better that moves the images to a new folder entirely. I'm actually short on time right now so that won't be possible. 
        </li>
        <li>
            Another note is that if the product has no associted name and "NO_PRODUCT_STRING" is returned from the prompt, then the filename is derived from the product-handle.
        </li>
    </ul>
    <li>
        Finally... it's time to upload the images to the store and delete the current ones. I've added a backup method to the script which clones the current images in your store to a backup folder.
    </li>
    <ul>
        <li>
            All you will have to do is add your correct API tokens from Shopify.
        </li>
        <li>
            and finally, run the `./replace_remote_images.sh` script.
        </li>
        <li>
            this will replace your product images by using the product handles, then getting the product id and image ids, it will delete the images, then upload the new ones in the correct placements.
        </li>
        <li>
            You can set the stop point for the script so that you can check that your images are being uploaded correctly. Then you can continue by re-running the script, it'll pick up where you left off.
        </li>
        <li>
            The backup folder is there with the renamed and compressed images.
        </li>
    </ul>
</ol>

<p>
After all the products are downloaded, we proceed to extract the image URLs from the products CSV file, and then we save those
into their own CSV file.
</p>
