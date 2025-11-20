# Gaussian Mixture Model (GMM) Analysis of Audiogram Data

## Overview
This repository contains a full analytic workflow for characterising audiometric hearing-loss phenotypes using Gaussian Mixture Modelling (GMM). Building upon the work of Parthasarathy et al., this project applies a comparable modelling framework to a large United Kingdom hearing-health population and assesses the replicability, robustness, and clinical relevance of the resulting clusters. The analysis examines whether the GMM-derived phenotypes previously described in the literature generalise to a large independent cohort and evaluates their stability under sampling and modelling variability.

The workflow is divided into two components. A SQL script is used to extract and preprocess the raw audiogram data, ensuring appropriate data cleaning, demographic merging, and patient-level aggregation. A Jupyter notebook then performs the full statistical analysis, including model fitting, cluster interpretation, clinical phenotype mapping, and replication testing.

## SQL Preprocessing

The SQL file (`Auditbase_audiograms.sql`) prepares the audiology dataset as imported from Auditbase for modelling by:

- Selecting AC and BC threshold data from the raw tables.  
- Retrieving and linking patient demographics (date of birth, sex) across current and historic EHR systems.  
- Removing duplicate audiograms and restricting to one audiogram per patient per date.  
- Excluding records with impossible threshold values (< −10 dB, > 120 dB, or not in 5-dB steps).  
- Retaining audiograms with complete AC data across all six frequencies of interest.  
- Identifying whether BC is available for each ear and classifying audiograms as AC-only or AC+BC.  
- Computing air–bone gaps and classifying ears as SNHL, CHL, or incomplete based on ABG patterns.  
- Combining all tables containing SNHL cases into a single unified SNHL dataset.  
- Filtering to retain adults (≥ 18 years).  
- Restricting the final dataset to adults with bilateral SNHL and complete AC thresholds in both ears.  

The processed dataset is subsequently imported into Python for analysis.

## GMM Audiogram Modelling

The notebook (`GMM_audiogram_analysis.ipynb`) implements the full modelling pipeline.

### Data preparation
- Load the SQL-processed audiometric dataset.  
- Select a single audiogram per patient (randomly chosen when multiple are available).  

### Dataset summary
- Compute population-level demographic summaries (e.g. age and sex distributions).  
- Summarise the distribution of audiometric thresholds across frequencies.  

### Feature selection
- Use six threshold frequencies as model features:  
  - 250 Hz, 500 Hz, 1 kHz, 2 kHz, 4 kHz, and 8 kHz.  

### Model selection
- Fit a range of GMMs (e.g. 2–15 components) across multiple random initialisations.  
- Use AIC and BIC, with confidence intervals, to select the optimal number of clusters.  
- Identify a final cluster solution that balances model fit and interpretability (e.g. a 9-cluster model).  

### Cluster characterisation
For each cluster, the notebook derives:

- Mean audiometric configuration.  
- Interquartile range (IQR) of thresholds.  
- Cluster prevalence within the dataset.  
- Demographic profiles (age and sex) associated with each cluster.  

These results provide a set of physiologically interpretable audiometric phenotypes.

### Mapping known clinical phenotypes
- Define clinically recognised patterns using established audiological criteria, including:  
  - Noise-induced hearing-loss patterns.  
  - Reverse-sloping low-frequency loss consistent with Ménière’s disease.  
- Quantify how these clinically defined patterns map onto the GMM-derived clusters.  

### Bilateral consistency analysis
- Compare cluster allocations for left and right ears within individuals.  
- Summarise within-patient agreement in cluster assignment.  
- Visualise bilateral correspondence using probability/heatmap-style plots.  

### Replication and robustness analyses
To assess stability of the cluster solution, the notebook performs:

- **Bootstrap resampling (e.g. n = 1000):**  
  - Refit GMMs to bootstrap samples.  
  - Use Jaccard similarity to quantify agreement in cluster membership with the original model.  

- **Multiple model initialisations:**  
  - Re-run the chosen GMM model across multiple random seeds.  
  - Assess how consistently individuals are assigned to the same clusters.  

- **Dataset-size sensitivity analysis:**  
  - Fit GMMs to random subsets (e.g. 10–90% of the full dataset).  
  - Evaluate how cluster stability changes as a function of sample size.  

### Outputs
The notebook generates and saves:

- Audiogram cluster phenotype plots.  
- AIC/BIC model-selection curves.  
- Demographic profiles by cluster.  
- Clinical phenotype mapping outputs.  
- Bilateral ear correspondence heatmaps.  
- Jaccard similarity results for bootstrap, model initialisation, and subset-size analyses.  

## License
This project is licensed under the **MIT License**.
