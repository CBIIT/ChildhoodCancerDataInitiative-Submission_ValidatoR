#!/usr/bin/env Rscript

#Childhood Cancer Data Initiative - Submission ValidatoR v1.0.0


##################
#
# USAGE
#
##################

#This takes a CCDI Metadata template file as input and creates an output file basesd on the QC checks.

#Run the following command in a terminal where R is installed for help.

#Rscript --vanilla CCDI-Submission_ValidatoR.R --help

##################
#
# Env. Setup
#
##################

#List of needed packages
list_of_packages=c("dplyr","tidyr","readr","stringi","janitor","readxl","openxlsx","optparse","tools")

#Based on the packages that are present, install ones that are required.
new.packages <- list_of_packages[!(list_of_packages %in% installed.packages()[,"Package"])]
suppressMessages(if(length(new.packages)) install.packages(new.packages, repos = "http://cran.us.r-project.org"))

#Load libraries.
suppressMessages(library(dplyr,verbose = F))
suppressMessages(library(readr,verbose = F))
suppressMessages(library(tidyr,verbose = F))
suppressMessages(library(stringi,verbose = F))
suppressMessages(library(janitor,verbose = F))
suppressMessages(library(readxl,verbose = F))
suppressMessages(library(openxlsx,verbose = F))
suppressMessages(library(optparse,verbose = F))
suppressMessages(library(tools,verbose = F))

#remove objects that are no longer used.
rm(list_of_packages)
rm(new.packages)


##################
#
# Arg parse
#
##################

#Option list for arg parse
option_list = list(
  make_option(c("-f", "--file"), type="character", default=NULL, 
              help="CCDI submission template workbook file (.xlsx, .tsv, .csv)", metavar="character"),
  make_option(c("-t", "--template"), type="character", default=NULL, 
              help="CCDI dataset template file, can be the same Metadata template workbook file or a blank CCDI_submission_metadata_template.xlsx", metavar="character")
)

#create list of options and values for file input
opt_parser = OptionParser(option_list=option_list, description = "\nCCDI-Submission_ValidationR v1.0.0")
opt = parse_args(opt_parser)

#If no options are presented, return --help, stop and print the following message.
if (is.null(opt$file)&is.null(opt$template)){
  print_help(opt_parser)
  cat("Please supply both the input file (-f) and template file (-t), CCDI_submission_metadata_template.xlsx.\n\n")
  suppressMessages(stop(call.=FALSE))
}

#Data file pathway
file_path=file_path_as_absolute(opt$file)

#Template file pathway
template_path=file_path_as_absolute(opt$template)

#A start message for the user that the validation is underway.
cat("The data file is being validated at this time.\n")


###############
#
# Start write out
#
###############

#Rework the file path to obtain a file name, this will be used for the output file.
file_name=stri_reverse(stri_split_fixed(stri_reverse(basename(file_path)),pattern = ".", n=2)[[1]][2])
ext=tolower(stri_reverse(stri_split_fixed(stri_reverse(basename(file_path)),pattern = ".", n=2)[[1]][1]))
path=paste(dirname(file_path),"/",sep = "")

#Output file name based on input file name and date/time stamped.
output_file=paste(file_name,
                  "_Validate",
                  stri_replace_all_fixed(
                    str = Sys.Date(),
                    pattern = "-",
                    replacement = ""),
                  sep="")

#Start writing in the outfile.
sink(paste(path,output_file,".txt",sep = ""))

cat(paste("This is a validation output for ",file_name,".\n----------",sep = ""))

###############
#
# Expected sheets to check
#
###############

#Pull sheet names
sheet_names=excel_sheets(path = template_path)
sheet_gone=FALSE

#Expected sheet names for a basic template
expected_sheets=c("Dictionary",             
                  "Terms and Value Sets")

#Test to see if expected sheet names are present.
if (all(expected_sheets%in%sheet_names)){
  cat("\n\tPASS: Found expected sheets in the submitted template file.\n")
}else{
  sheet_gone=TRUE
}

#If any sheet is missing, throw an overt error message then stops the process. This script pulls information from the expected sheets and requires all sheets present before running.
template_warning="\n\n################################################################################################################################\n#                                                                                                                              #\n# ERROR: Please obtain a new data template with all sheets and columns present before making further edits to this one.        #\n#                                                                                                                              #\n################################################################################################################################\n\n\n"

