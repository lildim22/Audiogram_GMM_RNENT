#Import Packages and requred libraries
from sklearn.mixture import GaussianMixture
import seaborn as sns
import matplotlib.pyplot as plt
import numpy as np
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
from scipy.stats import multivariate_normal
from scipy.stats import norm
import warnings
import random
from sklearn import mixture
import math, statistics 
import scipy.stats as stats


###Import datset from postgres. At this stage there are multiple audiograms per patient

data_2ears = pd.read_sql_query('select * from schema_name;', cnx)

###Select a single audiogram per patient. Set random seed so this sampling is reproducible 

random_seed = 42

data_gmm_2ears = data_2ears.groupby('patient_id').apply(lambda x: x.sample(1, random_state=random_seed))

###generate a random but reproducible id
import random

random_seed = 42
random.seed(random_seed)

data_gmm_2ears['rid'] = random.sample(range(0, 54927), data_gmm_2ears.shape[0]) #54927 is the number of patients in the dataset after selecting 1 audiogram per patient

# Check the number of unique values to ensure each rid is unique
unique_count = data_gmm_2ears.rid.nunique()
print(unique_count)


###Earliest and latest date of the hearing test 

data_gmm_2ears.investdate.min() #1981,5,15
data_gmm_2ears.investdate.max() #2021,2,10

###ages of the patients in buckets

data_gmm_2ears
condition_age = [
     (data_gmm_2ears['age'] <= 29),
    (data_gmm_2ears['age'] > 29) & (data_gmm_2ears['age'] <= 39),
     (data_gmm_2ears['age'] > 39) & (data_gmm_2ears['age'] <= 49),
     (data_gmm_2ears['age'] > 49) & (data_gmm_2ears['age'] <= 59),
     (data_gmm_2ears['age'] > 59) & (data_gmm_2ears['age'] <= 69),
     (data_gmm_2ears['age'] > 69) & (data_gmm_2ears['age'] <= 79),
     (data_gmm_2ears['age'] > 79) & (data_gmm_2ears['age'] <= 89),
     (data_gmm_2ears['age'] > 89)
    ]


values = ['18-29', '30-39', '40-49', '50-59', '60-69', '70-79', '80-89', '>90']


### Alter dataframe so each ear per patient on own row 

#Identify left ears

data_gmm_2ears_l = data_gmm_2ears[['sex','age','age_range', 'rid', 'ac_l250', 'ac_l500', 'ac_l1000', 'ac_l2000', 'ac_l4000',
                                  'ac_l8000']].copy()

data_gmm_2ears_l = data_gmm_2ears_l.rename(columns = {'ac_l250': 'ac_250', 
                                   'ac_l500': 'ac_500',
                                  'ac_l1000': 'ac_1000',
                                  'ac_l2000': 'ac_2000',
                                  'ac_l4000' : 'ac_4000',
                                  'ac_l8000': 'ac_8000'})
data_gmm_2ears_l['side'] = 'left'

#Identify right ears

data_gmm_2ears_r = data_gmm_2ears[['sex','age','age_range', 'rid', 'ac_r250', 'ac_r500', 'ac_r1000', 'ac_r2000', 'ac_r4000',
                                  'ac_r8000']].copy()

data_gmm_2ears_r = data_gmm_2ears_r.rename(columns = {'ac_r250': 'ac_250',
                                   'ac_r500': 'ac_500',
                                  'ac_r1000': 'ac_1000',
                                  'ac_r2000': 'ac_2000',
                                  'ac_r4000' : 'ac_4000',
                                  'ac_r8000': 'ac_8000'})

data_gmm_2ears_r['side'] = 'right' 

#Concat into single dataframe

data_gmm_2ears_bl = pd.concat([data_gmm_2ears_l, data_gmm_2ears_r])
data_gmm_2ears_bl

df_both_ears = df_gmm_2ears.set_index('rid')

### Look at characteristics of the final dataset

#look at only records with unique rid so only unique patient details considered

duplicated_indices = df_both_ears.index.duplicated(keep='first')

# Filter the DataFrame to keep only rows with unique indices
unique_indices_df = df_both_ears[~duplicated_indices]

#age: mean and sd across all patients

print(unique_indices_df.age.mean())
print(unique_indices_df.age.std())

#proportion over 50 

total_count = len(unique_indices_df)
over_50_count = len(unique_indices_df[unique_indices_df['age'] > 50])

proportion_over_50 = over_50_count / total_count


print(f"Proportion of individuals over the age of 50: {proportion_over_50:.2%}")


#sex counts 
sex_counts = unique_indices_df['sex'].value_counts()

# Calculate proportions per sex
total_count = len(unique_indices_df)
proportion_male = sex_counts.get('M', 0) / total_count
proportion_female = sex_counts.get('F', 0) / total_count

print(f"Proportion of men: {proportion_male:.2%}")
print(f"Proportion of women: {proportion_female:.2%}")

#proportions across age range

