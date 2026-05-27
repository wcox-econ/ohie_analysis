* Title:    BetterDDwithIV/monthly_crime_stats.do
* Blame:    William Cox <wcox@williamandrewcox.com>
* Created:  12 June 2025
* Purpose:  Runs an "event study" of bias in DiD using event study
*           data of OHIE experiment
* Note:     Run via `nohup stata-mp -b do BetterDDwithIV/event_study_bias.do &`


clear all

cd "/homes/nber/coxw/oregon/coxw/ohie_analysis"

capture log close _all

log using "output/monthly_crime_stats.log", replace


* Get all res_person_ids used in analysis

use "original_data/individual_crime_data.dta", clear

keep res_person_id
gduplicates drop

tempfile indiv_identifiers
save `indiv_identifiers'


use "raw_crime_data/matched_crime_data.dta", clear

* Keep observations in OHIE data
keep if true_match == 1

keep res_person_id incidentdate_first crimes_per_case penalcode_FE penalcode_MI ///
	penalcode_VIO penalcode_Unknown crime_substanceabuse_per_case ///
	crime_violent_per_case crime_income_per_case crime_unclass_per_case ///
	disposition_convicted disposition_missing tot_convict_*

gen month = month(incidentdate_first)
gen year = year(incidentdate_first)

gen MDate = ym(year, month)

gen case = 1
gen tot_charge = crimes_per_case

gen fel = penalcode_FE != 0
gen tot_fel = penalcode_FE

gen mi = penalcode_MI != 0
gen tot_mi = penalcode_MI

gen viol = penalcode_VIO!=0
gen tot_viol = penalcode_VIO

gen unknow = penalcode_Unknown!=0
gen tot_unknow = penalcode_Unknown

gen subst = crime_substanceabuse_per_case!=0
gen tot_subst = crime_substanceabuse_per_case

gen vlent = crime_violent_per_case!=0
gen tot_vlent = crime_violent_per_case

gen incrime = crime_income_per_case!=0
gen tot_incrime = crime_income_per_case

gen unclass = crime_unclass_per_case!=0
gen tot_unclass = crime_unclass_per_case

gen convict = disposition_convicted!=0
gen tot_convict = disposition_convicted

foreach stub in FE MI VIO UNK INC VIOL SUBST UNCLASS {
	gen convict`stub' = tot_convict_`stub'!=0
}

* Keep only one observations per person-month (CHECK THIS AFTER CHANGES)
gcollapse (max) case fel mi viol unknow subst vlent incrime unclass convict* ///
	(sum) tot*, by(res_person_id MDate month year)

gisid res_person_id MDate

* Merge in all individual identifiers (i.e. people who were never charged)
merge m:1 res_person_id using `indiv_identifiers', gen(id_merge)
replace month = 3 if id_merge == 2
replace year = 2008 if id_merge == 2
replace MDate = ym(year, month) if id_merge == 2

xtset res_person_id MDate

* Fill in dataset to account for every month
tsfill, full

format MDate %tm

* Fill in data for months in which individuals were not charged
foreach var of varlist case fel mi viol unknow subst vlent incrime unclass convict* tot*{
	replace `var' = 0 if mi(`var')
}
replace year = yofd(dofm(MDate)) if mi(year)
replace month = month(dofm(MDate)) if mi(month)

keep if year >= 2007 & year <= 2010
bysort res_person_id : egen id_merge_ph = max(id_merge)
replace id_merge = id_merge_ph
drop id_merge_ph

* March 08 corresponds with 578
gen month_index = MDate - 578

gen string_month_index = cond(month_index >= 0, ///
	"month_" + strofreal(month_index), "month_m" + strofreal(abs(month_index)))

drop id_merge

save "cleaned_data/monthly_crime_stats_long.dta", replace

drop MDate month year month_index

foreach var of varlist case fel mi viol unknow subst vlent incrime unclass convict* tot*{
	rename `var' `var'_
}

reshape wide case_ fel_ mi_ viol_ unknow_ subst_ vlent_ incrime_ unclass_ convict* tot*, ///
	i(res_person_id) j(string_month_index) string

gisid res_person_id

foreach var of varlist case_*{
	label var `var' "Had a criminal case in given month"
}

foreach var of varlist tot_charge*{
	label var `var' "Number of criminal charges in given month"
}

foreach var of varlist fel_*{
	label var `var' "Had a felony charge in given month"
}

foreach var of varlist tot_fel_*{
	label var `var' "Number of felony charges in given month"
}

foreach var of varlist mi_*{
	label var `var' "Had a misdemeanor charge in given month"
}

foreach var of varlist tot_mi_*{
	label var `var' "Total number of misdemeanor charges in given month"
}

foreach var of varlist viol_*{
	label var `var' "Charged with a violation in given month"
}

foreach var of varlist tot_viol_*{
	label var `var' "Total number of violations in given month"
}

foreach var of varlist unknow_*{
	label var `var' "Charged with crimes (unknown penal code type) in given month"
}

foreach var of varlist tot_unknow_*{
	label var `var' "Total number of charges with unknown penal code in given month"
}

foreach var of varlist subst_*{
	label var `var' "Had a substance abuse charge in given month"
}

foreach var of varlist tot_subst_*{
	label var `var' "Number of substance abuse charges in given month"
}

foreach var of varlist vlent_*{
	label var `var' "Had a violent criminal charge in given month"
}

foreach var of varlist tot_vlent_*{
	label var `var' "Number of violent criminal charges in given month"
}

