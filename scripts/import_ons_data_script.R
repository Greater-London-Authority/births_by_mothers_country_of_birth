# Aim - to automatically download ONS data on live births by mother's country of origin and wrangle into the correct format for
# generating automated reports

# Section 1 - Install and load necessary packages -------------------------

# 1.1. Install and attach packages
# install.packages(c("tidyverse", "magrittr", "readxl", "rvest", "lubridate", "stringr", "utils", "tidyxl", "unpivotr", "kableExtra"))
library(tidyverse)
library(magrittr)
library(openxlsx)
library(rvest)
library(lubridate)
library(stringr)
library(utils)
library(readxl)
library(tidyxl)
library(unpivotr)

# 1.2 Turn off scientific notation
options(scipen=999)

# 1.3 Set-up working directory folders
if (!dir.exists("data")) {dir.create("data")}
if (!dir.exists("scripts")) {dir.create("scripts")}
if (!dir.exists("figures")) {dir.create("figures")}

# Section 2 - Scrape data from www.ons.gov.uk ---------------------------------

# 2.1 Extract years covered by the data
years<-
  read_html("https://www.ons.gov.uk/peoplepopulationandcommunity/birthsdeathsandmarriages/livebirths/datasets/parentscountryofbirth") %>% 
  html_nodes(".margin-bottom--0") %>% 
  html_text() %>%
  str_extract("\\d{4}")
years <- years[!is.na(years)]

# 2.2 Get ONS workbook URLs
workbook_urls<-
  read_html("https://www.ons.gov.uk/peoplepopulationandcommunity/birthsdeathsandmarriages/livebirths/datasets/parentscountryofbirth") %>% 
  html_nodes(".btn--thick") %>% 
  html_attr("href") %>% 
  as.list()

# 2.3 Add full filepaths to workbook_urls and name them with years from the timeseries
workbook_urls<-map(workbook_urls, ~paste0("https://www.ons.gov.uk", .x))
names(workbook_urls)<-years

# 2.4 Create ons_workbooks folder if it doesn't already exist
if (!dir.exists("data/ons_workbooks")) {dir.create("data/ons_workbooks")}

# 2.5 Download ONS workbooks to ons_workbooks folder (deleting any .xls files which are already present)

# Delete contents of ons_workbooks folder
list.files("data/ons_workbooks", full.names=TRUE) %>% unlink(TRUE)

# Download workbooks with download.file - added pause after each download to try and reduce number of failed downloads
for(i in 1:length(workbook_urls)){
  x <- workbook_urls[[i]]
  if(str_detect(x, "\\b.xlsx\\b")){
    if(!file.exists(paste0("data/ons_workbooks/", names(workbook_urls)[i], ".xlsx"))){
      download.file(x, destfile=paste0("data/ons_workbooks/", names(workbook_urls)[i], ".xlsx"), mode="wb")
    }
  } else {
    if(!file.exists(paste0("data/ons_workbooks/", names(workbook_urls)[i], ".xls"))){
      download.file(x, destfile=paste0("data/ons_workbooks/", names(workbook_urls)[i], ".xls"), mode="wb")
    }
  }
  Sys.sleep(1)
}

# Remove workbook_urls
rm(workbook_urls)

# Section 2 - Import relevant worksheets from ons_workbooks ---------------

# 2.1 Set headings and name areas to be extracted
headings<-c("usual_residence_of_mother", "total_births_all", "total_births_uk_mothers", "total_births_overseas_mothers",
            "remove1", "remove2", "overseas_mothers_total_EU", "overseas_mothers_post2004_EU_accession_countries",
            "overseas_mothers_non_EU_europe", "overseas_mothers_asia", "overseas_mothers_africa", "overseas_mothers_rest_of_world")
headings2<-headings[-6]
# column order changed for 2022 - africa swapped places with middle east and asia 
headings3<-c("usual_residence_of_mother", "total_births_all", "total_births_uk_mothers", "total_births_overseas_mothers",
             "remove1", "overseas_mothers_total_EU", "overseas_mothers_post2004_EU_accession_countries",
             "overseas_mothers_non_EU_europe", "overseas_mothers_africa", "overseas_mothers_asia", "overseas_mothers_rest_of_world")

regions<-c("EAST", "EAST OF ENGLAND", "EAST MIDLANDS", "ENGLAND", "LONDON", "NORTH EAST", "NORTH WEST", "SOUTH EAST",
           "SOUTH WEST", "WALES", "WEST MIDLANDS", "YORKSHIRE AND THE HUMBER")
boroughs<-dplyr::pull(read_csv("borough_names.csv"))
regions_and_boroughs<-c(regions, boroughs)

