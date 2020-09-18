# Births by Parents' Country of Birth in London

The Office for National Statistics (ONS) publishes data on the number of live births by the parents' country of birth in England and Wales each year. Every time a birth is registered in England and Wales both parents are required to state their places of birth on their child's birth certificate, and this information is then collated to produce these statistics.

In order to make it easier to look at what these data tell us about births in London, and how these have been changing over time, the GLA Demography team has developed an automated system for extracting the data which relate to London from the main ONS dataset going back to 2001 and uploading it to a page on the London Datastore (including data for the individual London boroughs). A CSV file containing the raw data is also provided as part of the dataset so that it's available for other analysts to use. 

The original raw data can be seen on the ONS website here: https://www.ons.gov.uk/peoplepopulationandcommunity/birthsdeathsandmarriages/livebirths/bulletins/parentscountryofbirthenglandandwales/previousReleases

And the London Datastore page which presents these data is here:
https://data.london.gov.uk/dataset/births-by-parents-country-of-birth-in-london

## How to update the Births by Parents' Country of Birth in London page: a step-by-step guide
In order to keep this dataset up-to-date, it needs to be updated whenever the ONS updates the main Births by Parents' Country of Birth in England and Wales dataset. This normally happens once a year at some point in either late Summer or Autumn. Updating the dataset is very simple, and can be accomplished by following these steps:

1) Clone a local copy of this repository.

2) Open the file called "import_ons_data_script.R" from the "scripts" folder and check that you have all of the packages which are listed at the beginning of the script under point 1.1 installed. If you don't then un-comment that line using ctrl+c and install them. Then run the rest of the code in this script; it should create two new folders called "data" and "figures" in your project working directory. 

3) Inside the data folder you should find the individual datasets which have been scraped from the ONS website and a .csv file, the name of which begins "births_by_mothers_country_of_birth_2001_[latest year available].csv". If the code returns an error message, or it does run sucessfully but the latest year's data hasn't been appended to that file, then something has gone wrong. The most likely explanation is that the internal layout of the original data has been changed by the ONS since the previous year's release, in which you will need to modify the code to take account of these changes.

4) Once that .csv file has been properly updated, the next step is to update the file called "births_by_mothers_country_of_birth_markdown.Rmd". This requires the gglaplot package, which first needs to be installed from Github. The graphs and figures which are currently in that document should update themselves automatically, but it's important to re-read the accompanying text to ensure that figures which are generated from inline code have updated themselves, and also that any manually-written analyis in the text is updated.

5) Once the .Rmd file has been updated the remaining task is to upload it to the London Datastore. This is achieved by opening and running the file called "add_to_datastore_script.R". As before, you need to check that you've got the relevant packages installed; this includes the ldndatar package, which again needs to be installed from Github. It also requires you to have saved your London Datastore API key to your .Renviron file; a guide to doing this is provided below.

6) Check that the London Datastore page has sucessfully updated and has all of the correct resources attached to it.

## How do I save my London Datastore API key to my .Renviron file in R?
When you share code which interacts with the London Datastore API between multiple users or host it on Github, it's important not to expose your personal API Key. It's easy to prevent this by saving your API key as an environment variable in your .Renviron file, so it's then available for you to load into all of your other R scripts as an object. All you have to do is complete the following steps (N.B. if you are working across multiple computers then you may need to do this once for each installation of R):

1) Find your personal API key on the London Datastore by clicking on My Profile>Edit Profile>Get API Key and copy it to your clipboard.

2) Type the follwing command directly into the console of an active RStudio session: *usethis::edit_r_environ()*.

3) This should open your .Renviron file within RStudio. Type *lds_api_key=* on a new line and then paste your API Key after the equals sign as a text string.

4) Save your .Renviron file and close it, then click on Session>Restart R in the Rstudio header menu (you need to restart your RStudio session in order for the changes you've made to take effect).

5) Now, whenever you need to use your API key in a script, you can include the following line of code to assign it to a variable called my_api_key in the global environment of the current session: *my_api_key<-Sys.getenv("lds_api_key")*. This should keep your API Key secure, becasue R will always know what it is without it actually appearing directly within the script itself.