if (sheet_gone==TRUE){
  stop(paste("\nThe following sheet(s) is/are missing in the template file: ",paste(expected_sheets[!expected_sheets%in%sheet_names],collapse = ", "), template_warning, sep = ""), call.=FALSE)
}


##############
#
# Pull Dictionary Page to create node pulls
#
##############

#Read in Dictionary page to obtain the required properties.
df_dict=suppressMessages(read.xlsx(xlsxFile = template_path,sheet = "Dictionary"))
df_dict=remove_empty(df_dict,c('rows','cols'))

#Look for all entries that have a value
all_properties=unique(df_dict$Property)[grep(pattern = '.',unique(df_dict$Property))]
#Remove all entries that are all spaces
all_properties=all_properties[!grepl(pattern = " ",x = all_properties)]
#Pull out required property groups
required_property_groups=unique(df_dict$Required[!is.na(df_dict$Required)])
required_properties=df_dict$Property[!is.na(df_dict$Required)]
#Pull out nodes to read in respective tabs
dict_nodes=unique(df_dict$Node)


################
#
# Read in TaVS page to create value checks
#
################

#Read in Terms and Value sets page to obtain the required value set names.
df_tavs=suppressMessages(read.xlsx(xlsxFile = template_path, sheet = "Terms and Value Sets"))
df_tavs=remove_empty(df_tavs,c('rows','cols'))

#Pull out the positions where the value set names are located
VSN=unique(df_tavs$Value.Set.Name)
VSN=VSN[!is.na(VSN)]

df_all_terms=list()

#Pull the list of values for each controlled vocabulary property.
for (VSN_indv in VSN){
    df_all_terms[[VSN_indv]] = list(filter(df_tavs,Value.Set.Name==VSN_indv)["Term"][[1]])
  }


##############
#
# Read in each tab and apply to a data frame list
#
##############

cat("\n\nReading in the Metadata template workbook.\n----------")

# A bank of NA terms to make sure NAs are brought in correctly
NA_bank=c("NA","na","N/A","n/a")

#Establish the list
workbook_list=list()

#create a list of all node pages with data
for (node in dict_nodes){
  #read the sheet
  df=readWorkbook(xlsxFile = file_path,sheet = node, na.strings = NA_bank)
  #create an emptier version that removes the type and makes everything a character
  df_empty_test=df%>%
    select(-type)%>%
    mutate(across(everything(), as.character))
  #remove empty rows and columns
  df_empty_test=remove_empty(df_empty_test,c("rows","cols"))
  
  #if there are at least one row in the resulting data frame, add it
  if (dim(df_empty_test)[1]>0){
    #if the only columns in the resulting data frame are only linking properties (node.node_id), do not add it.
    if (any(!grepl(pattern = "\\.",x = colnames(df_empty_test)))){
      #add the data frame to the workbook
      df_typeless=df%>%
        select(-type)
      workbook_list=append(x = workbook_list,values = list(df_typeless))
      names(workbook_list)[length(workbook_list)]<-node
    }else{
      cat("\n\tWARNING: The following node, ", node,", did not contain any data except a linking value and type.\n" ,sep = "")
    }
  }
}

nodes_present=names(workbook_list)

####################
#
# Write out for validation
#
####################


##################
#
# Required property completeness and white space
#
##################

cat("\n\nThis section is for required properties for all nodes that contain data.\nFor information on required properties per node, please see the 'Dictionary' page of the template file.\nFor each entry, it is expected that all required information has a value:\n----------")

#For required columns in nodes, it will check if all required columns have values. If there are missing values or the values within the required column contain leading and/or trailing white space, it will return those row positions for the required columns.

