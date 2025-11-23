

options nonotes;
cas mySess;
libname casuser cas;
caslib _all_ assign;

/* ROI by Channel */
title "Overall ROI by Channel";
proc sgplot data=casuser.roi_by_channel;
  vbar channel / response=roi datalabel;
  yaxis label="ROI (Revenue / Spend)" grid;
  xaxis discreteorder=data;
run;

/* Revenue vs Spend by Channel */
title "Total Spend vs Revenue by Channel";
proc sgplot data=casuser.roi_by_channel;
  vbarparm category=channel response=spend   / transparency=0.3;
  vbarparm category=channel response=revenue / transparency=0.5;
  yaxis label="USD" grid;
run;

/* Monthly ROI trends by Channel */
title "Monthly ROI by Channel";
proc sgplot data=casuser.roi_by_month_channel;
  series x=month y=roi / group=channel markers;
  xaxis integer label="Month";
  yaxis grid label="ROI";
run;

/* Attribution-style lift vs spend share */
title "Lift vs Spend Share by Channel";
proc sgplot data=casuser.attr_by_channel;
  vbar channel / response=lift_vs_spend_share datalabel;
  refline 0 / axis=y;
  yaxis grid label="Revenue Share - Spend Share";
run;

title;
footnote;