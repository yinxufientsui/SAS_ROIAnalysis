/* Build daily modeling data by channel */
proc fedsql sessref=mysess;
  create table casuser.daily_ch as
  select
    date,
    channel,
    sum(spend)   as spend,
    sum(revenue) as revenue
  from casuser.fact_agg
  group by date, channel;
quit;

/* Prepare for regression (log transforms) */
data work.daily_ch;
  set casuser.daily_ch;
  log_spend = log(spend + 1);
  log_rev   = log(revenue + 1);
run;

/* Fit a separate log-log regression per channel */
proc sort data=work.daily_ch;
  by channel;
run;

proc reg data=work.daily_ch outest=work.chan_model noprint;
  by channel;
  model log_rev = log_spend;
run;
quit;

/* Keep only parameter rows and rename */
data work.chan_model;
  set work.chan_model;
  where _TYPE_ = 'PARMS';
  keep channel Intercept log_spend;
  rename Intercept = beta0
         log_spend = beta1;
run;

/* Join ML model with smart-simulated spends */
proc sql;
  create table work.budget_sim_ml as
  select
    s.scenario,
    s.channel,
    s.new_spend,
    s.new_revenue as roi_based_revenue,   /* from constant-ROI sim  */
    m.beta0,
    m.beta1
  from work.budget_sim_upg as s
  left join work.chan_model as m
    on upcase(s.channel) = upcase(m.channel);
quit;

/* Predict revenue using the learned response curve */
data work.budget_sim_ml;
  set work.budget_sim_ml;

  if new_spend < 0 then new_spend = 0;

  /* If we have a model, use it; otherwise fall back to ROI */
  if not missing(beta0) and not missing(beta1) then do;
    pred_log_rev = beta0 + beta1 * log(new_spend + 1);
    ml_revenue   = exp(pred_log_rev) - 1;
  end;
  else ml_revenue = roi_based_revenue;
run;

/* Aggregate ML predictions to scenario level */
proc sql;
  create table casuser.budget_summary_ml as
  select
    scenario,
    sum(new_spend)     as total_spend,
    sum(ml_revenue)    as total_revenue_ml,
    sum(roi_based_revenue) as total_revenue_roi,
    sum(ml_revenue) / sum(new_spend)      as overall_roi_ml,
    sum(roi_based_revenue) / sum(new_spend) as overall_roi_const
  from work.budget_sim_ml
  group by scenario;
quit;


/* Summary table */
proc print data=casuser.budget_summary_ml noobs;
  format total_spend       dollar14.2
         total_revenue_ml  dollar14.2
         total_revenue_roi dollar14.2
         overall_roi_ml    8.2
         overall_roi_const 8.2;
run;

/* Single-bar chart for ML-based ROI */
title "Baseline vs Smart Reallocation: Overall ROI (ML-based)";
proc sgplot data=casuser.budget_summary_ml;
  vbar scenario / response=overall_roi_ml datalabel;
  yaxis label="Overall ROI (Revenue / Spend, ML model)" grid;
run;
title;

/* side-by-side comparison of ML vs Constant ROI */
data work.roi_long;
  set casuser.budget_summary_ml;
  length metric $20;
  metric = "ML-based ROI";       value = overall_roi_ml;    output;
  metric = "Constant ROI";       value = overall_roi_const; output;
run;

title "Overall ROI by Scenario: ML vs Constant ROI";
proc sgplot data=work.roi_long;
  vbar scenario / response=value group=metric groupdisplay=cluster datalabel;
  yaxis label="Overall ROI" grid;
  keylegend / title="ROI Metric";
run;
title;