for (node in nodes_present){
  cat("\n",node,"\n",sep = "")
  #initialize data frames and properties for tests
  df=workbook_list[node][[1]]
  properties=colnames(df)
  df_ws=df

  required_properties=df_dict$Property[grepl(pattern = TRUE,x = df_dict$Required %in% node)]
  if ("file_url_in_cds" %in% properties & "file_name" %in% properties & "file_size" %in% properties & "md5sum" %in% properties & "dcf_indexd_guid" %in% properties){
    file_req_props=c("file_name","file_size","file_type","md5sum","file_url_in_cds","dcf_indexd_guid")
    required_properties=unique(c(required_properties,file_req_props))
  }
  #initialize possible bad rows/cols
  bad_cols_all=c()
  
  if (!all(required_properties %in% colnames(df))){
    present_required_properties=required_properties[required_properties %in% colnames(df)]
    missing_required_properties=required_properties[!required_properties %in% colnames(df)]
    cat("\t####################################\n\tERROR: The following required columns are missing in this template: ", paste(missing_required_properties,collapse = ", "),".\n\tObtain a new template with the correct required properties present.\n\t####################################\n", sep = "")
    required_properties=present_required_properties
  }
  #If all required properties are present, continue test or skip and note that required properties are missing.
  df_req=df %>%
    select(all_of(required_properties))
  
  for (required_property in required_properties){
    
    #initialize possible bad rows/cols
    bad_rows=c()
    bad_cols_add=c()
    
    if (required_property %in% colnames(df)){
      
      #check for rows that have any NA's or '' blank values
      bad_rows=grep(pattern = TRUE, x = !grepl(pattern = ".", x = df_req[required_property][[1]]))
      if (required_property=="dcf_indexd_guid" & length(bad_rows)==dim(df_req)[1]){
        bad_cols_add=grep(pattern = TRUE, x = colnames(df_req) %in% required_property)
        bad_cols_all=c(bad_cols_all,bad_cols_add)
        cat("\tERROR: For the node, ",node,", values still need to be generated for the required property, ", required_property,".\n", sep = "")
      }else if (length(bad_rows)>0){
        bad_cols_add=grep(pattern = TRUE, x = colnames(df_req) %in% required_property)
        bad_cols_all=c(bad_cols_all,bad_cols_add)
        for (bad_row in bad_rows){
          cat("\tERROR: There is a missing value for the node, ",node,", in the required property, ", required_property,", on row: ", bad_row+1,"\n", sep = "")
        }
      }
    }else{
      missing_req_props=required_properties[!required_properties %in% colnames(df)]
      cat("\tERROR: For the node, ", node, " there are missing required columns: ",paste(missing_req_props,collapse = ", ",sep = ""),"\n",sep = "")
    }
  }
  
  #Check for white space in all values
  for (property in properties){
    
    #initialize possible bad rows/cols
    bad_rows=c()
    bad_cols_add=c()
    
    for (x in 1:dim(df[property])[1]){
      df_ws[property][x,]=trimws(df[property][x,])
    }
    
    #Return value positions that are either empty (NA) or contain leading/trailing white space in the value for the required column.
    if (!all(is.na(df_ws[property]))){
      if (!all(na.omit(df_ws[property]==df[property]))){
        bad_rows=grep(pattern = FALSE, x = df_ws[property]==df[property])
        if (property %in% required_properties){
          bad_cols_add=grep(pattern = TRUE, x = colnames(df_req) %in% property)
          bad_cols_all=c(bad_cols_all,bad_cols_add)
        }
        for (bad_row in bad_rows){
          if (!all(is.na(df[bad_row,property]))){
            cat(paste("\tERROR: For the node, ", node,", leading/trailing white space was found in the property, ",property,", on row: ", bad_row+1,"\n", sep = ""))
          }
        }
      }
    }
  }
  
  #Summary of required columns that pass with no issue
  #Based on all the noted column issues, create a unique list of bad columns
  bad_cols_all=unique(bad_cols_all)
  
  if (length(bad_cols_all)<length(required_properties)){
    if(is.null(bad_cols_all)){
      pass_cols=required_properties
    }else{
      pass_cols=required_properties[-bad_cols_all]
    }
    for (pass_col in pass_cols){
      cat("\tPASS: For the node, ", node,", the required property, ",pass_col,", contains values for all expected entries.\n",sep = "")
    }
    #cat("\n")
  }
}


##################
#
# Terms and Value sets checks
#
##################

cat("\n\nThe following columns have controlled vocabulary on the 'Terms and Value Sets' page of the template file:\n----------")