import matplotlib.pyplot as plt

# Calculate overall proportions by age range
proportions = unique_indices_df.groupby('age_range').size() / len(unique_indices_df)

# Plot the bar chart with 'age_range' on x and overall proportion on y
fig, ax1 = plt.subplots(figsize=(10, 6))
ax1.bar(proportions.index, proportions, color='#4169E1', label='Overall Proportion')
ax1.set_xlabel('Age Range')
ax1.set_ylabel('Overall Proportion', color='#4169E1')  # Set the color here
ax1.tick_params(axis='y', labelcolor='#4169E1')  # Set the color here

# Create a secondary y-axis for the line graph to show proportion male per age range 
ax2 = ax1.twinx()
proportion_male = unique_indices_df[unique_indices_df['sex'] == 'M'].groupby('age_range').size() / unique_indices_df.groupby('age_range').size()
ax2.plot(proportion_male.index, proportion_male, marker='o', linestyle='-', color='red', label='Proportion Male')
ax2.set_ylabel('Proportion Male', color='red')
ax2.tick_params(axis='y', labelcolor='red')

# Add labels and legend
fig.suptitle('Proportion by Age Range and Sex')
fig.tight_layout()
fig.legend(loc='upper left', bbox_to_anchor=(0.8, 0.85))

# Save the plot as a JPEG file
plt.savefig('proportion_age_sex.jpg', format='jpeg', dpi=300)

plt.show()


### Prepare dataset for GMM

# only include columns with the features (hearing thresohlds for the 6 test frequencies)

gmm_thresholds_bl = df_both_ears.iloc[:,3:9]
gmm_thresholds_bl


### Iterate through different cluster numbers and caclulate BIC scores to select optimal cluster number 
delete


# Function to normalize data - MEE paper compute normalised BIC rather than raw BIC. 
def normalize_data(data):
    return (data - np.min(data)) / (np.max(data) - np.min(data))

# Step 1: Define Random Seeds and Cluster Range
rand = [1, 10, 20, 30, 40, 50, 60000, 70, 80, 9333330, 100, 110, 120, 13044, 140, 150, 160, 170, 18024, 190, 200]  # 21 random seeds
n_comp = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]  # Range of clusters

# Track time
start_time = time.time()

# Step 2: Fit Gaussian Mixture Model and Compute BIC and AIC
scores = []  # Store both BIC and AIC

# Create a progress bar with tqdm
total_iterations = len(n_comp) * len(rand)
with tqdm(total=total_iterations, desc="Processing Clusters", unit="iteration") as pbar:
    for i, n in enumerate(n_comp):
        for j, r in enumerate(rand):
            gmm = GaussianMixture(n_components=n, covariance_type='full', random_state=r, reg_covar=0.01)
            gmm.fit(gmm_thresholds_bl)

            bic = gmm.bic(gmm_thresholds_bl)  # Compute BIC
            aic = gmm.aic(gmm_thresholds_bl)  # Compute AIC

            scores.append({'seed': r, 'k': n, 'bic': bic, 'aic': aic})  # Store both scores

            # Update progress bar
            pbar.update(1)

            # Optional: Print progress every 10 iterations
            if (i * len(rand) + j) % 10 == 0:
                elapsed_time = time.time() - start_time
                print(f"Iteration {i * len(rand) + j}/{total_iterations} completed. Elapsed time: {elapsed_time:.2f} seconds.")

# Step 3: Convert to DataFrame
df_scores = pd.DataFrame(scores)

# Step 4: Normalize BIC and AIC
df_scores['normalized_bic'] = normalize_data(df_scores['bic'])
df_scores['normalized_aic'] = normalize_data(df_scores['aic'])

# Step 5: Calculate Mean and Standard Deviation for Each Cluster Size
cluster_stats = df_scores.groupby('k')[['normalized_bic', 'normalized_aic']].agg(['mean', 'std']).reset_index()

# Track end time
end_time = time.time()
execution_time = end_time - start_time

# Display Results
print("\nDataFrame with BIC and AIC scores:")
print(df_scores)

print("\nDataFrame with cluster statistics (mean & std):")
print(cluster_stats)

print(f"\nTotal execution time: {execution_time:.2f} seconds.")

#save these outputs to csv so not so slow to run each time .
df_scores.to_csv('df_scores_03_02.csv')

cluster_stats.to_csv('cluster_stats_03_02.csv')


### Plot AIC and BIC elbow plots as function of cluster number 


# Group by 'k' and calculate mean and standard deviation for each group (BIC & AIC)
grouped_bic = df_scores.groupby('k')['normalized_bic']
grouped_aic = df_scores.groupby('k')['normalized_aic']

# Compute mean and standard deviation for each cluster (k)
means_bic = grouped_bic.mean()
std_devs_bic = grouped_bic.std()

means_aic = grouped_aic.mean()
std_devs_aic = grouped_aic.std()

# Number of observations in each group
n_bic = grouped_bic.size()
n_aic = grouped_aic.size()

# Degrees of freedom for each group (n - 1)
df_bic = n_bic - 1
df_aic = n_aic - 1

# Calculate standard error
standard_errors_bic = std_devs_bic / (n_bic ** 0.5)
standard_errors_aic = std_devs_aic / (n_aic ** 0.5)

# Compute t-value for 95% confidence interval
t_value_bic = stats.t.ppf(0.975, df_bic)
t_value_aic = stats.t.ppf(0.975, df_aic)

# Compute margin of error for confidence interval
margin_of_error_bic = t_value_bic * standard_errors_bic
margin_of_error_aic = t_value_aic * standard_errors_aic

# Compute confidence intervals
confidence_intervals_bic = pd.DataFrame({
    'lower_bound': means_bic - margin_of_error_bic,
    'upper_bound': means_bic + margin_of_error_bic
})

confidence_intervals_aic = pd.DataFrame({
    'lower_bound': means_aic - margin_of_error_aic,
    'upper_bound': means_aic + margin_of_error_aic
})

# Plot the means with 95% confidence intervals
plt.figure(figsize=(10, 6))
plt.plot(means_bic.index, means_bic, marker='o', label='Mean BIC Score', color='blue')
plt.fill_between(means_bic.index, confidence_intervals_bic['lower_bound'], confidence_intervals_bic['upper_bound'], alpha=0.3, label='95% CI (BIC)', color='skyblue')

plt.plot(means_aic.index, means_aic, marker='o', label='Mean AIC Score', color='red')
plt.fill_between(means_aic.index, confidence_intervals_aic['lower_bound'], confidence_intervals_aic['upper_bound'], alpha=0.3, label='95% CI (AIC)', color='salmon')

plt.xlabel('Number of Clusters (k)')
plt.ylabel('Normalized Score')
plt.title('Mean BIC & AIC Scores per Cluster with 95% Confidence Intervals')
plt.legend()
plt.grid(False)

plt.savefig('elbow_bic_aic.jpg', format='jpeg', dpi=300)
plt.show()

# Display the confidence interval results
print("\nConfidence Intervals for BIC:")
print(confidence_intervals_bic)

print("\nConfidence Intervals for AIC:")
print(confidence_intervals_aic)


###Now lets see the clusters identified by the optimal model of 9 clusters 

info = df_both_ears.iloc[:,3:10] #create a new dataframe for our dataset and clal this info. This includes the rid column

info_copy = info.copy(deep = True) #create deep copy so original not altered

#re-fit our model 

gmm = mixture.GaussianMixture(n_components=9, covariance_type='full', random_state=20, reg_covar=0.01)
gmm_init = gmm.fit(info_copy.drop(['rid'], axis=1))
labels = gmm_init.predict(info_copy.drop(['rid'], axis=1))

info_copy["clusters"] = labels 

#get the mean values per cluster 

cluster1 = gmm.means_[0,:6]
cluster2 = gmm.means_[1,:6]
cluster3 = gmm.means_[2,:6]
cluster4 = gmm.means_[3,:6]
cluster5 = gmm.means_[4,:6]
cluster6 = gmm.means_[5,:6]
cluster7 = gmm.means_[6,:6]
cluster8 = gmm.means_[7,:6]
cluster9 = gmm.means_[8,:6]

#get the mean value of each frequency per cluster 
for i in range(1, 10):
    cluster_name = f'cluster{i}'
    cluster_value = locals()[cluster_name]
    print(f'{cluster_name}: {cluster_value}')
    
#store number of clusters as variable 
num_clusters = gmm.n_components

# Initialize an array to store the number of samples in each cluster
num_samples_per_cluster = np.zeros(num_clusters, dtype=int)

# Count the number of samples in each cluster
for cluster in range(num_clusters):
    num_samples_per_cluster[cluster] = np.sum(labels == cluster)
    
num_samples_per_cluster 


###long-winded code to create audiogram phenotypes 

fig, ((ax1, ax2, ax3, ax4, ax5),(ax6, ax7, ax8, ax9, _)) = plt.subplots(2, 5, sharex=True, sharey=True, 
                                                                                       figsize=(10, 6))
fig.delaxes(_)
fig.suptitle('Audiogram subtypes identifed by GMM in RNENT patient population') 

fig.text(0.5,0.04, "Frequency (Hz)", ha="center", va="center")
fig.text(0.05,0.5, "Thresholds (db)", ha="center", va="center", rotation=90)


x= [250,500,1000,2000,4000,8000]
ticks = [.25,0.5,1, 2, 4, 8]
y = [120,110,100,90,80,70,60,50,40,30,20,10,0,-10]

for ax in [ax1, ax2, ax3, ax4, ax5, ax6, ax7, ax8, ax9]:
    ax.set_xscale('log', base=2)
    ax.set_xticks(x)
    ax.set_xticklabels(ticks)
    ax.invert_yaxis()
    ax.set_xlim(300, 9000)
    ax.set_ylim(130, -10)
    ax.set_facecolor("none")
    ax.grid(False)