# 2.2 Import data for 2001-2009
workbook_2009<-list.files("data/ons_workbooks", pattern="2009.xls", full.names=TRUE)
sheets_2009<-as.list(seq(10, 18)) 
data_2001_2009<-map(sheets_2009, ~read_xls(workbook_2009, sheet=.x, skip=10, col_names=headings))
rm(sheets_2009)

data_2001_2009<- 
  map(data_2001_2009,
    ~.x %>% 
      filter(!is.na(total_births_all)) %>% 
      select(-contains("remove")) %>% 
      filter(usual_residence_of_mother %in% regions_and_boroughs) %>% 
      mutate(usual_residence_of_mother = recode(usual_residence_of_mother,
                                                "EAST" = "EAST OF ENGLAND")) %>%
      distinct(usual_residence_of_mother, .keep_all=TRUE) %>% 
      mutate_at(vars(total_births_all:overseas_mothers_rest_of_world), ~as.numeric(.)))

fix_hackney<-function(x) {
  
  data<-x
  
  hackney_and_col<-
    data %>% 
    filter(str_detect(usual_residence_of_mother, "^City of London$|^Hackney$")) %>% 
    summarise_if(is.numeric, sum, na.rm=TRUE) %>% 
    mutate(usual_residence_of_mother="Hackney and City of London") %>% 
    select(usual_residence_of_mother,
           total_births_all:overseas_mothers_rest_of_world)
  
  data<-
    data %>% 
    filter(!str_detect(usual_residence_of_mother, "^City of London$|^Hackney$")) %>% 
    rbind(hackney_and_col)
  
  return(data)
}


data_2001_2009[2:9]<-map(data_2001_2009[2:9], ~fix_hackney(.x))

names(data_2001_2009)<-seq(2009, 2001)

# 2.3 Import data for 2010 onwards (N.B. this code assumes the relevant data is always on a worksheet called "Table 7" or "7")
workbooks_2010_onwards<-as.list(list.files("data/ons_workbooks", pattern="20[1-99]", full.names=TRUE))

get_sheet_name <- function(path, valid_names = c("Table 7", "7", "Table_6a")) {
  
  sheetnames <- excel_sheets(path)
  sheetname <- sheetnames[sheetnames %in% valid_names]
  
  return(sheetname)
}

sheetnames_2010_onwards<- lapply(workbooks_2010_onwards, get_sheet_name)
workbooks_2010_onwards<-map2(workbooks_2010_onwards, sheetnames_2010_onwards, ~read_excel(.x, .y))
names(workbooks_2010_onwards)<-rev(years[str_detect(years, "20[1-99]")]) 

if (!dir.exists("data/ons_workbooks/xlsx_files")) {dir.create("data/ons_workbooks/xlsx_files")}
list.files("data/ons_workbooks/xlsx", full.names=TRUE) %>% unlink(TRUE)

for(i in 1:length(workbooks_2010_onwards)){
  write.xlsx(workbooks_2010_onwards[[i]],
             paste0("data/ons_workbooks/xlsx_files/year", names(workbooks_2010_onwards)[i], ".xlsx"))
}

rm(workbooks_2010_onwards)

# 2.4 Clean data for 2010 onwards
extract_births_data<-function(x) {
  
# Import .xlsx file using xlsx_cells()
  data<-xlsx_cells(x) 
  
# Extract list of rows containing the names of the regions we want to extract
  get_regions<-           
    data %>%
    filter(character %in% regions) %>% 
    select(row) %>% 
    pull()
  
  get_boroughs<-           
    data %>%
    filter(character %in% boroughs) %>% 
    select(row) %>% 
    pull()

# Filter rows on the list of rows specified above and turn back into a spreadsheet
  data<-
    data %>% 
    filter(row %in% get_regions|row %in% get_boroughs) %>%
    select(row, col, character, data_type) %>% 
    spatter(col) %>% 
    select(-row,
           -`1`)

  return(data)
}
data_2010_onwards<-map(as.list(list.files("data/ons_workbooks/xlsx_files", full.names=TRUE)), ~extract_births_data(.x))
names(data_2010_onwards)<-seq(2010, 2010+(length(data_2010_onwards)-1))


data_2010_onwards[c(1:5, 7, 8)]<-
  map(data_2010_onwards[c(1:5, 7, 8)],
    ~.x %>% 
      distinct(`2`, .keep_all=TRUE) %>% 
      set_colnames(headings2) %>%
      mutate(usual_residence_of_mother = recode(usual_residence_of_mother,
                                                "EAST" = "EAST OF ENGLAND"))
    )

# data for 2015 comes through with geography codes in column 2
data_2010_onwards[[6]]<-
  data_2010_onwards[[6]] %>%
  distinct(`3`, .keep_all=TRUE) %>% 
  select(-`2`) %>% 
  set_colnames(headings2)