for (node in nodes_present){
  cat("\n",node,"\n",sep = "")
  #initialize data frames and properties for tests
  df=workbook_list[node][[1]]
  properties=colnames(df)
  #Enumerated Array properties
  enum_arrays=c('therapeutic_agents',"treatment_type","study_data_types","morphology","primary_site","race")
  
  #For the '_id' properties, make sure there are no illegal characters and it only has "Only the following characters can be included in the ID: English letters, Arabic numerals, period (.), hyphen (-), underscore (_), at symbol (@), and the pound sign (#)."
  for (property in properties){
    if (grepl(pattern = "_id", x = property)){
      bad_id_loc=grep(pattern = FALSE, x = grepl(pattern = '^[a-zA-Z0-9_.@#-]*$', x = df[property][[1]]))
      if (length(bad_id_loc)>0){
        bad_cols_add=grep(pattern = TRUE, x = colnames(df_req) %in% property)
        bad_cols_all=c(bad_cols_all,bad_cols_add)
        for (bad_id in bad_id_loc){
          if (!is.na(df[property][[1]][bad_id])){
            cat(paste("\tERROR: The following ID, ",df[property][[1]][bad_id], ", has an illegal character (acceptable: A-z,0-9,_,.,-,@,#) in the property, ",property,".\n",sep = ""))
          }
        }
      }
    }
    if (property %in% names(df_all_terms)){
      if (property %in% enum_arrays){
        unique_values=unique(df[property][[1]])
        unique_values=unique(trimws(unlist(stri_split_fixed(str = unique_values,pattern = ";"))))
        unique_values=unique_values[!is.na(unique_values)]
        if (length(unique_values)>0){
          if (!all(unique_values%in%df_all_terms[property][[1]][[1]])){
            for (x in 1:length(unique_values)){
              check_value=unique_values[x]
              if (!is.na(check_value)){
                if (!as.character(check_value)%in%df_all_terms[property][[1]][[1]]){
                  cat(paste("\tERROR: ",property," property contains a value that is not recognized: ", check_value,"\n",sep = ""))
                }
              }
            }
          }else{
            cat(paste("\tPASS:",property,"property contains all valid values.\n"))
          }
        }
      }else{
        unique_values=unique(df[property][[1]])
        unique_values=unique_values[!is.na(unique_values)]
        if (length(unique_values)>0){
          if (!all(unique_values%in%df_all_terms[property][[1]][[1]])){
            for (x in 1:length(unique_values)){
              check_value=unique_values[x]
              if (!is.na(check_value)){
                if (!as.character(check_value)%in%df_all_terms[property][[1]][[1]]){
                  cat(paste("\tERROR: ",property," property contains a value that is not recognized: ", check_value,"\n",sep = ""))
                }
              }
            }
          }else{
            cat(paste("\tPASS:",property,"property contains all valid values.\n"))
          }
        }
      }
    }
  }
}

#################
#
# Unique Key check
#
#################

cat("\n\nThe following will check for multiples of key values, which are expected to be unique.\nIf there are any unexpected values, they will be reported below:\n----------")

#for each node create a data frame to check
for (node in nodes_present){
  cat("\n",node,"\n",sep = "")
  #initialize data frames and properties for tests
  df=workbook_list[node][[1]]
  properties=colnames(df)

  #if the node is a file node, set the key value
  if ("file_url_in_cds" %in% properties & "file_name" %in% properties & "file_size" %in% properties & "md5sum" %in% properties & "dcf_indexd_guid" %in% properties){
    key_value_prop="dcf_indexd_guid"
  }else{
    key_value=df_dict%>%
      filter(Node==node, Key=="TRUE")
    
    key_value_prop=key_value$Property
  }
  
  #check to make sure the key value exists, is not only NA and is the same value if it was unique.
  if (key_value_prop %in% properties){
    if (any(!is.na(df[key_value_prop]))){
      if (dim(df[key_value_prop])[1] != dim(unique(df[key_value_prop]))[1]){
        cat("\tERROR: The following node, ", node, ", has multiple instances of the same key value, which should be unique, in the property, ", key_value_prop,":\n",sep = "")
        id_table=as.data.frame(table(df[key_value_prop][[1]]))
        id_table_gtr1=id_table%>%
          filter(Freq>1)
        cat("\t\t",paste(id_table_gtr1$Var1,"\n\t\t",collapse = "",sep = ""),sep = "")
      }
    }else {
      cat("\tERROR: The following node, ", node, ", has no key values in the property, ", key_value_prop,".\n",sep = "")
    }
  }
}


#################
#
# Library to sample check
#
#################

cat("\n\nThis submission and subsequent submission files derived from this template assume that a library_id is associated to only one sample_id.\nIf there are any unexpected values, they will be reported below:\n----------")

#obtain df with libraries and samples
df=workbook_list['sequencing_file'][[1]]
library_id_list=unique(df$library_id)

