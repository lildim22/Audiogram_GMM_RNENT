# Gaussian Mixture Model (GMM) Analysis of Audiogram Data

## Overview
This repository contains a full analytic workflow for characterising audiometric hearing-loss phenotypes using Gaussian Mixture Modelling (GMM). Building upon the work of Parthasarathy et al., this project applies a comparable modelling framework to a large United Kingdom hearing-health population and assesses the replicability, robustness, and clinical relevance of the resulting clusters. The analysis examines whether the GMM-derived phenotypes previously described in the literature generalise to a large independent cohort and evaluates their stability under sampling and modelling variability.

The workflow is divided into two components. A SQL script is used to extract and preprocess the raw audiogram data, ensuring appropriate data cleaning, demographic merging, and patient-level aggregation. A Jupyter notebook then performs the full statistical analysis, including model fitting, cluster interpretation, clinical phenotype mapping, and replication testing.

## SQL Preprocessing
The SQL file (`data_preprocessing.sql`) prepares the audiology dataset as imported from Auditbase for modelling by:
- Removing duplicate records
- Performing data linkage with eletronic health record databases to complete sex and age fields and filtering patients with plausible values for these fields.
- Cleaning invalid or implausible threshold values
- Filtering records that show sensorineural hearing loss
- Filtering records to only include adult patients. 

The processed dataset is subsequently imported into Python for analysis.

## GMM Audiogram Modelling
The notebook (`GMM_audiogram_analysis.ipynb`) implements the comprehensive modelling pipeline:

### Data preparation
- Loading SQL-processed audiometric data  
- Selecting a single audiogram per patient - chosen at random

### Dataset summary
- Computing population-level demographic summaries  

### Feature selection
Six threshold frequencies are used as model features: 250 Hz, 500 Hz, 1 kHz, 2 kHz, 4 kHz, and 8 kHz.

### Model selection
A range of GMMs (2–15 components) is fitted across 21 random initialisations. AIC and BIC, along with their confidence intervals, guide selection of the optimal number of clusters. A 9-cluster solution is identified as the best overall model for this dataset.

### Cluster characterisation
For each cluster, the notebook derives:
- Mean audiometric configuration  
- Interquartile range of thresholds  
- Prevalence within the dataset  
- Corresponding demographic distributions (age and sex)  

These results provide a physiologically interpretable set of audiometric phenotypes.

### Mapping known clinical phenotypes
Two predefined clinically recognised patterns are identified using established audiological criteria:
- Noise-induced hearing-loss pattern  
- Reverse-sloping low-frequency loss consistent with Meniere’s disease  

The analysis determines how patients exhibiting these patterns are distributed among the GMM-derived clusters.

### Bilateral consistency analysis
Cluster allocations for left and right ears are compared to evaluate within-patient agreement. A probability heatmap visualises the correspondence between ear-pair cluster assignments.

## Replication and Robustness Analyses
To evaluate the stability of the cluster solutions, the notebook includes three complementary replication analyses:

1. **Bootstrap resampling (n = 1000):**  
   GMMs are refitted to resampled datasets, and Jaccard similarity coefficients quantify the similarity of cluster membership between the bootstrap models and the original model.

2. **Multiple model initialisations:**  
   The GMM is re-run across 20 additional random seeds to examine sensitivity to model initialisation. Cluster assignments remain consistently reproducible across runs.

3. **Dataset-size sensitivity analysis:**  
   GMMs are fitted to random subsets representing 10–90% of the original dataset. The mean Jaccard similarity across subsets demonstrates how cluster stability varies with sample size.


## Outputs
The notebook generates:
- Audiogram cluster phenotype plots  
- AIC/BIC model-selection curves  
- Demographic profiles by cluster  
- Clinical phenotype mapping outputs  
- Bilateral ear correspondence heatmap  
- Jaccard similarity analyses for bootstrap, model initialisation, and dataset-size sensitivity  

All visual outputs are saved in the results directory.

## License
This project is licensed under the **MIT License**:
