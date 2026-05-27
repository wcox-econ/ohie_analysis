================================================================================
Better DD with IV - OHIE Analysis
Master README
Hull and Roth
================================================================================

Project Overview
----------------
This project replicates Finkelstein, Baicker, and Miller's work on 
the impact of Medicaid on crime, and extends the work to the 
"Better DD with IV" setting. Specifically, we replicate the main results 
from the Finkelstein et al. paper, calculate the bias of our hypothetical DiD between compliers and never takers, create an "event study" version of the 
dataset with monthly crime statistics, and then calculate the DiD bias in 
our event study replication.


================================================================================
MODULE 1: replicate-amy-sarah.do
================================================================================

Description
-----------
Replicates Finkelstein et al.'s main results, then calculates bias between compliers and never-takers in our hypothetical DiD

Blame
-----------
Jon Roth

Key Steps
---------
1. Restrict dataset to households of size 1
2. Replicate Finkelstein et al results with household restriction
3. Calculate DiD bias


Inputs
------
- /disk/store1a/oregon/millers/Criminalcharges/Data/individual_crime_data.dta


Outputs
-------
- bias_results.csv


================================================================================
MODULE 2: monthly_crime_stats.do
================================================================================

Description
-----------
Creates wide and long datasets of monthly crime statistics for individuals. 
Collapses the long dataset and compares to Finkelstein data as a sanity check. 
After random spot-checking, differences seem to occur only if individual was 
charged with a crime in March 2008 or July 2010 (Finkelstein original data 
defines pre- treatment as before/after 9 March 2008 and analysis ends on 15 
July 2010)

Blame
-----------
Will Cox (wcox@williamandrewcox.com)

Key Steps
---------
1. Load raw Oregon crime data
2. Create crime variables
3. Collapse crime data to individual-month level
4. Fill in each month for each individual to create balanced panel
5. Reshape crime data from long to wide
6. Reload long dataset, and collapse to pre/post treatment level
7. Compare data from pre/post treatment level to original Finkelstein
	data as sanity check.


Inputs
------
- /disk/store1a/oregon/millers/Criminalcharges/Data/individual_crime_data.dta


Outputs
-------
- cleaned_data/monthly_crime_stats_long.dta
- cleaned_data/monthly_crime_stats_wide.dta
- cleaned_data/sanity_check_monthly_crime.dta

================================================================================
MODULE 3: event_study_bias.do
================================================================================

Description
-----------
Runs our DiD bias code in an "event study" version of the Finkelstein et al. 
paper. We have two event study specifications. The first run the DiD bias code 
over our monthly crime data developed in module 2. The second collapses the 
monthly data into 6-month periods, and runs the event study over these periods.

Blame
-----------
Will Cox (wcox@williamandrewcox.com)

Key Steps
---------
1. Drop households with more than 1 person
2. Run DiD bias code over all months (except for our base of Feb 08) in which 
	we have crime data.
3. Collapse our monthly crime data into 6 month periods
4. Run DiD bias code over all periods (except our base period -1)


Inputs
------
- /disk/store1a/oregon/millers/Criminalcharges/Data/individual_crime_data.dta
- cleaned_data/monthly_crime_stats_wide.dta

Outputs
-------
- cleaned_data/monthly_crime_stats_long.dta
- cleaned_data/monthly_crime_stats_wide.dta
- cleaned_data/sanity_check_monthly_crime.dta
- BetterDDwithIV_event_study.csv
- BetterDDwithIV_event_study_period.csv



