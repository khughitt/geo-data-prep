#!/bin/env/Rscript
#
# Gene Expression of Bone Marrow Plasma Cells from Healthy Donors (N=22), MGUS (N=44),
# and Smoldering Myeloma (N=12)
#
# Zhan et al. (2006)
#
library(GEOquery)
library(tidyverse)
library(arrow)
source("util/eset.R")

# GEO accession
accession <- 'GSE5900'

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
eset <- getGEO(accession, destdir = raw_data_dir)[[1]]

# size factor normalization
exprs(eset) <- sweep(exprs(eset), 2, colSums(exprs(eset)), '/') * 1E6

sample_metadata <- pData(eset) %>%
  select(geo_accession, platform_id)

group <- pData(eset)$source_name_ch1

sample_metadata$mm_stage <- rep('Healthy', nrow(sample_metadata))
sample_metadata$mm_stage[grepl('MGUS', group)] <- 'MGUS'
sample_metadata$mm_stage[grepl('smoldering', group)] <- 'SMM'

sample_metadata$disease_stage <- sample_metadata$mm_stage

# add cell type
sample_metadata$cell_type <- 'CD138+'

sample_metadata$platform_type <- 'Microarray'

table(sample_metadata$mm_stage)
#
# Healthy    MGUS     SMM
#      22      44      12
#

# extract gene expression data
expr_dat <- process_eset(eset)

if (!all(colnames(expr_dat)[-1] == sample_metadata$geo_accession)) {
  stop("Sample ID mismatch!")
}

# create a version of gene expression data with a single entry per gene, including
# only entries which could be mapped to a known gene symbol
expr_dat_nr <- expr_dat %>%
  group_by(symbol) %>%
  summarize_all(median)

# determine filenames to use for outputs and save to disk
expr_outfile <- sprintf('%s_gene_expr.feather', accession)
expr_outfile_nr <- sprintf('%s_gene_expr_nr.feather', accession)
mdat_outfile <- sprintf('%s_sample_metadata.tsv', accession)

print("Final dimensions:")
print(paste0("- Num rows: ", nrow(expr_dat_nr)))
print(paste0("- Num cols: ", ncol(expr_dat_nr)))

# store cleaned expression data and metadata
write_feather(expr_dat, file.path(processed_data_dir, expr_outfile))
write_feather(expr_dat_nr, file.path(processed_data_dir, expr_outfile_nr))
write_tsv(sample_metadata, file.path(processed_data_dir, mdat_outfile))