#For each library_id check to see how many instances it is found.
for (library_id in unique(df$library_id)){
  if(!is.na(library_id)){
    grep_instances=unique(df$sample.sample_id[grep(pattern = TRUE, x = df$library_id %in% library_id)])
    if (length(grep_instances)>1){
      cat("\nERROR: The library_id, ",library_id,", has multiple samples associated with it: \n\t", paste(grep_instances,collapse = "\n\t",sep = "") ,"\n\t\tThis setup will cause issues when submitting to SRA.\n",sep = "")
    }
  }
}


#################
#
# Require certain properties based on the file type.
#
#################

#For BAM, CRAM and Fastq files, we expect that all the files to have only one sample associated with them and the following properties: avg_read_length, coverage, bases, reads.

cat("\n\nThis submission and subsequent submission files derived from the sequencing file template assume that FASTQ, BAM and CRAM files are single sample files, and contain all associated metadata for submission.\nIf there are any unexpected values, they will be reported below:\n----------")

#obtain df for seq files
df=workbook_list['sequencing_file'][[1]]
library_id_list=unique(df$library_id)

#Gather all file types.
file_types=c("bam","cram","fastq")
prob_sample_id_locs=c()
prob_file_locs=c()

#For each position, check to see if there are any samples that share the same library_id and make sure that the values for the required properties for SRA submission are present.      
for (file_type in file_types){
  single_sample_seq_files=grep(pattern = TRUE, x = tolower(df$file_type) %in% file_type)
  for (file_location in single_sample_seq_files){
    sample_id=unique(df$sample.sample_id[file_location])
    file_url=unique(df$file_url_in_cds[file_location])
    file_name=unique(df$file_name[file_location])
    sample_id_loc=unique(grep(pattern = TRUE, x = (df$sample.sample_id %in% sample_id)))
    sample_id_loc=sample_id_loc[grep(pattern=TRUE, x = (df$file_type[sample_id_loc] %in% file_types))]
    file_url_loc=unique(grep(pattern = TRUE, x = (df$file_url_in_cds %in% file_url)))
    file_name_loc=unique(grep(pattern = TRUE, x = (df$file_name %in% file_name)))
    
    if (length(sample_id_loc)>1){
      if (!any(sample_id_loc %in% prob_sample_id_locs)){
        cat("\nWARNING: The sample, ", sample_id, ", has multiple single sample files associated with it. These could cause errors in SRA submissions if this is unexpected.\n",paste("\t",df$file_name[sample_id_loc],collapse = "\n",sep = ""),sep = "")
      }
      prob_sample_id_locs=c(prob_sample_id_locs, sample_id_loc)
    }
    
    #if there are any urls or files 
    if (any(length(file_url_loc)>1 | length(file_name_loc)>1)){
      if (!any(file_name_loc %in% prob_file_locs)){
      cat("\nWARNING: The following file, ", file_name, ", is found multiple times.",sep = "")
        sample_file_loc=unique(df$sample.sample_id[file_name_loc])
        file_url_file_loc=unique(df$file_url_in_cds[file_name_loc])
        prob_file_locs=c(prob_file_locs,file_name_loc)
        #If there are multiple samples related to a file, it will note them
        if (length(sample_file_loc)>1){
          cat("\n\tERROR: There are multiple samples associated with the single sample file, ",file_name,".",paste("\n\t\t",sample_file_loc,collapse = "",sep = ""), sep = "")
        }
        
        #If there are multiple url locations to a file, it will note them
        if(length(file_url_file_loc)>1){
          cat("\n\tWARNING: There are multiple url locations associated with the file, ",file_name,".",paste("\n\t\t",file_url_file_loc,collapse = "",sep = ""), sep = "")
        }
      }
    }  
    
    #Check to see if the expected SRA metadata is present for the files going to the SRA submission.
    bases_check= df$number_of_bp[file_location]
    avg_read_length_check=df$avg_read_length[file_location]
    coverage_check=df$coverage[file_location]
    reads_check=df$number_of_reads[file_location]
    #for fastq files, skips the checks for coverage values to be present
    if (file_type=="fastq"){
      SRA_checks=c(bases_check, avg_read_length_check, reads_check)
      if (any(is.na(SRA_checks))){
        cat(paste("\nERROR: The file, ",df$file_name[file_location],", is missing at least one expected value (bases, avg_read_length, number_of_reads) that is associated with an SRA submission.",sep = ""))
      }
      if (!is.na(coverage_check)){
        cat(paste("\nWARNING: The file, ",df$file_name[file_location],", is not expected to have a coverage value.",sep = ""))
      }
      #for RNA-seq data, skips the checks for coverage values to be present
    }else if(tolower(df$library_strategy[file_location])=="rna-seq"){
      SRA_checks=c(bases_check, avg_read_length_check, reads_check)
      if (any(is.na(SRA_checks))){
        cat(paste("\nERROR: The file, ",df$file_name[file_location],", is missing at least one expected value (bases, avg_read_length, number_of_reads) that is associated with an SRA submission.\n",sep = ""))
      }
      if (!is.na(coverage_check)){
        cat(paste("\nWARNING: The file, ",df$file_name[file_location],", is not expected to have a coverage value.",sep = ""))
      }
    }else{
      SRA_checks=c(bases_check, avg_read_length_check, coverage_check, reads_check)
      if (any(is.na(SRA_checks))){
        cat(paste("\nERROR: The file, ",df$file_name[file_location],", is missing at least one expected value (bases, avg_read_length, coverage, number_of_reads) that is associated with an SRA submission.",sep = ""))
      }
    }
  }
}


