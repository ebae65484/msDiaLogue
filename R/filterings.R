##
## msDiaLogue: Analysis + Visuals for Data Indep. Aquisition Mass Spectrometry Data
## Copyright (C) 2025  Shiying Xiao, Timothy Moore and Charles Watt
## Shiying Xiao <shiying.xiao@uconn.edu>
##
## This file is part of the R package msDiaLogue.
##
## The R package msDiaLogue is free software: You can redistribute it and/or
## modify it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or any later
## version (at your option). See the GNU General Public License at
## <https://www.gnu.org/licenses/> for details.
##
## The R package msDiaLogue is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
##

#################################
#### Code for data filtering ####
#################################
#'
#' Filtering of raw data signals
#' 
#' @description
#' Apply a series of filtering steps to the data set.
#' 
#' @param dataSet The 2d data set of experimental values.
#' 
#' @param filterNaN A boolean (default = TRUE) specifying whether proteins with NaN should
#' be removed from the data set.
#' 
#' @param filterUnique An integer (default = 2) specifying whether proteins with less than
#' the default number of unique peptides should be removed from the data set.
#' 
#' @param replaceBlank A boolean (default = TRUE) specifying whether proteins without names
#' should be be named by their accession numbers.
#' 
#' @param saveRm A boolean (default = TRUE) specifying whether to save removed data to
#' current working directory.
#' 
#' @details
#' All forms of filtering are recommended for most use cases.
#' 
#' @import dplyr
#' @importFrom utils write.csv
#'  
#' @returns A filtered 2d dataframe.
#' 
#' @autoglobal
#' 
#' @noRd

preProcessFiltering <- function(dataSet,
                                filterNaN = TRUE,
                                filterUnique = 2,
                                replaceBlank = TRUE,
                                saveRm = TRUE) {
  
  filteredData <- dataSet
  
  if (filterNaN) {
    
    if (saveRm) {
      
      ## create a dataframe of the removed data
      removedData <- filteredData %>% filter(is.nan(PG.Quantity))
      
      ## save removed data to current working directory
      write.csv(removedData, file = "preprocess_Filtered_Out_NaN.csv", row.names = FALSE)
    }
    
    ## filter out the proteins that have no recorded value
    filteredData <- filteredData %>% filter(!is.nan(PG.Quantity))
    
  }
  
  if (filterUnique >= 2) {
    
    if (saveRm) {
      
      ## create a dataframe of the removed data
      removedData <- filteredData %>%
        filter(PG.NrOfStrippedSequencesIdentified < filterUnique)
      
      ## save removed data to current working directory
      write.csv(removedData, file = "preprocess_Filtered_Out_Unique.csv", row.names = FALSE)
    }
    
    ## filter out proteins that have only 1 unique peptide
    filteredData <- filteredData %>%
      filter(PG.NrOfStrippedSequencesIdentified >= filterUnique)
    
  }

  if (replaceBlank) {
    
    ## replace blank protein name entries with their accession numbers
    filteredData <- filteredData %>%
      mutate(PG.ProteinNames =
               replace(PG.ProteinNames, PG.ProteinNames == "", PG.ProteinAccessions))
  }
  
  ## return the filtered data
  return(filteredData)
}


##----------------------------------------------------------------------------------------
#' 
#' Filtering proteins or contaminants
#' 
#' @description
#' Apply a series of filtering steps to the data set.
#' 
#' @param dataSet The 2d data set of experimental values.
#' 
#' @param listName A character vector of proteins to select or remove.
#' 
#' @param regexName A character vector specifying proteins for regular expression pattern
#' matching to select or remove.
#' 
#' @param removeList A boolean (default = TRUE) specifying whether the list of proteins
#' should be removed or selected.
#' \itemize{
#' \item TRUE: Remove the list of proteins from the data set. 
#' \item FALSE: Remove all proteins not in the list from the data set.
#' }
#' 
#' @param saveRm A boolean (default = TRUE) specifying whether to save removed data to
#' current working directory. This option only works when \code{removeList = TRUE}.
#' 
#' @details
#' If both \code{listName} and \code{regexName} are provided, the protein names selected
#' or removed will be the union of those specified in \code{listName} and those matching
#' the regex pattern in \code{regexName}.
#' 
#' @import dplyr
#' @importFrom utils write.csv
#' 
#' @returns A filtered 2d dataframe.
#' 
#' @autoglobal
#' 
#' @export

filterOutIn <- function(dataSet,
                        listName = c(),
                        regexName = c(),
                        removeList = TRUE,
                        saveRm = TRUE) {
  
  ## relabel the data frame
  filteredData <- dataSet %>%
    select(-c(R.Condition, R.Replicate))
  
  ## only list filter if listName is present
  if (length(listName) != 0) {
    listIndex <- which(colnames(filteredData) %in% listName)
  } else {
    listIndex <- NULL
  }
  
  ## only regex filter if regexName is present
  if (length(regexName) != 0) {
    regexIndex <- grep(paste(regexName, collapse = "|"), colnames(filteredData))
  } else {
    regexIndex <- NULL
  }
  
  ## combine protein names from list and regex filters
  unionName <- colnames(filteredData)[sort(union(listIndex, regexIndex))]
  
  ## create a dataframe of the data of proteins
  unionData <- dataSet %>%
    select(any_of(c("R.Condition", "R.Replicate", unionName)))
  
  ## if contaminants are being removed
  if (removeList == TRUE) {
    
    if (saveRm) {
      
      ## save removed data to current working directory
      write.csv(unionData, file = "filtered_out_data.csv", row.names = FALSE)
    }
    
    ## remove all of the contaminants if they are present
    filteredData <- dataSet %>% select(-any_of(unionName))
    
    ## if certain proteins are being selected
  } else if (removeList == FALSE) {
    
    ## select only proteins of interest
    filteredData <- unionData
  }
  
  ## return the filtered data 
  return(filteredData)
}