# Define the y-axis range for shading
shade_y_min = -10
shade_y_max = 20

# Loop through each subplot and add the shaded area
for ax in [ax1, ax2, ax3, ax4, ax5, ax6, ax7, ax8, ax9]:
    ax.fill_between(x, shade_y_min, shade_y_max, color='gray', alpha=0.3)

# Loop through each subplot and remove grid lines
for ax in [ax1, ax2, ax3, ax4, ax5, ax6, ax7, ax8, ax9]:
    ax.grid(False)
    
             
def plot_function(ax):
             ax.set_xticks(x)
             ax.set_xticklabels(ticks)

             
    
plot_function(ax1)
plt.xticks(x)

plt.gca().invert_yaxis()


ax1.plot(x,lower_quartiles[0], '--', color='grey',)
ax1.plot(x,upper_quartiles[0], '--', color='grey',)
ax2.plot(x,lower_quartiles[1], '--', color='grey',)
ax2.plot(x,upper_quartiles[1], '--', color='grey',)

ax3.plot(x,lower_quartiles[2], '--', color='grey',)
ax3.plot(x,upper_quartiles[2], '--', color='grey',)

ax4.plot(x,lower_quartiles[3], '--', color='grey',)
ax4.plot(x,upper_quartiles[3], '--', color='grey',)

ax5.plot(x,lower_quartiles[4], '--', color='grey',)
ax5.plot(x,upper_quartiles[4], '--', color='grey',)

ax6.plot(x,lower_quartiles[5], '--', color='grey',)
ax6.plot(x,upper_quartiles[5], '--', color='grey',)

ax7.plot(x,lower_quartiles[6], '--', color='grey',)
ax7.plot(x,upper_quartiles[6], '--', color='grey',)

ax8.plot(x,lower_quartiles[7], '--', color='grey',)
ax8.plot(x,upper_quartiles[7], '--', color='grey',)

ax9.plot(x,lower_quartiles[8], '--', color='grey',)
ax9.plot(x,upper_quartiles[8], '--', color='grey',)



ax1.plot(x, cluster1, label = "Cluster 1")
ax1.title.set_text("Cluster 1")
ax2.plot(x, cluster2, label = "Cluster 2")
ax2.title.set_text("Cluster 2")
ax3.plot(x, cluster3, label = "Cluster 3")
ax3.title.set_text("Cluster 3")
ax4.plot(x, cluster4, label = "Cluster 4")
ax4.title.set_text("Cluster 4")
ax5.plot(x, cluster5, label = "Cluster 5")
ax5.title.set_text("Cluster 5")
ax6.plot(x, cluster6, label = "Cluster 6")
ax6.title.set_text("Cluster 6")
ax7.plot(x, cluster7, label = "Cluster 7")
ax7.title.set_text("Cluster 7")
ax8.plot(x, cluster8, label = "Cluster 8")
ax8.title.set_text("Cluster 8")
ax9.plot(x, cluster9, label = "Cluster 9")
ax9.title.set_text("Cluster 9")

plt.gca().invert_yaxis()


# Create a new set of subplots for the bar chart
fig2, ax = plt.subplots(figsize=(10, 2))  # Adjust the height as needed
# Your existing code for the bar chart
# Assuming gmm_thresholds_bl is your DataFrame with a 'cluster' column
import matplotlib.pyplot as plt



# Create a bar plot
plt.bar(range(1, len(num_samples_per_cluster) + 1), num_samples_per_cluster/109854 , color='blue')
plt.xlabel('Cluster')
plt.ylabel('Proportion of Samples')
plt.title('Proportion of Samples per Cluster')

# Adjust the layout to prevent overlapping
plt.tight_layout()

# Add annotation 'A' to the top-left corner
ax1.annotate('A', xy=(-0.15, 1.15), xycoords='axes fraction',
             fontsize=12, fontweight='bold', color='black')

# Add annotation 'B' to the top-left corner
plt.annotate('B', xy=(-0.15, 1.15), xycoords='axes fraction',
             fontsize=12, fontweight='bold', color='black')


plt.show()


plt.savefig('lily.jpg', format='jpeg', dpi=300)

# Show the combined plot

plt.show()


###identify characteristics of the clusters

#update the dataframe with cluster number + 1 and add the demographic information 
info_copy2 = info_copy.copy(deep = True)
merge = pd.concat([info_copy2, df_both_ears[['age', 'age_range', 'sex', 'side']]], axis=1)

merge['clusters'] = merge['clusters'] + 1 #add 1 so cluster numbers start from 1 not 0 
merge

#men and women per cluster and age distribution per cluster in single plot 


sns.set(style="whitegrid")


fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(8, 8)) # Create a figure with two subplots (1 row, 1 column)

# --- Stacked Bar Chart ---
# Calculate the proportion of men and women in each cluster
proportions = merge.groupby(['cluster', 'sex']).size() / merge.groupby('cluster').size()
proportions = proportions.reset_index(name='proportion')

