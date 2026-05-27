capture log close _all

log using "output/jon_code_rep.log", replace

use /disk/store1a/oregon/millers/Criminalcharges/Data/individual_crime_data.dta, clear

*Replicate their IV exactly
ivregress 2sls case_15jul2010 (ohp_all_ever_15jul2010 =treatment) nnn* tot_case_09mar2008   [pw=weight_15jul2010], cluster(reservation_id)

*Pre-treatment outcome analog
ivregress 2sls case_09mar2008 (ohp_all_ever_15jul2010 =treatment) nnn* tot_case_09mar2008  [pw=weight_15jul2010], cluster(reservation_id)

* For the rest of our analysis, we restrict to households of size 1
keep if numhh_list == 1


**Local's defining variable names
local paper_outcome case_15jul2010
*local paper_outcome case_30sep2009
local paper_baseline case_09mar2008
local paper_treatment treatment
local paper_controls nnn* tot_case_09mar2008
*local paper_controls nnn* // do without stot_case_09mar2008
*local paper_controls "" // do without controls
local paper_cluster reservation_id
local paper_if_cond ""
local paper_options ""
local paper_weight [pw=weight_15jul2010]
local paper_takeup ohp_all_ever_15jul2010


*ITT
reg `paper_outcome' `paper_treatment' `paper_controls' `paper_weight' `paper_if_cond', cluster(`paper_cluster') `paper_options'

*2SLS
ivreg2 `paper_outcome' (`paper_takeup' = `paper_treatment') `paper_controls' `paper_weight' `paper_if_cond', cluster(`paper_cluster') `paper_options'

scalar tsls = _b[`paper_takeup']
scalar tslsse = _se[`paper_takeup']

*First stage
reg `paper_takeup' `paper_treatment' `paper_controls' `paper_weight' `paper_if_cond', cluster(`paper_cluster') `paper_options'

*generate change in y
gen y_diff = `paper_outcome' - `paper_baseline'
gen y_diff_dm1 = (`paper_takeup' - 1) * y_diff 
gen y_post_dm1 = (`paper_takeup' - 1) * `paper_outcome'
gen y_pre_dm1 = (`paper_takeup' - 1) * `paper_baseline'

*Control complier \Delta Y(0)
ivreg2 y_diff_dm1 (`paper_takeup' = `paper_treatment') `paper_controls' `paper_weight' `paper_if_cond', cluster(`paper_cluster') `paper_options'

* NT \Delta Y(0)
if("`paper_if_cond'" == ""){
	local nt_if_cond "if `paper_treatment' == 1 & `paper_takeup' == 0"
}
else{
	local nt_if_cond "`paper_if_cond' & `paper_treatment' == 1 & `paper_takeup' == 0"
}
reg y_diff `paper_weight' `nt_if_cond', cluster(`paper_cluster')