##----------------------------------------------------------------------------------------
#'
#' Filter proteins by gene, accession or description
#' 
#' @description
#' Filter the preprocessed dataset by gene, accession, or description.
#' 
#' @param dataSet The 2d data set of experimental values.
#' 
#' @param proteinInformation The name of the .csv file containing protein information data
#' (including the path to the file, if needed). The file should include the following
#' columns:
#' \itemize{
#' \item For Spectronaut: "PG.Genes", "PG.ProteinAccessions", "PG.ProteinDescriptions",
#' and "PG.ProteinNames".
#' \item For Scaffold: "ProteinDescriptions", "AccessionNumber", and "AlternateID".
#' }
#' This file is automatically generated by the function
#' \code{\link[msDiaLogue]{preprocessing}} or
#' \code{\link[msDiaLogue]{preprocessing_scaffold}}.
#' 
#' @param text A character vector of text used as the key for selecting or removing.
#' 
#' @param by A character string specifying the information to which the \code{text} filter
#' is applied, with allowable options:
#' \itemize{
#' \item For Spectronaut: "PG.Genes", "PG.ProteinAccessions", "PG.ProteinDescriptions",
#' and "PG.ProteinNames".
#' \item For Scaffold: "ProteinDescriptions", "AccessionNumber", and "AlternateID".
#' }
#' 
#' @param removeList A boolean (default = TRUE) specifying whether the list of proteins
#' should be removed or selected.
#' \itemize{
#' \item TRUE: Remove the list of proteins from the data set. 
#' \item FALSE: Remove all proteins not in the list from the data set.
#' }
#' 
#' @param saveRm A boolean (default = TRUE) specifying whether to save removed data to
#' current working directory. This option only works when \code{removeList = TRUE}.
#' 
#' @details
#' The function is an extension of the function \code{\link[msDiaLogue]{preprocessing}} or
#' \code{\link[msDiaLogue]{preprocessing_scaffold}} that allows for filtering proteins
#' based on additional information.
#' 
#' @import dplyr
#' @importFrom utils read.csv write.csv
#' 
#' @returns A filtered 2d dataframe.
#' 
#' @autoglobal
#' 
#' @export

filterProtein <- function(dataSet,
                          proteinInformation = "preprocess_protein_information.csv",
                          text = c(),
                          by = c("PG.Genes", "PG.ProteinAccessions",
                                 "PG.ProteinDescriptions", "PG.ProteinNames",
                                 "ProteinDescriptions", "AccessionNumber", "AlternateID"),
                          removeList = TRUE,
                          saveRm = TRUE) {
  
  proteinInformation <- read.csv(proteinInformation)
  
  ## relabel the data frame
  filteredData <- dataSet %>%
    select(-c(R.Condition, R.Replicate))
  
  index <- grep(paste(text, collapse = "|"), proteinInformation[[by]])
  
  if (by %in% c("PG.Genes", "PG.ProteinAccessions",
                "PG.ProteinDescriptions", "PG.ProteinNames")) {
    proteinName <- proteinInformation[index,]$PG.ProteinNames
  } else {
    proteinName <- proteinInformation[index,]$AccessionNumber
  }
  
  result <- dataSet %>%
    select(any_of(c("R.Condition", "R.Replicate", proteinName)))
  
  ## if contaminants are being removed
  if (removeList == TRUE) {
    
    if (saveRm) {
      
      ## save removed data to current working directory
      write.csv(result, file = "filtered_protein_data.csv", row.names = FALSE)
    }
    
    ## remove all of the contaminants if they are present
    filteredData <- dataSet %>% select(-any_of(proteinName))
    
    ## if certain proteins are being selected
  } else if (removeList == FALSE) {
    
    ## select only proteins of interest
    filteredData <- result
  }
  
  ## return the filtered data 
  return(filteredData)
}


##----------------------------------------------------------------------------------------
#' 
#' Filtering NA's post-imputation
#' 
#' @description 
#' Remove proteins with NA values.
#' 
#' @param dataSet The 2d data set of experimental values.
#' 
#' @param saveRm A boolean (default = TRUE) specifying whether to save removed data to
#' current working directory.
#' 
#' @details 
#' If proteins that do not meet the imputation requirement are removed, a .csv file is
#' created with the removed data.
#' 
#' @import dplyr
#' @importFrom utils write.csv
#' 
#' @returns A filtered 2d dataframe.
#' 
#' @autoglobal
#' 
#' @export

filterNA <- function(dataSet, saveRm = TRUE) {
  
  if (saveRm) {
    
    ## create a dataframe of the removed data
    removedData <- bind_cols(select(dataSet, c(R.Condition, R.Replicate)),
                             select_if(dataSet, ~any(is.na(.))))
    
    ## save removed data to current working directory
    write.csv(removedData, file = "filtered_NA_data.csv", row.names = FALSE)
  }
  
  ## remove all of the contaminants if they are present
  filteredData <- dataSet %>% select_if(~!any(is.na(.)))
  
  ## return the filtered data 
  return(filteredData)
}