# Pivot the DataFrame to have 'sex' as columns for each cluster
proportions_pivot = proportions.pivot(index='cluster', columns='sex', values='proportion')

# Create a stacked bar chart on the first subplot (ax1)
proportions_pivot.plot(kind='bar', stacked=True, ax=ax1, color=['#1f77b4', '#ff7f0e'])

# Set plot labels and title for the first subplot
ax1.set_title('Proportion of Men and Women in Each Cluster')
ax1.set_xlabel('Cluster')
ax1.set_ylabel('Proportion')

# Add label 'A' to the top-left corner of the first subplot
ax1.text(-0.15, 1.15, 'A', transform=ax1.transAxes, fontsize=16, fontweight='bold', va='top', ha='right')

# --- Violin Plot ---
# Create a violin plot on the second subplot (ax2)
sns.violinplot(data=merge, x="cluster", y="age", ax=ax2).set(title="Violin plot showing the normalized probability distribution of ages for each cluster")

# Median represented by a white dot
# 1st and 3rd quartile indicated by the lower and upper limits of the thick central bar
# Minimum and maximum values indicated by the lower and upper limit of the thin central line

# Add label 'B' to the top-left corner of the second subplot
ax2.text(-0.15, 1.15, 'B', transform=ax2.transAxes, fontsize=16, fontweight='bold', va='top', ha='right')

# Adjust layout to prevent overlapping
plt.tight_layout()

# Save the plot as a JPEG file
plt.savefig('clusters_age_sex.jpg', format='jpeg', dpi=300)
# Show the plot
plt.show()


###Replication Study:

# need to create a list of lists where the rid for each cluster are stored in a list 


def clusters(info_copy):
    clusters = []
    unique_labels = info_copy['clusters'].unique()


    for j in unique_labels:
        clus = []
        for i in range(len(info_copy)):
            #if info['clusters'][i] == j:
            if info_copy['clusters'].iloc[i] == j: 
                clus.append(info_copy['rid'].iloc[i])
        clusters.append(clus)
    #cluster = pd.DataFrame(clusters)
    return clusters 

clusters_init = clusters(info_copy) #output of this function when applied to the original dataset

###Bootstrap version 

#create my bootstrap samples

num_samples = 1000 

np.random.seed(42) # Set a seed for reproducibility

bootstrap_samples = [info_copy.iloc[:, :-1].sample(frac=1, replace=True) for _ in range(num_samples)] #Generate bootstrap samples using the specified seed

#now define by jaccard function 

def jaccard_similarity(list1, list2):
    set1 = set(list1)
    set2 = set(list2)
    intersection = len(set1.intersection(set2))
    union = len(set1.union(set2))
    return intersection / union

# now run the gmm on the bootstrap samples and save the ouputs of the cluster assigment 

for sample in bootstrap_samples:
    gmm.fit(sample.iloc[:, 1:7])
    boot_labels = gmm.predict(sample.iloc[:, 1:7])
    sample["clusters"] = boot_labels

#save the rid per cluster for each bootstrap sample and compre the similarity of each cluster to the original GMM
#this finds the jaccard_index for the most similar cluster 

n_clus = 9
boot = []

for df in bootstrap_samples:
    j = clusters(df)
    bootresults = []
    for k in range(n_clus):
        max_similarity = max(jaccard_similarity(clusters_init[k], j_cluster) for j_cluster in j)
        bootresults.append(max_similarity)
    boot.append(bootresults)    
    
#calculate the mean and std jaccard score per cluster across all bootstrap samples

boot_array = np.array(boot) # Convert 'boot' to a NumPy array for easier calculations

mean_values = np.mean(boot_array, axis=0) # Calculate mean values for each cluster (column-wise mean)

std_dev_values = np.std(boot_array, axis=0) # Calculate standard deviations for each cluster (column-wise standard deviation)

result = list(zip(mean_values, std_dev_values)) # Combine mean and standard deviation into a list of tuples

#plot this information 

import matplotlib.pyplot as plt

clusters_xaxis = range(len(result))
 
mean_values, std_dev_values = zip(*result)  #Unpack the tuples

plt.bar(clusters_xaxis, mean_values, yerr=std_dev_values, capsize=5)
plt.xlabel('Cluster')
plt.ylabel('Mean Jaccard Similarity')
plt.title('Mean Jaccard Similarity with Standard Deviation per cluster across all bootstrap samples')
plt.show()



### Replicability across different initialisations 

random_seeds = [1, 10, 30, 40, 50, 60000, 70, 80, 9333330, 100, 110, 120, 13044, 140, 150, 160, 170, 18024, 190, 200] #remove 20 as this used in optimal model
df_list = []



