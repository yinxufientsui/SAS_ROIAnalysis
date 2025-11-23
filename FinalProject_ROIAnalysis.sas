options nonotes fullstimer;

/* CAS session & library */
cas mySess;
libname casuser cas;
caslib _all_ assign;

/* Drop old result tables if they exist */
proc casutil;
  droptable incaslib="casuser" casdata="roi_by_channel"       quiet;
  droptable incaslib="casuser" casdata="roi_by_campaign"      quiet;
  droptable incaslib="casuser" casdata="roi_by_month_channel" quiet;
  droptable incaslib="casuser" casdata="attr_by_channel"      quiet;
quit;

/* Channel-level ROI */
proc fedsql sessref=mySess;
  create table casuser.roi_by_channel as
  select
    channel,
    sum(spend)        as spend,
    sum(imps)         as imps,
    sum(clicks)       as clicks,
    sum(conversions)  as conversions,
    sum(revenue)      as revenue,
    case when sum(imps)        > 0 then sum(clicks)      / sum(imps)        end as ctr,
    case when sum(clicks)      > 0 then sum(spend)       / sum(clicks)      end as cpc,
    case when sum(conversions) > 0 then sum(spend)       / sum(conversions) end as cpa,
    case when sum(spend)       > 0 then sum(revenue)     / sum(spend)       end as roi
  from casuser.fact_agg
  group by channel;
quit;

/* Campaign-level ROI */
proc fedsql sessref=mySess;
  create table casuser.roi_by_campaign as
  select
    channel,
    campaign,
    sum(spend)        as spend,
    sum(imps)         as imps,
    sum(clicks)       as clicks,
    sum(conversions)  as conversions,
    sum(revenue)      as revenue,
    case when sum(imps)        > 0 then sum(clicks)      / sum(imps)        end as ctr,
    case when sum(clicks)      > 0 then sum(spend)       / sum(clicks)      end as cpc,
    case when sum(conversions) > 0 then sum(spend)       / sum(conversions) end as cpa,
    case when sum(spend)       > 0 then sum(revenue)     / sum(spend)       end as roi
  from casuser.fact_agg
  group by channel, campaign;
quit;

/* Month x Channel ROI trend */
proc fedsql sessref=mySess;
  create table casuser.roi_by_month_channel as
  select
    month,
    channel,
    sum(spend)   as spend,
    sum(revenue) as revenue,
    case when sum(spend) > 0 then sum(revenue)/sum(spend) end as roi
  from casuser.fact_agg
  group by month, channel;
quit;



/* Get total spend and total revenue across all channels */
proc sql noprint;
  select sum(spend), sum(revenue)
    into :TOT_SPEND, :TOT_REV
  from casuser.roi_by_channel;
quit;


/* Compute shares and lift in CAS */
data casuser.attr_by_channel;
  set casuser.roi_by_channel;

  /* spend & revenue share*/
  if &TOT_SPEND > 0 then spend_share   = spend   / &TOT_SPEND;
  else spend_share = .;

  if &TOT_REV   > 0 then revenue_share = revenue / &TOT_REV;
  else revenue_share = .;

  /* lift vs spend share */
  if n(spend_share, revenue_share) = 2 then
    lift_vs_spend_share = revenue_share - spend_share;
  else lift_vs_spend_share = .;
run;