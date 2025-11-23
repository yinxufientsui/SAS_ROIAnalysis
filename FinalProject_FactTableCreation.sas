%let INFILE = /export/viya/homes/yxu4723@monroeu.edu/casuser/cleanroom_fact.csv;  

%put NOTE: INFILE=&INFILE;
%put NOTE: FILE EXISTS? %sysfunc(fileexist(&INFILE));


/* Import the CSV to WORK */
proc import datafile="&INFILE"
  dbms=csv
  out=work.fact_raw
  replace;
  guessingrows=max;
run;

proc contents data=work.fact_raw; run;  /* should list your variables */

/* Create FACT_CLEAN in WORK and then FACT_AGG in CASUSER */
data work.fact_clean;
  set work.fact_raw;
  length date_sas 8;
  format date_sas yymmdd10.;
  date_sas = input(strip(date), yymmdd10.);
  if date_sas = . then put "WARN: bad date " date=;
  drop date;
  rename date_sas = date;
run;

cas mySess;
libname casuser cas;
caslib _all_ assign;

data casuser.fact_agg;
  set work.fact_clean;
run;

proc contents data=casuser.fact_agg; run;   /* this must work before PROC MEANS */