*Control complier Ypre(0)
ivreg2 y_pre_dm1 (`paper_takeup' = `paper_treatment') `paper_controls' `paper_weight' `paper_if_cond', cluster(`paper_cluster') `paper_options'

* NT Ypre(0)
if("`paper_if_cond'" == ""){
	local nt_if_cond "if `paper_treatment' == 1 & `paper_takeup' == 0"
}
else{
	local nt_if_cond "`paper_if_cond' & `paper_treatment' == 1 & `paper_takeup' == 0"
}
reg `paper_baseline' `paper_weight' `nt_if_cond', cluster(`paper_cluster')



*Control complier Ypost(0)
ivreg2 y_post_dm1 (`paper_takeup' = `paper_treatment') `paper_controls' `paper_weight' `paper_if_cond', cluster(`paper_cluster') `paper_options'

* NT Ypost(0)
if("`paper_if_cond'" == ""){
	local nt_if_cond "if `paper_treatment' == 1 & `paper_takeup' == 0"
}
else{
	local nt_if_cond "`paper_if_cond' & `paper_treatment' == 1 & `paper_takeup' == 0"
}
reg `paper_outcome' `paper_weight' `nt_if_cond', cluster(`paper_cluster')

*** Create programs to calculate our quantities of interest, which we then use w bootstrap

* function for calculating different in Y(0) between Cs and NTs
cap program drop c_nt_diff
program c_nt_diff, rclass
	syntax , ///
	y(varname) ///
        takeup(varname) ///
        treatment(varname) ///
        controls(varlist) ///
        weight(string) ///
        [ifcond(string)] ///
        cluster(varname) ///
        [options(string)]
	
	cap drop y_dm1
	gen y_dm1 = (`takeup'-1)*`y'
	
	if("`ifcond'" == ""){
	local nt_if_cond "if `treatment' == 1 & `takeup' == 0"
	}
else{
	local nt_if_cond "if `ifcond' & `treatment' == 1 & `takeup' == 0"
}

    ivreg2 y_dm1 (`takeup' = `treatment') ///
        `controls' `weight' `ifcond', ///
        cluster(`cluster') `options' 
	scalar c_mean = _b[`takeup']
	reg `y' `nt_if_cond'
	scalar nt_mean = _b["_cons"] 
	return scalar diff = c_mean - nt_mean
end

* Function for DID bias
cap program drop did_bias
program did_bias, rclass
	syntax , ///
	ypre(varname) ///
	ypost(varname) ///
        takeup(varname) ///
        treatment(varname) ///
        controls(varlist) ///
        weight(string) ///
        [ifcond(string)] ///
        cluster(varname) ///
        [options(string)]
	
	cap drop y_diff
	gen y_diff = `ypost' - `ypre'
	
	c_nt_diff, y(y_diff) takeup(`takeup') treatment(`treatment') controls(`controls') weight(`weight') ifcond(`ifcond') cluster(`cluster') options(`options')

	return scalar bias = r(diff)

end

*Function for DIM bias
cap program drop dim_bias
program dim_bias, rclass
	syntax , ///
	[ypre(varname)] ///
	ypost(varname) ///
        takeup(varname) ///
        treatment(varname) ///
        controls(varlist) ///
        weight(string) ///
        [ifcond(string)] ///
        cluster(varname) ///
        [options(string)]
	
	cap drop y_diff
	gen y_diff = `ypost' - `ypre'
	
	c_nt_diff, y(`ypost') takeup(`takeup') treatment(`treatment') controls(`controls') weight(`weight') ifcond(`ifcond') cluster(`cluster') options(`options')

	return scalar bias = r(diff)

end

*Function for difference in Ypre(0)
cap program drop ypre_diff
program ypre_diff, rclass
	syntax , ///
	ypre(varname) ///
	[ypost(varname)] ///
        takeup(varname) ///
        treatment(varname) ///
        controls(varlist) ///
        weight(string) ///
        [ifcond(string)] ///
        cluster(varname) ///
        [options(string)]
	
	cap drop y_diff
	gen y_diff = `ypost' - `ypre'
	
	c_nt_diff, y(`ypre') takeup(`takeup') treatment(`treatment') controls(`controls') weight(`weight') ifcond(`ifcond') cluster(`cluster') options(`options')

	return scalar diff = r(diff)

end

*Function for LDV Bias
cap program drop ldv_bias
program ldv_bias, rclass
	syntax , ///
	ypre(varname) ///
	ypost(varname) ///
        takeup(varname) ///
        treatment(varname) ///
        controls(varlist) ///
        weight(string) ///
        [ifcond(string)] ///
        cluster(varname) ///
        [options(string)]
	
	
	did_bias, ypre(`ypre') ypost(`ypost') takeup(`takeup') treatment(`treatment') controls(`controls') weight(`weight') ifcond(`ifcond') cluster(`cluster') options(`options')

	local didbias = r(bias)
	
	dim_bias, ypre(`ypre') ypost(`ypost') takeup(`takeup') treatment(`treatment') controls(`controls') weight(`weight') ifcond(`ifcond') cluster(`cluster') options(`options')

	local dimbias = r(bias)
	
	if("`ifcond'" == ""){
	local nt_if_cond "if `treatment' == 1 & `takeup' == 0"
	}
	else{
	local nt_if_cond "if `ifcond' & `treatment' == 1 & `takeup' == 0"
	}
	
	reg `ypost' `ypre' `nt_if_cond' `weight'
	
	local beta = _b[`ypre']
	
	local ldv_bias = `beta'*`didbias' + (1-`beta') * `dimbias'
	
	return scalar bias = `ldv_bias'

end


*did_bias, ypre(`paper_baseline') ypost(`paper_outcome') takeup(`paper_takeup') treatment(`paper_treatment') controls(`paper_controls') weight(`paper_weight') ifcond(`paper_if_cond') cluster(`paper_cluster') options(`paper_options')

* Bootstrap bias for DID
bootstrap bias = r(bias), rep(100) cluster(`paper_cluster') nodrop : did_bias, ypre(`paper_baseline') ypost(`paper_outcome') takeup(`paper_takeup') treatment(`paper_treatment') controls(`paper_controls') weight(`paper_weight') ifcond(`paper_if_cond') cluster(`paper_cluster') options(`paper_options')

scalar didbias = _b["bias"]
scalar didbiasse = _se["bias"]

*Bootstrap bias for DIM
bootstrap bias = r(bias), rep(100) cluster(`paper_cluster') nodrop : dim_bias, ypre(`paper_baseline') ypost(`paper_outcome') takeup(`paper_takeup') treatment(`paper_treatment') controls(`paper_controls') weight(`paper_weight') ifcond(`paper_if_cond') cluster(`paper_cluster') options(`paper_options')

scalar dimbias = _b["bias"]
scalar dimbiasse = _se["bias"]

*Bootstrap bias for LDV
bootstrap bias = r(bias), rep(100) cluster(`paper_cluster') nodrop : ldv_bias, ypre(`paper_baseline') ypost(`paper_outcome') takeup(`paper_takeup') treatment(`paper_treatment') controls(`paper_controls') weight(`paper_weight') ifcond(`paper_if_cond') cluster(`paper_cluster') options(`paper_options')

scalar ldvbias = _b["bias"]
scalar ldvbiasse = _se["bias"]

*Write results into CSV file
file open myfile using bias_results.csv, write replace
*file write myfile "variable, tsls, did, dim, ldv" _n
file write myfile "estimate," %6.3f (tsls) "," %6.3f (didbias) "," %6.3f (dimbias) "," %6.3f (ldvbias) _n
file write myfile "se," %6.3f (tslsse) "," %6.3f (didbiasse) "," %6.3f (dimbiasse) "," %6.3f (ldvbiasse) _n
file close myfile



** SEs for hypothetical DID 
cap drop y_diff 
cap drop y_diff_d
cap drop y_diff2
cap drop y_diff2_d

gen y_diff = `paper_outcome' - `paper_baseline' // create variable for \Delta Y
gen y_diff_d = `paper_takeup' * y_diff // \Delta Y * D
gen y_diff2 = y_diff^2 // create variable for (\Delta Y)^2
gen y_diff2_d = `paper_takeup' * y_diff2 // (\Delta Y)^2 * Ds

*Estimate of E[\DeltaY(1)^2 | Compliers]
ivreg2 y_diff2_d (`paper_takeup' = `paper_treatment')
local y_diff2_mean_c = _b[`paper_takeup']

*Estimate of E[\DeltaY(1) | Compliers]
ivreg2 y_diff_d (`paper_takeup' = `paper_treatment')
local y_diff_mean_c = _b[`paper_takeup']
local y_diff_se_c = _se[`paper_takeup']

local y_diff_var_c = `y_diff2_mean_c' - (`y_diff_mean_c'^2 - `y_diff_se_c'^2)
disp `y_diff2_mean_c'
disp `y_diff_var_c'

if("`paper_ifcond'" == ""){
	local nt_if_cond "if `paper_treatment' == 1 & `paper_takeup' == 0"
	}
	else{
	local nt_if_cond "if `ifcond' & `paper_treatment' == 1 & `paper_takeup' == 0"
	}
	
reg y_diff2 `nt_if_cond'
local y_diff2_mean_nt = _b["_cons"] 

reg y_diff `nt_if_cond'
local y_diff_mean_nt = _b["_cons"]
local y_diff_se_nt = _se["_cons"]
local y_diff_var_nt = `y_diff2_mean_nt' - (`y_diff_mean_nt'^2 - `y_diff_se_nt'^2)

reg `paper_takeup' `paper_treatment'
local share_c = _b["treatment"]
local share_at = _b["_cons"]
local share_nt = 1 - `share_c' - `share_at'

count if `paper_treatment' == 1
local n_treated = r(N)

count
local n_total = r(N) 

local se_hyp_did_treated = ( sqrt( `y_diff_var_c' / `share_c' + `y_diff_var_nt' / `share_nt' ) / sqrt(`n_treated') ) // SE assuming N is treated arm N



local se_hyp_did_all = `se_hyp_did_treated' * sqrt(`n_treated') / sqrt(`n_total') // SE assuming N is total experiment N

disp ( "`se_hyp_did_treated'" )
disp ( "`se_hyp_did_all'" )

*compare to actual DID in treated group that includes ATs
reg y_diff `paper_takeup' if `paper_treatment' ==1, r

log close
