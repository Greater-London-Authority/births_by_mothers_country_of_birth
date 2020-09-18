# Project goal - to add the Births by Parents' Country of Births report and underlying data to the London Datastore using 
# the London Datastore API

# N.B. A dataset called "Births by Parents' Country of Birth in London" has already been set up on the London Datastore

# N.B. This requires you to have previously installed  ldndatar from Github using a Github auth token and saved your 
# London Datastore API Key to your .Renviron file as an object called lds_api_key

# 1.0 Install and attach required packages ---------------------------------

# 1.1 Install and load required packages
# install.packages(c("tidyverse", "magrittr", "devtools", "rmarkdown"))
library(tidyverse)
library(magrittr)
library(devtools)
library(ldndatar)
library(rmarkdown)

# 1.2 Turn off scientific notation
options(scipen=999)

# 1.3 Set my_api_key for the London Datastore
my_api_key<-Sys.getenv("lds_api_key")

# Section 2 - Add Description and Resources to dataset ---------------------

# 2.1 Add births_by_mothers_country_of_birth_markdown.Rmd to the dataset as its description
new_description<-
  list(lds_description_render(
  "births_by_mothers_country_of_birth_markdown.Rmd",
  include_title=FALSE,
  save_html=FALSE)
  )
names(new_description)<-"description"

lds_patch_dataset(
  slug="births-by-parents-country-of-birth-in-london",
  my_api_key,
  patch=new_description
  )

# 2.2 Add all resources to the dataset

# Create list of resources which need to be uploaded
datastore_resources_list<-
  c(as.list(list.files("data/", pattern="births_by_mothers_country_of_birth", full.names=TRUE)),
    as.list(list.files("figures/", recursive=TRUE, full.names=TRUE)))
names(datastore_resources_list)<-seq(1:length(datastore_resources_list))

# The following algorithm checks if there are any resources associated with this dataset, and uploads all the ones in
# datastore_resources_list if there aren't any. If there are already resources associated with the dataset which is 
# being modified then it checks if each of the new resources has a similar name to one of the resources which is 
# already present. If the new resources does have a similar name to an existing one then the former overwrites 
# the latter, whereas new resources which do not have names which are similar to existing resources are uploaded 
# without replacing an existing resource.

if (!"resource_id" %in% colnames(lds_meta_dataset(slug="births-by-parents-country-of-birth-in-london", my_api_key))) {
  
  map(datastore_resources_list,
      ~lds_add_resource(
        file_path=.x,
        slug="births-by-parents-country-of-birth-in-london",
        my_api_key
      ))
  
} else {
  
  datastore_resources_list<-
    bind_rows(datastore_resources_list) %>% 
    gather(number, name) %>% 
    select(name) %>% 
    mutate(name2=basename(name)) %>% 
    mutate(name2=str_remove(name2, "_[:digit:]{4}.jpeg|_[:digit:]{4}.csv"))
  
  current_resources_names<-
    select(as_tibble(lds_meta_dataset(slug="births-by-parents-country-of-birth-in-london", my_api_key)),
           resource_title,
           resource_id) %>% 
    mutate(resource_title2=str_remove(resource_title, "_[:digit:]{4}.pdf|_[:digit:]{4}.xlsx|_[:digit:]{4}.tiff|_[:digit:]{4}.csv|_[:digit:]{4}.jpeg"))
  
  datastore_resources_list<-
    full_join(datastore_resources_list,
              current_resources_names, by=c("name2"="resource_title2")) %>% 
    mutate(name_for_resource=str_remove(name, "figures//maps/|figures//|maps/|data//"))
  
  for (i in 1:nrow(datastore_resources_list)) {
    
    if (is.na(datastore_resources_list$resource_id[i])) {
      
      lds_add_resource(
        file_path=datastore_resources_list$name[i],
        slug="births-by-parents-country-of-birth-in-london",
        my_api_key
      )
    }
    
    else {
      
      lds_replace_resource(
        file_path=datastore_resources_list$name[i],
        slug="births-by-parents-country-of-birth-in-london",
        res_id=datastore_resources_list$resource_id[i],
        res_title=datastore_resources_list$name_for_resource[i],
        api_key=my_api_key
      )
    }
  }
}

# Section 3 - Clear Environment -------------------------------------------

# 3.1
rm(list = ls())    
