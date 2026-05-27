* Title:    BetterDDwithIV/event_study_bias.do
* Blame:    William Cox <wcox@williamandrewcox.com>
* Created:  12 June 2025
* Purpose:  Runs an "event study" of bias in DiD using event study
*           data of OHIE experiment
* Note:     Run via `nohup stata-mp -b do BetterDDwithIV/event_study_bias.do &`

capture log close _all

log using "output/event_study_bias.log", replace

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
    gen y_diff = (`ypost' - `ypre') * 1000
    
    c_nt_diff, y(y_diff) takeup(`takeup') treatment(`treatment') controls(`controls') weight(`weight') ifcond(`ifcond') cluster(`cluster') options(`options')

    return scalar bias = r(diff)

end

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

cap program drop did_c_mean
program did_c_mean, rclass
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
    gen y_diff = (`ypost' - `ypre') * 1000


    cap drop y_contemp
    gen y_contemp = `ypost' * 1000

    cap drop y_dm1
    gen y_dm1 = (`takeup'-1)* y_contemp
    
    if("`ifcond'" == ""){
    local nt_if_cond "if `treatment' == 1 & `takeup' == 0"
    }
else{
    local nt_if_cond "if `ifcond' & `treatment' == 1 & `takeup' == 0"
}

    ivreg2 y_dm1 (`takeup' = `treatment') ///
        `controls' `weight' `ifcond', ///
        cluster(`cluster') `options' 
    scalar comp_mean = _b[`takeup']
    reg y_contemp `nt_if_cond'
    scalar nt_mean = _b["_cons"] 
    return scalar c_mean = comp_mean
end

cap program drop did_nt_mean
program did_nt_mean, rclass
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
    gen y_diff = (`ypost' - `ypre') * 1000

    cap drop y_contemp
    gen y_contemp = `ypost' * 1000

    cap drop y_dm1
    gen y_dm1 = (`takeup'-1)* y_contemp
    
    if("`ifcond'" == ""){
    local nt_if_cond "if `treatment' == 1 & `takeup' == 0"
    }
else{
    local nt_if_cond "if `ifcond' & `treatment' == 1 & `takeup' == 0"
}

    ivreg2 y_dm1 (`takeup' = `treatment') ///
        `controls' `weight' `ifcond', ///
        cluster(`cluster') `options' 
    scalar comp_mean = _b[`takeup']
    reg y_contemp `nt_if_cond'
    scalar never_takers_mean = _b["_cons"] 
    return scalar nt_mean = never_takers_mean
end

cap program drop event_study_did_bias
program event_study_did_bias
    syntax,

    set seed 858611415

    use /disk/store1a/oregon/millers/Criminalcharges/Data/individual_crime_data.dta, clear

    keep if numhh_list == 1

    * Original DiD Bias
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

    bootstrap bias = r(bias), rep(100) cluster(`paper_cluster') nodrop : did_bias, ypre(`paper_baseline') ypost(`paper_outcome') takeup(`paper_takeup') treatment(`paper_treatment') controls(`paper_controls') weight(`paper_weight') ifcond(`paper_if_cond') cluster(`paper_cluster') options(`paper_options')

    scalar didbias = _b["bias"]
    scalar didbiasse = _se["bias"]

    display didbias
    display didbiasse

    bootstrap c_mean = r(c_mean), rep(100) cluster(`paper_cluster') nodrop : did_c_mean, ypre(`paper_baseline') ypost(`paper_outcome') takeup(`paper_takeup') treatment(`paper_treatment') controls(`paper_controls') weight(`paper_weight') ifcond(`paper_if_cond') cluster(`paper_cluster') options(`paper_options')

    scalar didcmean = _b["c_mean"]
    scalar didcmeanse = _se["c_mean"]

    display didcmean
    display didcmeanse

    bootstrap nt_mean = r(nt_mean), rep(100) cluster(`paper_cluster') nodrop : did_nt_mean, ypre(`paper_baseline') ypost(`paper_outcome') takeup(`paper_takeup') treatment(`paper_treatment') controls(`paper_controls') weight(`paper_weight') ifcond(`paper_if_cond') cluster(`paper_cluster') options(`paper_options')

    scalar didntmean = _b["nt_mean"]
    scalar didntmeanse = _se["nt_mean"]

    display didntmean
    display didntmeanse


    * Monthly DiD bias
    merge 1:1 res_person_id using ///
        "cleaned_data/monthly_crime_stats_wide.dta", ///
        gen(wide_merge) keepusing(case_month_* tot_charge_month_m1)

    keep if wide_merge == 3

    local paper_baseline case_month_m1
    local paper_controls nnn* tot_charge_month_m1
    forval i = 14(-1)2{

        di("m`i'")
        local paper_outcome case_month_m`i'

        bootstrap bias = r(bias), rep(100) cluster(`paper_cluster') nodrop : did_bias, ypre(`paper_baseline') ypost(`paper_outcome') takeup(`paper_takeup') treatment(`paper_treatment') controls(`paper_controls') weight(`paper_weight') ifcond(`paper_if_cond') cluster(`paper_cluster') options(`paper_options')

        scalar didbias_m`i' = _b["bias"]
        scalar didbiasse_m`i' = _se["bias"]

        bootstrap c_mean = r(c_mean), rep(100) cluster(`paper_cluster') nodrop : did_c_mean, ypre(`paper_baseline') ypost(`paper_outcome') takeup(`paper_takeup') treatment(`paper_treatment') controls(`paper_controls') weight(`paper_weight') ifcond(`paper_if_cond') cluster(`paper_cluster') options(`paper_options')

        scalar c_mean_m`i' = _b["c_mean"]
        scalar c_meanse_m`i' = _se["c_mean"]

        bootstrap nt_mean = r(nt_mean), rep(100) cluster(`paper_cluster') nodrop : did_nt_mean, ypre(`paper_baseline') ypost(`paper_outcome') takeup(`paper_takeup') treatment(`paper_treatment') controls(`paper_controls') weight(`paper_weight') ifcond(`paper_if_cond') cluster(`paper_cluster') options(`paper_options')

        scalar nt_mean_m`i' = _b["nt_mean"]
        scalar nt_meanse_m`i' = _se["nt_mean"]
    }

    forval i = 0/33{
        di("`i'")
        local paper_outcome case_month_`i'
        
        bootstrap bias = r(bias), rep(100) cluster(`paper_cluster') nodrop : did_bias, ypre(`paper_baseline') ypost(`paper_outcome') takeup(`paper_takeup') treatment(`paper_treatment') controls(`paper_controls') weight(`paper_weight') ifcond(`paper_if_cond') cluster(`paper_cluster') options(`paper_options')

        scalar didbias_`i' = _b["bias"]
        scalar didbiasse_`i' = _se["bias"]

        bootstrap c_mean = r(c_mean), rep(100) cluster(`paper_cluster') nodrop : did_c_mean, ypre(`paper_baseline') ypost(`paper_outcome') takeup(`paper_takeup') treatment(`paper_treatment') controls(`paper_controls') weight(`paper_weight') ifcond(`paper_if_cond') cluster(`paper_cluster') options(`paper_options')

        scalar c_mean_`i' = _b["c_mean"]
        scalar c_meanse_`i' = _se["c_mean"]

        bootstrap nt_mean = r(nt_mean), rep(100) cluster(`paper_cluster') nodrop : did_nt_mean, ypre(`paper_baseline') ypost(`paper_outcome') takeup(`paper_takeup') treatment(`paper_treatment') controls(`paper_controls') weight(`paper_weight') ifcond(`paper_if_cond') cluster(`paper_cluster') options(`paper_options')

        scalar nt_mean_`i' = _b["nt_mean"]
        scalar nt_meanse_`i' = _se["nt_mean"]
    }

    file open myfile using BetterDDwithIV_event_study.csv, write replace
    
    file write myfile "Month," "Bias," "Bias SE," "C Mean," "C SE," "NT Mean," "NT SE" _n

    forval i = 14(-1)2 {
        di("m`i'")
        local month = -1 * `i'
        file write myfile "`month'," %6.3f (didbias_m`i') "," %6.3f (didbiasse_m`i') "," %6.3f (c_mean_m`i') "," %6.3f (c_meanse_m`i') "," %6.3f (nt_mean_m`i') "," %6.3f (nt_meanse_m`i') _n
    }

    forval i = 0/33 {
        di("`i'")
        local month = `i'
        file write myfile "`i'," %6.3f (didbias_`i') "," %6.3f (didbiasse_`i') "," %6.3f (c_mean_`i') "," %6.3f (c_meanse_`i') "," %6.3f (nt_mean_`i') "," %6.3f (nt_meanse_`i') _n
    }

    file close myfile



end

cap program drop event_study_did_bias_period
program event_study_did_bias_period
    syntax,

    set seed 362836536

    use /disk/store1a/oregon/millers/Criminalcharges/Data/individual_crime_data.dta, clear

    keep if numhh_list == 1

    * Original DiD Bias
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

    bootstrap bias = r(bias), rep(100) cluster(`paper_cluster') nodrop : did_bias, ypre(`paper_baseline') ypost(`paper_outcome') takeup(`paper_takeup') treatment(`paper_treatment') controls(`paper_controls') weight(`paper_weight') ifcond(`paper_if_cond') cluster(`paper_cluster') options(`paper_options')

    scalar didbias = _b["bias"]
    scalar didbiasse = _se["bias"]

    display didbias
    display didbiasse

    bootstrap c_mean = r(c_mean), rep(100) cluster(`paper_cluster') nodrop : did_c_mean, ypre(`paper_baseline') ypost(`paper_outcome') takeup(`paper_takeup') treatment(`paper_treatment') controls(`paper_controls') weight(`paper_weight') ifcond(`paper_if_cond') cluster(`paper_cluster') options(`paper_options')

    scalar didcmean = _b["c_mean"]
    scalar didcmeanse = _se["c_mean"]

    display didcmean
    display didcmeanse

    bootstrap nt_mean = r(nt_mean), rep(100) cluster(`paper_cluster') nodrop : did_nt_mean, ypre(`paper_baseline') ypost(`paper_outcome') takeup(`paper_takeup') treatment(`paper_treatment') controls(`paper_controls') weight(`paper_weight') ifcond(`paper_if_cond') cluster(`paper_cluster') options(`paper_options')

    scalar didntmean = _b["nt_mean"]
    scalar didntmeanse = _se["nt_mean"]

    display didntmean
    display didntmeanse


    * Monthly DiD bias
    merge 1:1 res_person_id using ///
        "cleaned_data/monthly_crime_stats_wide.dta", ///
        gen(wide_merge) keepusing(case_month_* tot_charge_month_m*)

    keep if wide_merge == 3



    **********************************************
    *               6 month period               *
    **********************************************

    scalar drop _all

    * Generate controls
    gen tot_charge_period_m1 = 0
    forval i = 1/6{
        replace tot_charge_period_m1 = tot_charge_period_m1 + tot_charge_month_m`i'
    }

    * Generate periods
    forval i = 1/3 {
        gen case_period_m`i' = 0
        local begin_period = `i' * -6
        local end_period = `begin_period' + 5

        forval j = `begin_period'/`end_period' {
            local m_month = `j' * -1
            if `m_month' <= 14 {
                replace case_period_m`i' = 1 if case_month_m`m_month' == 1
            }
        }
    }

    forval i = 0/5 {
        gen case_period_`i' = 0
        local begin_period = `i' * 6
        local end_period = `begin_period' + 5

        forval j = `begin_period'/`end_period' {
            if `j' <= 33 {
                replace case_period_`i' = 1 if case_month_`j' == 1
            }
        }
    }

    save "cleaned_data/BetterDDwithIV_event_study_periods.dta", replace

    * Generate event study results (6 month periods)

    local paper_baseline case_period_m1
    local paper_controls nnn* tot_charge_period_m1

    forval i = 3(-1)2{

        di("m`i'")
        local paper_outcome case_period_m`i'

        bootstrap bias = r(bias), rep(100) cluster(`paper_cluster') nodrop : did_bias, ypre(`paper_baseline') ypost(`paper_outcome') takeup(`paper_takeup') treatment(`paper_treatment') controls(`paper_controls') weight(`paper_weight') ifcond(`paper_if_cond') cluster(`paper_cluster') options(`paper_options')

        scalar didbias_m`i' = _b["bias"]
        scalar didbiasse_m`i' = _se["bias"]

        bootstrap c_mean = r(c_mean), rep(100) cluster(`paper_cluster') nodrop : did_c_mean, ypre(`paper_baseline') ypost(`paper_outcome') takeup(`paper_takeup') treatment(`paper_treatment') controls(`paper_controls') weight(`paper_weight') ifcond(`paper_if_cond') cluster(`paper_cluster') options(`paper_options')

        scalar c_mean_m`i' = _b["c_mean"]
        scalar c_meanse_m`i' = _se["c_mean"]

        bootstrap nt_mean = r(nt_mean), rep(100) cluster(`paper_cluster') nodrop : did_nt_mean, ypre(`paper_baseline') ypost(`paper_outcome') takeup(`paper_takeup') treatment(`paper_treatment') controls(`paper_controls') weight(`paper_weight') ifcond(`paper_if_cond') cluster(`paper_cluster') options(`paper_options')

        scalar nt_mean_m`i' = _b["nt_mean"]
        scalar nt_meanse_m`i' = _se["nt_mean"]

    }

    forval i = 0/5 {

        di("`i'")
        local paper_outcome case_period_`i'

        bootstrap bias = r(bias), rep(100) cluster(`paper_cluster') nodrop : did_bias, ypre(`paper_baseline') ypost(`paper_outcome') takeup(`paper_takeup') treatment(`paper_treatment') controls(`paper_controls') weight(`paper_weight') ifcond(`paper_if_cond') cluster(`paper_cluster') options(`paper_options')

        scalar didbias_`i' = _b["bias"]
        scalar didbiasse_`i' = _se["bias"]

        bootstrap c_mean = r(c_mean), rep(100) cluster(`paper_cluster') nodrop : did_c_mean, ypre(`paper_baseline') ypost(`paper_outcome') takeup(`paper_takeup') treatment(`paper_treatment') controls(`paper_controls') weight(`paper_weight') ifcond(`paper_if_cond') cluster(`paper_cluster') options(`paper_options')

        scalar c_mean_`i' = _b["c_mean"]
        scalar c_meanse_`i' = _se["c_mean"]

        bootstrap nt_mean = r(nt_mean), rep(100) cluster(`paper_cluster') nodrop : did_nt_mean, ypre(`paper_baseline') ypost(`paper_outcome') takeup(`paper_takeup') treatment(`paper_treatment') controls(`paper_controls') weight(`paper_weight') ifcond(`paper_if_cond') cluster(`paper_cluster') options(`paper_options')

        scalar nt_mean_`i' = _b["nt_mean"]
        scalar nt_meanse_`i' = _se["nt_mean"]

    }

    file open myfile using BetterDDwithIV_event_study_period.csv, write replace
    
    file write myfile "Period," "Bias," "Bias SE," "C Mean," "C SE," "NT Mean," "NT SE" _n

    forval i = 3(-1)2 {
        di("m`i'")
        local period = -1 * `i'
        file write myfile "`period'," %6.3f (didbias_m`i') "," %6.3f (didbiasse_m`i') "," %6.3f (c_mean_m`i') "," %6.3f (c_meanse_m`i') "," %6.3f (nt_mean_m`i') "," %6.3f (nt_meanse_m`i') _n
    }

    forval i = 0/5 {
        di("`i'")
        local period = `i'
        file write myfile "`i'," %6.3f (didbias_`i') "," %6.3f (didbiasse_`i') "," %6.3f (c_mean_`i') "," %6.3f (c_meanse_`i') "," %6.3f (nt_mean_`i') "," %6.3f (nt_meanse_`i') _n
    }

    file close myfile



end

cap program drop main
program main
    syntax, [CAPture NOIsily]

    local progname  ohie_analysis/BetterDDwithIV
        disp  "Program: `progname'"
        disp  "Start:   $S_TIME $S_DATE"
        local start_time $S_TIME $S_DATE

    *event_study_did_bias
    event_study_did_bias_period

    local rc = _rc

    disp "Program: `progname'"
    disp "End:     $S_TIME $S_DATE"
    disp "Status:  `rc'"

    mail_notify, `capture' rc(`rc') ///
        progname(`progname')        ///
        start_time(`start_time')    ///
        email(`:env LOGNAME'@nber.org)
    exit `rc'

end

main, cap noi

log close