#################
#
# File Checks
#
#################

cat("\n\nThe following section will compare the manifest against the reported buckets and note if there are unexpected results where the file is represented equally in both sources.\nIf there are any unexpected values, they will be reported below:\n----------\n")

#Pull out all nodes that have the file url, denoting that there are files in the node.
node_props=names(unlist(x = workbook_list, recursive = FALSE))
file_nodes=node_props[grep(pattern = "file_url_in_cds", x = node_props)]
file_nodes=unique(unlist(stri_split_fixed(str = file_nodes, pattern = ".",n = 2)))
file_nodes=file_nodes[!grepl(pattern = "file_url_in_cds", x = file_nodes)]
df_file=data.frame(matrix(ncol = 4,nrow = 0))
colnames(df_file)<-c("file_size","md5sum","file_url_in_cds","type")

for (node in file_nodes){
  #obtain df for files
  df=workbook_list[node][[1]]
  df$type=node
  df=df%>%
    select(file_size, md5sum,file_url_in_cds,type)
  df_file=rbind(df_file,df)
}
  
  
#################
#
# Check file metadata
#
#################

for (row_pos in 1:dim(df_file)[1]){
  if (!is.na(df_file$file_size[row_pos])){
    if (df_file$file_size[row_pos]==0){
      cat(paste("\tWARNING: The file in row ",row_pos+1,", has a size value of 0. Please make sure that this is a correct value for the file.\n",sep = ""))
    }
  }
  if (!is.na(df_file$md5sum[row_pos])){
    if (!stri_detect_regex(str = df_file$md5sum[row_pos],pattern = '^[a-f0-9]{32}$',case_insensitive=TRUE)){
      cat(paste("\tERROR: The file in row ",row_pos+1,", has a md5sum value that does not follow the md5sum regular expression.\n",sep = ""))
    }
  }
}


###############
#
# AWS bucket file check
#
###############

#Obtain bucket information
df_bucket=select(df_file, file_url_in_cds)%>%
  separate(file_url_in_cds,into = c("s3","blank","bucket","the_rest"),sep = "/",extra = "merge")%>%
  select(-s3,-blank,-the_rest)
df_bucket=unique(df_bucket)

#Check to see if there is only one bucket associated with the submission. It is not required, but it is likely that there would only be one bucket.
if (dim(df_bucket)[1]>1){
  cat(paste("\tWARNING: There is more than one aws bucket that is associated with this metadata file in the, ",node,", node: ", df_bucket$bucket,".\n",sep = ""))
}