for r in random_seeds:
    info_copy_seed = info.copy(deep=True)
    gmm = mixture.GaussianMixture(n_components=9, covariance_type='full', random_state=r, reg_covar=0.01)
    gmm_start = gmm.fit(info_copy_seed.drop(['rid'], axis=1))
    labels = gmm_start.predict(info_copy_seed.drop(['rid'], axis=1))
    info_copy_seed["clusters"] = labels
    df_list.append(info_copy_seed)

#store rid per cluster for each random seed and compare cluster assignment to original GMM using jaccard similarity function     
    
n_clus = 9
itlist = []


for l in df_list:
    j = clusters(l)
    iteration_results = []
    for k in range(n_clus):
        max_similarity = max(jaccard_similarity(clusters_init[k], j_cluster) for j_cluster in j)
        iteration_results.append(max_similarity)
    itlist.append(iteration_results)    


# Convert 'itlist' to a NumPy array for easier calculations
it_array = np.array(itlist)

# Calculate mean values for each cluster (column-wise mean)
mean_values_it = np.mean(it_array, axis=0)

# Calculate standard deviations for each cluster (column-wise standard deviation)
std_dev_values_it = np.std(it_array, axis=0)

# Combine mean and standard deviation into a list of tuples
result_it = list(zip(mean_values_it, std_dev_values_it))

clusters_xaxis = range(len(result))


mean_values_it, std_dev_values_it = zip(*result_it) # Unpack the tuples

# Plotting
plt.bar(clusters_xaxis, mean_values_it, yerr=std_dev_values_it, capsize=5)
plt.xlabel('Cluster')
plt.ylabel('Mean Jaccard Similarity')
plt.title('Mean Jaccard Similarity with Standard Deviation per cluster across all models iterating through different initialisatons')
plt.show()



##Replicability across different sample sizes of the original dataset 


np.random.seed(42) # set seed for reproducibility
num_samples_per_percentage = 1000
bootstrap_samples_percent = []

# Generate 1000 bootstrap samples for each percentage from 10% to 90%
for percentage in range(10, 91, 10):
    fraction = percentage / 100.0
    samples_for_percentage = [info_copy2.sample(frac=fraction, replace=False) for _ in range(num_samples_per_percentage)]
    bootstrap_samples_percent.append((percentage, samples_for_percentage))
    
import numpy as np
import pickle
from tqdm import tqdm

# Initialize lists to store the filenames of pickle files
per_percentage_boot_pickle_filenames = []
per_percentage_bootresults_pickle_filenames = []
all_boot = []
all_bootresults = []

# Apply GMM and clusters function to each bootstrap sample for every percentage
for percentage, samples in tqdm(bootstrap_samples_percent, desc="Processing percentages", unit="percentage"):
    bootresults = []  # List to store maximum similarity scores for each sample in the current percentage
    mean_bootresults = []
    
    # Inner loop: iterate over each sample in the current percentage
    for sample_index, sample in enumerate(samples, start=1):
        # Code for fitting GMM and calculating similarity scores
        gmm = mixture.GaussianMixture(n_components=9, covariance_type='full', random_state=20, reg_covar=0.01)
        gmm.fit(sample.iloc[:, 1:7])
        boot_labels = gmm.predict(sample.iloc[:, 1:7])
        sample_with_clusters = sample.copy()  # Create a copy to avoid modifying the original sample
        sample_with_clusters["clusters"] = boot_labels
        j = clusters(sample_with_clusters) 
        r = clusters(sample) 

        max_similarities = [max(jaccard_similarity(r[k], j_cluster) for j_cluster in j) for k in range(n_clus)]
        bootresults.append(max_similarities)
        mean_similarity = sum(max_similarities) / n_clus  # Calculate the mean Jaccard score across all clusters for each sample
        mean_bootresults.append(mean_similarity)
        
        # Update tqdm description to indicate progress
        tqdm.write(f"Processing sample {sample_index} of {len(samples)} in percentage {percentage}")

    # Calculate the mean and confidence interval across all samples in the percentage
    mean_across_samples = np.mean(mean_bootresults)
    ci_lower, ci_upper = stats.t.interval(0.95, len(mean_bootresults)-1, loc=mean_across_samples, scale=stats.sem(mean_bootresults))
    
    # Append results to the final lists
    boot = (percentage, mean_across_samples, ci_lower, ci_upper)
    all_boot.append(boot)
    all_bootresults.extend(bootresults)



# Extracting data for plotting
percentages = [entry[0] for entry in  all_boot]
means = [entry[1] for entry in  all_boot]
ci_lower = [entry[2] for entry in  all_boot]
ci_upper = [entry[3] for entry in  all_boot]

# Convert lists to NumPy arrays for element-wise operations
means = np.array(means)
ci_lower = np.array(ci_lower)
ci_upper = np.array(ci_upper)

# Calculate the error bars (half of the confidence interval)
errors_lower = means - ci_lower
errors_upper = ci_upper - means