# 2018 onwards includes the 'geography' variable
data_2010_onwards[9:12]<-
  map(data_2010_onwards[9:12],
    ~.x %>% 
      distinct(`2`, .keep_all=TRUE) %>% 
      select(-`3`) %>% 
      set_colnames(headings2))

# africa and middle east/asia swapped order in 2022 
#TODO currently assume this will continue in subsequent years
data_2010_onwards[13:length(data_2010_onwards)]<-
  map(data_2010_onwards[13:length(data_2010_onwards)],
      ~.x %>% 
        distinct(`2`, .keep_all=TRUE) %>% 
        select(-`3`) %>% 
        set_colnames(headings3))

data_2010_onwards<-
  data_2010_onwards<-
  map(data_2010_onwards,
    ~.x %>% 
      select(-contains("remove")) %>% 
      mutate_at(vars(contains(c("total", "overseas"))), ~as.numeric(.)))

data_2010_onwards[5:length(data_2010_onwards)]<-map(data_2010_onwards[5:length(data_2010_onwards)], ~fix_hackney(.x))
  
# 2.5 Combine data_2001_2009 and data_2010_onwards
births_by_mothers_country_of_birth<-c(rev(data_2001_2009), data_2010_onwards)
rm(data_2001_2009, data_2010_onwards)

# Section 3 - Add geographical lookup information --------

# 3.1 Add ONS codes and regions taken from most recent ONS dataset
latest_data<-
  paste0("data/ons_workbooks/xlsx_files/", list.files("data/ons_workbooks/xlsx_files", pattern=as.character(max(as.numeric(years)))))

region_and_borough_rows<-
  xlsx_cells(latest_data) %>% 
  filter(character %in% regions_and_boroughs) %>% 
  select(row) %>% 
  pull()

latest_data<-
  xlsx_cells(latest_data) %>% 
  filter(row %in% region_and_borough_rows,
         col==1 | col==2 | col==3) %>% 
  select(row, col, character, data_type) %>% 
  spatter(col) %>% 
  select(-row,
         gss_code=`1`,
         name=`2`,
         type=`3`) %>% 
  mutate(name=ifelse(as.character(name)=="Hackney", "Hackney and City of London", as.character(name))) %>% 
  filter(name!="City of London")

births_by_mothers_country_of_birth<-
  map(births_by_mothers_country_of_birth, ~left_join(.x, latest_data, by=c("usual_residence_of_mother"="name")))

# 3.2 Re-arrange columns
births_by_mothers_country_of_birth<-
  map(births_by_mothers_country_of_birth,
    ~.x %>% 
      mutate(overseas_mothers_pre2004_EU_countries=overseas_mothers_total_EU-overseas_mothers_post2004_EU_accession_countries) %>% 
      select(gss_code,
             usual_residence_of_mother,
             type,
             total_births_all:overseas_mothers_total_EU,
             overseas_mothers_pre2004_EU_countries,
             overseas_mothers_post2004_EU_accession_countries:overseas_mothers_rest_of_world) %>% 
      mutate(type=factor(type, levels=c("Country", "Region", "London Borough"), ordered=TRUE)) %>% 
      arrange(type))

# 3.3 Add a year variable to each dataset
births_by_mothers_country_of_birth<-
  map2(births_by_mothers_country_of_birth, names(births_by_mothers_country_of_birth), cbind)

births_by_mothers_country_of_birth<-
  map(births_by_mothers_country_of_birth, ~select(.x,
                                                year=contains(".y"),
                                                gss_code:overseas_mothers_rest_of_world))

# Section 4 - Export data -------------------------------------------------

# 4.1 Delete any older versions of the dataset which are already present in the data folder
map(as.list(list.files("data", pattern="births_by_mothers_country_of_birth_2001_to", full.names=TRUE)), ~unlink(.x))

# 4.2 Bind rows of births_by_mothers_country_of_birth
births_by_mothers_country_of_birth<-bind_rows(births_by_mothers_country_of_birth)

# 4.3 Export births_by_mothers_country_of_birth to .csv
write_csv(
  births_by_mothers_country_of_birth,
  paste0("data/births_by_mothers_country_of_birth_", "2001_to_", as.character(max(as.numeric(years))), ".csv")
  )

# # 4.2 Import metadata_text
# metadata_text<-read_tsv("metadata_text.txt", col_names=FALSE)
# names(metadata_text)<-"Metadata"
# 
# # 4.3 Add metadata_text to dataset
# births_by_mothers_country_of_birth<-c(metadata_text, births_by_mothers_country_of_birth)

# 4.5 Clear environment
rm(list = ls())

