#!/bin/env/Rscript
#
# Expression data from multiple myeloma cells treated with arsenic
#
# Matulis et al. (2009)
#
library(GEOquery)
library(tidyverse)
library(arrow)
source("util/eset.R")

# GEO accession
accession <- 'GSE14519'

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

# size-factor normalization
exprs(eset) <- sweep(exprs(eset), 2, colSums(exprs(eset)), '/') * 1E6

# get relevant sample metadata
# "treatment_protocol_ch1" is another alias for death;
# "grow_protocol_ch1" is an alias for relapse;
sample_metadata <- pData(eset) %>%
  select(geo_accession, platform_id, title)

# treatment status
sample_metadata$treatment <- 'Untreated'
sample_metadata$treatment[grepl('DAR 6', sample_metadata$title)] <- 'DAR (6 hrs)'
sample_metadata$treatment[grepl('DAR 24', sample_metadata$title)] <- 'DAR (24 hrs)'
sample_metadata$treatment[grepl('ATO 6', sample_metadata$title)] <- 'ATO (6 hrs)'
sample_metadata$treatment[grepl('ATO 24', sample_metadata$title)] <- 'ATO (24 hrs)'
sample_metadata$treatment[grepl('ATO 48', sample_metadata$title)] <- 'ATO (48 hrs)'

# cell line
sample_metadata$cell_type <- 'U266'
sample_metadata$cell_type[grepl('MM.1s', sample_metadata$title)] <- 'MM.1s'
sample_metadata$cell_type[grepl('KMS11', sample_metadata$title)] <- 'KMS11'
sample_metadata$cell_type[grepl('8226', sample_metadata$title)] <- '8226'

# disease stage
sample_metadata$disease_stage <- 'MM'

# platform type
sample_metadata$platform_type <- 'Microarray'

# get expression data and add gene symbol column
# gene_symbols <- gsub('///', ' // ', fData(eset)$`Gene symbol`)

# expr_dat <- exprs(eset) %>%
#   as.data.frame() %>%
#   add_column(symbol = gene_symbols, .before = 1) %>%
#   filter(symbol != '')

# extract gene expression data
expr_dat <- process_eset(eset)

if (!all(colnames(expr_dat)[-1] == sample_metadata$geo_accession)) {
  stop("Sample ID mismatch!")
}

# only entries which could be mapped to a known gene symbol
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
