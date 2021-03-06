#!/bin/env/Rscript
#
# Integrated genomics approach to detect allelic imbalances in multiple myeloma
#
# Agnelli et al. (2009)
#
library(GEOquery)
library(tidyverse)
library(arrow)
source("util/eset.R")

# GEO accession
accession <- 'GSE13591'

# directory to store raw and processed data
raw_data_dir <- file.path('/data/raw', accession)
processed_data_dir <- sub('raw', 'clean', raw_data_dir)

# create output directories if they don't already exist
for (dir_ in c(raw_data_dir, processed_data_dir)) {
  if (!dir.exists(dir_)) {
      dir.create(dir_, recursive = TRUE)
  }
}

# download GEO data;
# result is a list with a single entry containing an ExpressionSet instance
eset <- getGEO(accession, destdir = raw_data_dir)[[1]]

# size factor normalization
exprs(eset) <- sweep(exprs(eset), 2, colSums(exprs(eset)), '/') * 1E6

# get relevant sample metadata
# "treatment_protocol_ch1" is another alias for death;
# "grow_protocol_ch1" is an alias for relapse;
sample_metadata <- pData(eset) %>%
  select(geo_accession, platform_id, sample_type = `sample type:ch1`)

sample_metadata$mm_stage <- sample_metadata$sample_type
sample_metadata$mm_stage[startsWith(sample_metadata$mm_stage, 'TC')] <- 'MM'
sample_metadata$mm_stage[startsWith(sample_metadata$mm_stage, 'N')] <- 'Healthy'

sample_metadata$disease_stage <- sample_metadata$mm_stage

#table(sample_metadata$sample_type)
# 
# MGUS    N  PCL  TC1  TC2  TC3  TC4  TC5 
#   11    5    9   29   25   49   24    6 

#table(sample_metadata$disease_stage)
# 
# Healthy    MGUS      MM     PCL 
#       5      11     133       9 

# drop PCL samples
mask <- sample_metadata$mm_stage  != 'PCL'

sample_metadata <- sample_metadata[mask, ]
eset <- eset[, mask]

# add cell type
sample_metadata$cell_type <- 'CD138+'

sample_metadata$platform_type <- 'Microarray'

# extract gene expression data
expr_dat <- process_eset(eset)

if (!all(colnames(expr_dat)[-1] == sample_metadata$geo_accession)) {
  stop("Sample ID mismatch!")
}

# average multi-mapped probes
expr_dat_nr <- expr_dat %>%
  group_by(symbol) %>%
  summarize_all(median)

# determine filenames to use for outputs and save to disk
expr_outfile <- sprintf('%s_gene_expr.feather', accession)
expr_nr_outfile <- sprintf('%s_gene_expr_nr.feather', accession)
mdat_outfile <- sprintf('%s_sample_metadata.tsv', accession)

print("Final dimensions:")
print(paste0("- Num rows: ", nrow(expr_dat_nr)))
print(paste0("- Num cols: ", ncol(expr_dat_nr)))

# store cleaned expression data and metadata
write_feather(expr_dat, file.path(processed_data_dir, expr_outfile))
write_feather(expr_dat_nr, file.path(processed_data_dir, expr_nr_outfile))
write_tsv(sample_metadata, file.path(processed_data_dir, mdat_outfile))