#Do a list of the bucket and then check the file size and name against the metadata submission.
for (bucket_num in 1:dim(df_bucket)[1]){
  #pull bucket metadata
  metadata_files=suppressMessages(suppressWarnings(system(command = paste("aws s3 ls --recursive s3://", df_bucket[bucket_num,],"/",sep = ""),intern = TRUE)))
  
  #fix bucket metadata to have fixed delimiters of one space
  while (any(grepl(pattern = "  ",x = metadata_files))==TRUE){
    metadata_files=stri_replace_all_fixed(str = metadata_files,pattern = "  ",replacement = " ")
  }
  
  #Break bucket string into a data frame and clean up
  bucket_metadata=data.frame(all_metadata=metadata_files)
  bucket_metadata=separate(bucket_metadata, all_metadata, into = c("date","time","file_size","file_path"),sep = " ", extra = "merge")%>%
    select(-date, -time)%>%
    mutate(file_path=paste("s3://",df_bucket[bucket_num,],"/",file_path,sep = ""))
  bucket_metadata$file_size=as.character(bucket_metadata$file_size)
  df_bucket_specific=df_file[grep(pattern = df_bucket[bucket_num,], x = df_file$file_url_in_cds),]
  
  #For each row in the manifest for this bucket, check the contents of the bucket against the manifest.
  for (row in 1:dim(df_bucket_specific)[1]){
    #locate the file url
    file_name_loc=grep(pattern = TRUE, x = bucket_metadata['file_path'][[1]] %in% df_bucket_specific[row,'file_url_in_cds'][[1]])
    #if the file is found, find that file with the correct size
    if (length(file_name_loc)!=0){
      if (bucket_metadata[file_name_loc,'file_size']!=as.character(df_bucket_specific[row,'file_size'][[1]])){
        cat(paste("\tERROR: The following file does not have the same file size found in the AWS bucket: ", df_bucket_specific[row,'file_url_in_cds'][[1]],"\n", sep = ""))
      }
    }else{
      cat(paste("\tERROR: The following file is not found in the AWS bucket: ", df_bucket_specific[row,'file_url_in_cds'][[1]],"\n", sep = ""))
    }
  }
  
  #Finally, check the bucket against the manifest to determine if there are files in the bucket that are not noted in the manifest.
  for (bucket_file in bucket_metadata$file_path){
    bucket_value = bucket_file  %in% df_bucket_specific['file_url_in_cds'][[1]]
    if (!bucket_value){
      cat(paste("\tERROR: The following file is found in the AWS bucket and not the manifest that was provided: ", bucket_file,"\n", sep = ""))
    }
  }
}


###############
#
# Cross node validation (do linking values have corresponding values)
#
###############

cat("\n\nIf there are unexpected or missing values in the linking values between nodes, they will be reported below:\n----------")

for (node in nodes_present){
  #note node, create df and pull out linking values
  cat("\n",node,"\n",sep = "")
  df=workbook_list[node][[1]]
  link_props_pos=grep(pattern = "\\.", x = colnames(df))
  link_props=colnames(df)[link_props_pos]
  
  if (length(link_props)>1){
    for (row in 1:dim(df)[1]){
      num_of_links=length(grep(pattern = TRUE, x = !is.na(df[row,link_props_pos])))
      if (num_of_links>1){
        cat("\tWARNING: For the node, ", node,", there are multiple links on row: ",row+1,"\n\t\tWhile multiple links can occur, they are often not needed or best practice.\n", sep="")
      }
    }
  }
  
  #for each linking value check to make sure there are values
  for (link_prop in link_props){
    link_values=unique(df[link_prop][[1]])
    link_values=link_values[!is.na(link_values)]
    
    #if there are values, then check values in the linking node
    if (length(link_values)>0){
      linking_node= stri_split_fixed(str = link_prop,pattern = ".",n = 2)[[1]][1]
      linking_prop=stri_split_fixed(str = link_prop,pattern = ".",n = 2)[[1]][2]
      df_link=workbook_list[linking_node][[1]]
      linking_values=unique(df_link[linking_prop][[1]])
      matching_links= link_values %in% linking_values
      
      #if not all the values match, determine the mismatched values
      if (!all(matching_links)){
        mis_match_value=grep(pattern = FALSE, x = matching_links)
        
        #for each mismatched value, throw and error.
        for (mis_match in mis_match_value){
          mis_match_text=link_values[mis_match]
          cat("\tERROR: For the node, ",node,", the following linking property, ", link_prop,", has a value that is not found in the parent node: ", mis_match_text,"\n",sep = "")
        }
      }else{
        cat("\tPASS: The links for the node, ", node,", have corresponding values in the parent node, ",linking_node,".\n", sep = "")
      }
    }
  }
}


#################
#
# Stop write out
#
#################

#Stop write out to file and display "done message" on command line.
sink()

cat(paste("\n\nProcess Complete.\n\nThe output file can be found here: ",path,"\n\n",sep = "")) 