# Plotting
plt.figure(figsize=(10, 6))
plt.bar(percentages, means, yerr=[errors_lower, errors_upper], capsize=5, width = 5)
plt.xlabel('Percentage')
plt.ylabel('Mean Jaccard Similarity Score')
plt.title('Mean Jaccard Similarity Score across Percentage of Original Dataset Size with 95% Confidence Interval')
plt.xticks(percentages)  # Set x-axis ticks to percentages
plt.grid(False)

plt.savefig('percentage.jpg', format='jpeg', dpi=300)
plt.show()

### Additional Analysis finding NIHL and reverse slope hearing loss 

#Now lets see about Noise-induced hearing loss
#coles et al criteria

noise_coles = gmm_thresholds_bl[
    (gmm_thresholds_bl['ac_4000'] - gmm_thresholds_bl['ac_8000'] >= 10) &
    (
        (gmm_thresholds_bl['ac_4000'] - gmm_thresholds_bl['ac_2000'] >= 10) |
        (gmm_thresholds_bl['ac_4000'] - gmm_thresholds_bl['ac_1000'] >= 10)
    )
]
noise_coles.count()
print("noise-induced hearing loss with atleast 10dB threshold sized dip at 4kHz", noise_coles.count())

####now assign everyone in our dataframe as noise 

merge['noise'] = (
    (merge['ac_4000'] - merge['ac_8000'] >= 10) & 
    (
        (merge['ac_4000'] - merge['ac_2000'] >= 10) |
        (merge['ac_4000'] - merge['ac_1000'] >= 10)
    )
).astype(int)

merge[merge['noise']==1]


# Count the occurrences of each cluster for rows where 'noise' is equal to 1
cluster_counts = merge[merge['noise'] == 1]['cluster'].value_counts()

# Sort clusters based on descending frequency
sorted_clusters = cluster_counts.sort_values(ascending=False)
 
# Filter the DataFrame based on the 'noise' column
filtered_merge = merge[merge['noise'] == 1]

# Calculate the mean across the first 6 columns for the filtered DataFrame
mean_values = filtered_merge.iloc[:, :6].mean()


#calculate the IQR

# Extract the first 6 columns for calculation
quartiles = filtered_merge.iloc[:,:6].quantile([0.25, 0.75])
upper_quartiles = quartiles.iloc[0].to_numpy()
lower_quartiles = quartiles.iloc[1].to_numpy()

fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(8, 8))
plt.subplots_adjust(hspace=0.5) 

ax1.set_title("Noise-induced phenotype: 10dB greater at 4kHz than at 8kHz and 1/2kHz")
ax1.set_ylabel("Thresholds (db)")
ax1.set_xlabel("Frequency (Hz)")
ax1.set_xlim(200,9000)
ax1.set_ylim(130,-10)
ax1.set_facecolor("none")

x = [250,500,1000,2000,4000,8000]
ticks = [250,500,1000, 2000, 4000, 8000]


ax1.set_xscale('log', base=2)
ax1.set_xticks(x)
ax1.set_xticklabels(ticks)
ax1.fill_between(x, shade_y_min, shade_y_max, color='gray', alpha=0.3)


ax1.yaxis.set_ticks([120,110,100,90,80,70,60,50,40,30,20,10,0,-10])

ax1.plot()
ax1.grid(color="grey")
ax1.grid(axis="x", which='minor',color="grey", linestyle="--")
ax1.plot(x, mean_values, label='Mean Values', c = 'blue')
ax1.plot(x, upper_quartiles, c = 'grey',  linestyle='--')
ax1.plot(x, lower_quartiles, c = 'grey', linestyle='--')
ax1.grid(False)
ax1.plot(x, )

# Add label 'B' to the top-left corner of the second subplot
ax1.text(-0.05, 1.15, 'A', transform=ax1.transAxes, fontsize=16, fontweight='bold', va='top', ha='right')



# Plot the mean values


import matplotlib.pyplot as plt


# Count the occurrences of each cluster for rows where 'noise' is equal to 1
cluster_counts = merge[merge['noise'] == 1]['cluster'].value_counts()

# Sort clusters based on descending frequency
sorted_clusters = cluster_counts.sort_values(ascending=False)

# Plotting
plt.bar(sorted_clusters.index.astype(str), sorted_clusters.values)
plt.xlabel('Cluster')
plt.ylabel('Count')
plt.title('Distribution of Clusters for Noise Induced Hearing Loss')
plt.grid(False)

# Add label 'B' to the top-left corner of the second subplot
ax2.text(-0.05, 1.15, 'B', transform=ax2.transAxes, fontsize=16, fontweight='bold', va='top', ha='right')
# Save the plot as a JPEG file
plt.savefig('clusters_NOISE.jpg', format='jpeg', dpi=300)
plt.show

"""Menniere's disease

Low frequency loss defined audiometrically using pre-established criteria. First the low-frequency, mid-frequency and high-frequency hearing losses L1, L2 and L3 were computed as: L1 = [(threshold at 250 Hz) + (threshold at 500 Hz)]/2 L2 = [(threshold at 1 kHz) + (threshold at 2 kHz)]/2 L3 = [(threshold at 4 kHz) + (threshold at 8 kHz)]/2

‘low’ frequency losses ie reverse sloping hearing loss defined as: L3 − L1 ≤ −10"""