foreach var of varlist incrime_*{
	label var `var' "Charged with income-generating crime in given month"
}

foreach var of varlist tot_incrime_*{
	label var `var' "Number of income-generating charges in given month"
}

foreach var of varlist unclass_*{
	label var `var' "Charged with non-income, non-substance, and non-violent crime in given month"
}

foreach var of varlist tot_unclass_*{
	label var `var' "Number of non-income, non-substance, and non-violent charges in given month "
}

foreach var of varlist convict_*{
	label var `var' "Had a conviction in given month"
}

foreach var of varlist tot_convict_*{
	label var `var' "Number of convictions in given month"
}

foreach var of varlist convictFE_*{
	label var `var' "Had a felony conviction in given month"
}

foreach var of varlist tot_convict_FE_*{
	label var `var' "Total number of felony convictions in given month"
}

foreach var of varlist convictMI_*{
	label var `var' "Had a misdemeanor conviction in given month"
}

foreach var of varlist tot_convict_MI_*{
	label var `var' "Total number of misdemeanor convictions in given month"
}

foreach var of varlist convictVIO_*{
	label var `var' "Had a violation conviction in given month"
}

foreach var of varlist tot_convict_VIO_*{
	label var `var' "Total number of violation convictions in given month"
}

foreach var of varlist convictUNK_*{
	label var `var' "Had an unknown conviction in given month"
}

foreach var of varlist tot_convict_UNK_*{
	label var `var' "Total number of unknown convictions in given month"
}

foreach var of varlist convictINC_*{
	label var `var' "Had an income-generating conviction in given month"
}

foreach var of varlist tot_convict_INC_*{
	label var `var' "Total number of income-generating convictions in given month"
}

foreach var of varlist convictVIOL_*{
	label var `var' "Had a violent conviction in given month"
}

foreach var of varlist tot_convict_VIOL_*{
	label var `var' "Total number of violent convictions in given month"
}

foreach var of varlist convictSUBST_*{
	label var `var' "Had a substance conviction in given month"
}

foreach var of varlist tot_convict_SUBST_*{
	label var `var' "Total number of substance convictions in given month"
}

foreach var of varlist convictUNCLASS_*{
	label var `var' "Had an unclasified conviction in given month"
}

foreach var of varlist tot_convict_UNCLASS_*{
	label var `var' "Total number of unclassified convictions in given month"
}

order *, sequential
order res_person_id



save "cleaned_data/monthly_crime_stats_wide.dta", replace


* SANITY CHECK

use "cleaned_data/monthly_crime_stats_long.dta", clear

drop if MDate > 606

gen period = MDate >= 578

gcollapse (max) case fel mi viol unknow subst vlent incrime unclass convict* ///
	(sum) tot*, by(res_person_id period)

rename (tot_convict_MI tot_convict_FE tot_convict_VIO tot_convict_UNK ///
	tot_convict_INC tot_convict_SUBST tot_convict_VIOL tot_convict_UNCLASS) ///
	(tot_convictMI tot_convictFE tot_convictVIO tot_convictUNK ///
	tot_convictINC tot_convictSUBST tot_convictVIOL tot_convictUNCLASS)

local crimeVars case fel mi viol unknow subst vlent incrime ///
	unclass convict* tot*
local pre_post_vars

foreach var of varlist `crimeVars'{
	local pre_post_vars `pre_post_vars' `var'_09mar2008 `var'_15jul2010
}

* Get relevant variables from analysis data
preserve
	use res_person_id `pre_post_vars' using "original_data/individual_crime_data.dta", clear
	
	describe, fullnames

	rename *_09mar2008 *0
	rename *_15jul2010 *1

	di("Reshape describe")
	describe, fullnames

	local reshapeVars case tot_charge fel tot_fel mi tot_mi viol tot_viol ///
		unknow tot_unknow subst tot_subst vlent tot_vlent incrime ///
		tot_incrime unclass tot_unclass convict tot_convict convictFE ///
		tot_convictFE convictMI tot_convictMI convictVIO tot_convictVIO ///
		convictUNK tot_convictUNK convictINC tot_convictINC convictVIOL ///
		tot_convictVIOL convictSUBST tot_convictSUBST convictUNCLASS tot_convictUNCLASS
	*di("Reshape reshapeVars describe")
	*describe `reshapeVars', fullnames

	reshape long `reshapeVars', i(res_person_id) j(period)

	describe, fullnames


	gisid res_person_id period


	tempfile compareData
	save `compareData'
restore

foreach var of varlist case fel mi viol unknow subst vlent incrime unclass convict* tot*{
	rename `var' `var'_wc
}

describe, fullnames

gisid res_person_id period

merge 1:1 res_person_id period using ///
	`compareData', ///
	gen(sanity_merge)

keep if sanity_merge == 2 | sanity_merge == 3

local checkVars case tot_charge fel tot_fel mi tot_mi viol tot_viol ///
	unknow tot_unknow subst tot_subst vlent tot_vlent incrime ///
	tot_incrime unclass tot_unclass convict tot_convict convictFE ///
	tot_convictFE convictMI tot_convictMI convictVIO tot_convictVIO ///
	convictUNK tot_convictUNK convictINC tot_convictINC convictVIOL ///
	tot_convictVIOL convictSUBST tot_convictSUBST convictUNCLASS tot_convictUNCLASS

foreach var in `checkVars'{
	gen match_`var' = `var'_wc == `var'
}

sum match_*

listsome res_person_id period if match_case == 0, random

save "cleaned_data/sanity_check_monthly_crime.dta", replace

log close

