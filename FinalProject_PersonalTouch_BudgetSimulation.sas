/* Read from previous ROI and attribution from the ROI Analysis */
data work.chan_perf;
  merge casuser.roi_by_channel(in=a)
        casuser.attr_by_channel(in=b);
  by channel;
  if a;  /* keep only channels present in roi_by_channel */
  if spend > 0 then roi = revenue / spend;
run;

/* Split into donors (negative lift) and receivers (positive lift) */
data work.donors work.receivers;
  set work.chan_perf;
  if lift_vs_spend_share < 0 then output work.donors;
  else if lift_vs_spend_share > 0 then output work.receivers;
run;

/* Compute total donor spend and total positive lift */
proc sql noprint;
  select sum(spend) into :TOT_DONOR
  from work.donors;

  select sum(lift_vs_spend_share) into :TOT_LIFT_POS
  from work.receivers
  where lift_vs_spend_share > 0;
quit;

%put NOTE: TOT_DONOR=&TOT_DONOR TOT_LIFT_POS=&TOT_LIFT_POS;

/* Percentage of donor spend to shift */
%let SHIFT_PCT = 0.05;
%let TOTAL_SHIFT = %sysevalf(&TOT_DONOR * &SHIFT_PCT);

/* Build baseline + scenario new_spend per channel */
data work.budget_sim_upg;
  set work.chan_perf(in=base)
      work.chan_perf(in=sc1);
  length scenario $40;
  retain shift_pct  &SHIFT_PCT
         total_shift &TOTAL_SHIFT
         tot_lift_pos &TOT_LIFT_POS;

  if base then scenario = 'Baseline';
  else if sc1 then scenario = 'SmartRealloc_5pct';

  /* Baseline: keep original spend */
  if scenario = 'Baseline' then new_spend = spend;
  else do;
    /* Donor channels: cut SHIFT_PCT of spend */
    if lift_vs_spend_share < 0 then
      new_spend = spend * (1 - shift_pct);

    /* Receiver channels: add share of TOTAL_SHIFT
       proportional to positive lift_vs_spend_share */
    else if lift_vs_spend_share > 0 and tot_lift_pos > 0 then do;
      alloc_share = lift_vs_spend_share / tot_lift_pos;
      new_spend = spend + total_shift * alloc_share;
    end;

    /* Neutral channels (exactly zero lift) – unchanged */
    else new_spend = spend;
  end;

  if new_spend < 0 then new_spend = 0;

  /* Assume per-channel ROI stays constant for small shifts */
  new_revenue = new_spend * roi;
run;

/* Scenario-level totals and overall ROI */
proc sql;
  create table casuser.budget_summary_upg as
  select scenario,
         sum(new_spend)   as total_spend,
         sum(new_revenue) as total_revenue,
         calculated total_revenue / calculated total_spend as overall_roi
  from work.budget_sim_upg
  group by scenario;
quit;

/* Visualization */
proc print data=casuser.budget_summary_upg noobs;
  format total_spend total_revenue dollar14.2 overall_roi 8.2;
run;

title "Baseline vs Smart Reallocation: Overall ROI";
proc sgplot data=casuser.budget_summary_upg;
  vbar scenario / response=overall_roi datalabel;
  yaxis label="Overall ROI (Revenue / Spend)" grid;
run;
title;