L1 = (gmm_thresholds_bl['ac_250'] +  gmm_thresholds_bl['ac_500'])/2
L3 = (gmm_thresholds_bl['ac_4000'] +  gmm_thresholds_bl['ac_8000'])/2
merge["meniere"] = L3 - L1 <=-10
meniere.sum()
print("Reverse sloping hearing loss", meniere.sum()) 


#assign meniere to 1 when the criterion is met 
merge[merge['meniere']==1]

# Count the occurrences of each cluster for rows where 'meniere' is equal to 1
cluster_counts = merge[merge['meniere'] == 1]['cluster'].value_counts()

# Sort clusters based on descending frequency
sorted_clusters = cluster_counts.sort_values(ascending=False)
 
# Filter the DataFrame based on the 'noise' column
filtered_merge = merge[merge['meniere'] == 1]

# Calculate the mean across the first 6 columns for the filtered DataFrame
mean_values = filtered_merge.iloc[:, :6].mean()


#calculate the IQR

# Extract the first 6 columns for calculation
quartiles = filtered_merge.iloc[:,:6].quantile([0.25, 0.75])
upper_quartiles = quartiles.iloc[0].to_numpy()
lower_quartiles = quartiles.iloc[1].to_numpy()

fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(8, 8))
plt.subplots_adjust(hspace=0.5) 

ax1.set_title("Reverse sloping phenotype")
ax1.set_ylabel("Thresholds (db)")
ax1.set_xlabel("Frequency (Hz)")
ax1.set_xlim(200,9000)
ax1.set_ylim(130,-10)
ax1.set_facecolor("none")

x = [250,500,1000,2000,4000,8000]
ticks = [250,500,1000, 2000, 4000, 8000]


ax1.set_xscale('log', base=2)
ax1.set_xticks(x)
ax1.set_xticklabels(ticks)
ax1.fill_between(x, shade_y_min, shade_y_max, color='gray', alpha=0.3)


ax1.yaxis.set_ticks([120,110,100,90,80,70,60,50,40,30,20,10,0,-10])

ax1.plot()
ax1.grid(color="grey")
ax1.grid(axis="x", which='minor',color="grey", linestyle="--")
ax1.plot(x, mean_values, label='Mean Values', c = 'blue')
ax1.plot(x, upper_quartiles, c = 'grey',  linestyle='--')
ax1.plot(x, lower_quartiles, c = 'grey', linestyle='--')
ax1.grid(False)
ax1.plot(x, )

# Add label 'B' to the top-left corner of the second subplot
ax1.text(-0.05, 1.15, 'A', transform=ax1.transAxes, fontsize=16, fontweight='bold', va='top', ha='right')



# Plot the mean values


import matplotlib.pyplot as plt


# Count the occurrences of each cluster for rows where 'noise' is equal to 1
cluster_counts = merge[merge['meniere'] == 1]['cluster'].value_counts()

# Sort clusters based on descending frequency
sorted_clusters = cluster_counts.sort_values(ascending=False)

# Plotting
plt.bar(sorted_clusters.index.astype(str), sorted_clusters.values)
plt.xlabel('Cluster')
plt.ylabel('Count')
plt.title('Distribution of Clusters for Reverse Sloping Hearing Loss')
plt.grid(False)

# Add label 'B' to the top-left corner of the second subplot
ax2.text(-0.05, 1.15, 'B', transform=ax2.transAxes, fontsize=16, fontweight='bold', va='top', ha='right')
# Save the plot as a JPEG file
plt.savefig('clusters_meniere.jpg', format='jpeg', dpi=300)
plt.show

### Heat map analysis looking at cluster assignment between left and right ears 


# Pivot the DataFrame to have 'side' and 'cluster' as separate columns
result = merge.pivot_table(index='rid', columns='side', values='cluster', aggfunc='first').reset_index()

# Rename columns if needed
result.columns.name = None  # Remove the 'side' label on columns
result = result.rename(columns={'left': 'left_cluster', 'right': 'right_cluster'})


# Create a contingency table
contingency_table = pd.crosstab(result['left_cluster'], result['right_cluster']).transpose()

print(contingency_table)

# Calculate the probability
probability_table = contingency_table.div(contingency_table.sum(axis=0), axis=1)
probability_table



# Round the values in the probability table to 2 decimal places
probability_table_rounded = probability_table.round(2)

# Plot the heatmap for the probability table with rounded values
plt.figure(figsize=(10, 8))
sns.heatmap(probability_table_rounded, annot=True, cbar=True, fmt=".2f", cmap = 'Blues')
plt.title("Probability Table Heatmap (Rounded to 2 Decimal Places)")
plt.savefig('heatmap.jpg', format='jpeg', dpi=300)
plt.show()

