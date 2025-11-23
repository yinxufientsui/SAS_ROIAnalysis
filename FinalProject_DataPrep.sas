options nonotes fullstimer;

/* CAS + CASUSER lib */
cas mySess;
libname casuser cas;
caslib _all_ assign;

/* CSV path */
%let INFILE = /export/viya/homes/yxu4723@monroeu.edu/casuser/cleanroom_fact.csv;

%put NOTE: INFILE=&INFILE;
%put NOTE: FILE EXISTS? %sysfunc(fileexist(&INFILE));

/* Import CSV -> WORK.FACT_RAW */
proc import datafile="&INFILE"
  dbms=csv
  out=work.fact_raw
  replace;
  guessingrows=max;
run;

proc contents data=work.fact_raw; run;

/* Clean dates + enforce non-negatives */
data work.fact_clean;
  set work.fact_raw;

  /* date: from "YYYY-MM-DD" to SAS date */
  length date_sas 8;
  format date_sas yymmdd10.;
  date_sas = input(strip(date), yymmdd10.);
  if date_sas = . then do;
    put "WARN: Invalid date encountered: " date=;
  end;


  /* non-negative numeric metrics */
  array mtrs spend imps clicks conversions add_to_cart revenue;
  do _i_ = 1 to dim(mtrs);
    if mtrs[_i_] < 0 then do;
        put "WARN: Negative value corrected: " mtrs[_i_]=;
        mtrs[_i_] = 0;
    end;
  end;
  drop _i_;

/* For iteration need to drop the table */
proc casutil;
  droptable incaslib="casuser" casdata="fact_agg" quiet;
quit;

/* Create KPIs + time variables directly in CAS */
data casuser.fact_agg;
  set work.fact_clean;

  /* time dims */
  month = month(date);         
  dow   = weekday(date);        

  /* KPIs */
  if imps > 0 then ctr = clicks / imps;
  else ctr = .;

  if clicks > 0 then cpc = spend / clicks;
  else cpc = .;

  if conversions > 0 then cpa = spend / conversions;
  else cpa = .;

  if spend > 0 then roi = revenue / spend;
  else roi = .;
run;

/* Confirm CAS table exists */
proc contents data=casuser.fact_agg; run;

/* Sanity check */
proc means data=casuser.fact_agg n mean p25 p50 p75 max min;
  var spend imps clicks conversions add_to_cart revenue
      ctr cpc cpa roi;
run;

proc freq data=casuser.fact_agg;
  tables channel campaign month dow / nocum nopercent;
run;

proc univariate data=casuser.fact_agg noprint;
  var spend imps clicks conversions revenue;
  output out=casuser.fact_agg_outliers
    pctlpts = 1 5 95 99
    pctlpre = spend_ imps_ clicks_ conv_ revenue_;
run;