library(sqldf)
library(dplyr)

conv_info<-read.csv("c:\\users\\david\\OneDrive - University of Texas at Arlington\\latency\\conv_info.csv", header=TRUE)
ptcp_info<-read.csv("c:\\users\\david\\OneDrive - University of Texas at Arlington\\latency\\ptcp_info.csv", header=TRUE)
trans_raw <-read.csv("c:\\users\\david\\OneDrive - University of Texas at Arlington\\latency\\trans.csv", header=TRUE)
ltnc_start_end <-read.csv("c:\\users\\david\\OneDrive - University of Texas at Arlington\\latency\\ltnc_start_end.csv", header=TRUE)

ptcp_info <- sqldf("
 select *, row_number() over (partition by conv order by \"Response.ID\") rn
  from ptcp_info
")

all_conv_ptcp_wide <- sqldf("
 select a.conv, a.date, a.exclude, a.language, a.latency/1000 latency, 
   b.native_lang native_lang1, b.age age1, b.gender gender1, b.call_freq call_freq1, b.closeness closeness1, 
   b.feel_pre feel_pre1, b.feel_post feel_post1, b.conv_rating conv_rating1,
   c.native_lang native_lang2, c.age age2, c.gender gender2, c.call_freq call_freq2, c.closeness closeness2, 
   c.feel_pre feel_pre2, c.feel_post feel_post2, c.conv_rating conv_rating2
  from conv_info a
   join ptcp_info b
    on b.conv = a.conv and b.rn = 1
   join ptcp_info c
    on c.conv = a.conv and c.rn = 2
")

all_conv_ptcp_long <- sqldf("
 select a.conv, a.date, a.exclude, a.language, a.latency/1000 latency,
   b.rn, b.native_lang, b.age, b.gender, b.call_freq, b.closeness, b.feel_pre, b.feel_post, b.conv_rating 
  from conv_info a
   join ptcp_info b
    on b.conv = a.conv 
")
all_conv_ptcp_long$feel_diff <- all_conv_ptcp_long$feel_post - all_conv_ptcp_long$feel_pre

all_conv <- sqldf("
  select a.params, a.conv, b.language, b.latency/1000.0 ltnc_ms, b.latency/1000000.0 ltnc_s,
     b.date, b.exclude,
     count(1) trans_cnt, 
     min(a.gap) min_gap,
     max(a.gap) max_gap,
     max(a.end_sound) max_end,
     sum(case when a.gap < 0 then 1 else 0 end) overlap_cnt, 
     sum(case when a.gap < 0 then abs(a.gap) else 0 end) overlap_dur,
     --sum(case when a.gap > 3.5 then 3.5 when a.gap > 0 then a.gap else 0 end) gap_dur,
     sum(case when a.gap > 0 then a.gap else 0 end) gap_dur,
     sum(case when a.gap > 0 then 1 else 0 end) gap_cnt,
     --avg(case when a.gap > 3.5 then 3.5 else a.gap end) mean_gap,
     sum(case when a.gap = 0 then 1 else 0 end) zero_cnt,
     c.conv_resume, c.ltnc_start, c.ltnc_end
   from trans_raw a
     join conv_info b
       on a.conv = b.conv
     join ltnc_start_end c
       on c.conv = b.conv
   where a.params = '_30_200_1.25'
  group by a.params, a.conv 
")
all_conv$overlap_trans_ratio<-all_conv$overlap_cnt/all_conv$trans_cnt

conv <- sqldf("
  select *,
    case
     when ltnc_ms < 100 then '0-100'
     when ltnc_ms < 200 then '100-200'
     when ltnc_ms < 300 then '200-300'
     when ltnc_ms < 400 then '300-400'
     else '400-500'
    end ltnc_cat,
    case
     when ltnc_ms < 167 then 'Low latency'
     when ltnc_ms < 333 then 'Med. latency'
     else 'High latency'
    end ltnc_cat2,
    case
     when ltnc_ms < 220 then 'low'
     else 'high'
    end ltnc_cat3
   from all_conv
   where exclude = ''
")
#conv$params <- as.factor(conv$params)
conv$ltnc_cat2<-factor(conv$ltnc_cat2,levels=c('Low latency','Med. latency','High latency'))

nrow(trans_raw)

trans <- sqldf("
  select a.params, a.conv, a.ch, a.begin_sound, a.end_sound, a.begin_turn, 
     gap, a.debug
   from trans_raw a
     join conv b 
       on b.conv = a.conv
") 
#trans$conv <- as.factor(trans$conv)
#trans$params <- as.factor(trans$params)

nrow(trans)

#calculate transition begin as the beginning of the sound unless it's a positive gap, in which case the gap needs to be subtracted from the beginning of the sound
trans<-sqldf("
 select *,
  case debug
    when 'h' then begin_sound - gap
    else begin_sound
  end trans_begin
  from trans
")

trans$minute<-floor((trans$trans_begin)/60)

trans<-sqldf("
 select params, conv, ch, begin_sound, end_sound, begin_turn, gap, debug, trans_begin,
    minute, graph_block, min_block, ltnc_cat, ltnc_cat2, ltnc_cat3,
    case 
      when graph_block = 'ltnc' then ltnc_ms 
      else 0 
    end ltnc_ms,
    case
      when graph_block = 'post' then ltnc_ms
      else 0
    end ltnc_ms_post,
    max(ltnc_ms) over (partition by conv) ltnc_ms_const,
    case when graph_block = 'ltnc' or graph_block = 'post' then max(ltnc_ms) over (partition by conv) else 0 end ltnc_ms_lp
 from
 (
 select t.*,
    case 
     when minute < 1 then 'init'
     when minute < 7 then 'wrmp'
     when minute < 13 then 'base'
     when minute < 19 then 'ltnc'
     else 'post'
    end min_block, --use this group for graphs to make minute line up with grouping
    case 
     when begin_sound > ltnc_end then 'post'
     when begin_sound > ltnc_start then 'ltnc'
     when begin_sound > 420 then 'base'
     when begin_sound > 60 then 'wrmp'
     else 'init'
    end graph_block, --use this group for tests to be as accurate as possible
    ltnc_ms,
    case
     when ltnc_ms < 100 then '0-100'
     when ltnc_ms < 200 then '100-200'
     when ltnc_ms < 300 then '200-300'
     when ltnc_ms < 400 then '300-400'
     else '400-500'
    end ltnc_cat,
    case
     when ltnc_ms < 167 then 'Low latency'
     when ltnc_ms < 333 then 'Med. latency'
     else 'High latency'
    end ltnc_cat2,
    case
     when ltnc_ms < 250 then 'low'
     else 'high'
    end ltnc_cat3,
    conv_resume,
    ltnc_end
 from trans t 
  join conv c on c.conv = t.conv
 ) x
")

#pretty version of params variable
#trans$Parameters<-trans$params
#levels(trans$Parameters)[levels(trans$Parameters)=='_30_200_1.25'] <- 'Intensity: 1.25%'
#levels(trans$Parameters)[levels(trans$Parameters)=='_30_200_1'] <- 'Intensity: 1%'
trans$ltnc_cat3<-factor(trans$ltnc_cat3,levels=c('low','high'))
trans$ltnc_cat2<-factor(trans$ltnc_cat2,levels=c('Low latency','Med. latency','High latency'))
trans$min_block<-factor(trans$min_block,levels=c('init','wrmp','base','ltnc','post'))
trans$graph_block<-factor(trans$graph_block,levels=c('init','wrmp','base','ltnc','post'))
#w/ base as first graph_block
trans$block<-factor(trans$graph_block,levels=c('base','wrmp','ltnc','post','init'))
trans$minute_f <- factor(trans$minute,levels=c('0','1',
'2',
'3',
'4',
'5',
'6',
'7',
'8',
'9',
'10',
'11',
'12',
'13',
'14',
'15',
'16',
'17',
'18',
'19',
'20',
'21',
'22',
'23',
'24'))


minute0<-sqldf("
 select x.*, c.max_end, c.ltnc_s, c.ltnc_ms, c.ltnc_cat, c.ltnc_cat2
 from
 (
 select *, max(max_minute_begin_sound) over (partition by conv) max_begin
 from 
 (
 select  conv, minute, count(1) trans_cnt,
  sum(case when gap < 0 then 1 else 0 end) overlap_cnt, 
  sum(case when gap < 0 then abs(gap) else 0 end) overlap_dur,
  sum(case when gap > 0 then gap else 0 end) gap_dur,
  sum(case when gap > 0 then 1 else 0 end) gap_cnt,
  max(begin_sound) max_minute_begin_sound
 from trans
  where params='_30_200_1.25' and
   begin_sound <= 1500
  group by conv, minute
 )
 ) x 
  join conv c
    on x.conv = c.conv 
")


minute<-sqldf("
 select conv, minute, ltnc_cat, ltnc_cat2,
  case when graph_block = 'ltnc' then ltnc_s else 0 end ltnc_s, 
  case when graph_block = 'ltnc' then ltnc_ms else 0 end ltnc_ms, 
  graph_block,   
  trans_cnt, 
  overlap_cnt, 
  overlap_dur,
  gap_cnt, 
  gap_dur,
  cast(trans_cnt as float)   / 60 trans_rate, 
  cast(overlap_cnt as float) / trans_cnt overlap_trans_ratio,
  cast(overlap_cnt as float) / 60 overlap_rate, 
  cast(overlap_dur as float) / 60 overlap_dur_ratio,
  cast(gap_cnt as float)     / 60 gap_rate, 
  cast(gap_dur as float)     / 60 gap_dur_ratio
 from
 (
 select x.conv, x.ltnc_s, x.ltnc_ms, x.ltnc_cat, x.ltnc_cat2, x.minute, 
   case 
      when minute < 1 then 'init'
      when minute < 7 then 'wrmp'
      when minute < 13 then 'base'
      when minute < 19 then 'ltnc'
      else 'post'
   end graph_block,  
   trans_cnt, 
   overlap_cnt, 
   overlap_dur,
   gap_cnt, 
   gap_dur
  from minute0 x
 )
")
#minute$overlap_trans_ratio<-minute$overlap_cnt/minute$trans_cnt
minute$ltnc_cat2<-factor(minute$ltnc_cat2,levels=c('Low latency','Med. latency','High latency'))
minute$graph_block<-factor(minute$graph_block,levels=c('init','wrmp','base','ltnc','post'))
minute$minute_f <- factor(minute$minute,levels=c('0','1',
'2',
'3',
'4',
'5',
'6',
'7',
'8',
'9',
'10',
'11',
'12',
'13',
'14',
'15',
'16',
'17',
'18',
'19',
'20',
'21',
'22',
'23',
'24'))

abcd<-sqldf("
  select conv, graph_block, ltnc_ms, ltnc_ms_post, ltnc_cat, ltnc_cat2, dur, 
   mean_gap, 
   trans_cnt / dur trans_rate, 
   overlap_cnt / cast(trans_cnt as float) overlap_trans_ratio,
   overlap_dur / dur overlap_spm, 
   gap_dur / dur gap_spm
  from
  (
  select t.conv, t.graph_block, t.ltnc_ms, t.ltnc_ms_post, c.ltnc_cat, c.ltnc_cat2, 
    c.ltnc_end, case when t.graph_block = 'post' then (1500.0 - c.ltnc_end)/60 else 6 end dur,
    avg(gap) mean_gap,
    count(1) trans_cnt, 
    sum(case when gap < 0 then 1 else 0 end) overlap_cnt, 
    sum(case when gap > 0 then 1 else 0 end) gap_cnt,
    sum(case when gap < 0 then gap * -1 else 0 end) overlap_dur, 
    sum(case when gap > 0 then gap else 0 end) gap_dur
  from trans t
    join conv c on c.conv = t.conv
  where t.graph_block != 'init'
  group by t.conv, t.graph_block, t.ltnc_ms, t.ltnc_ms_post, c.ltnc_cat, c.ltnc_cat2, c.ltnc_end
  )
")
abcd$ltnc_cat2<-factor(abcd$ltnc_cat2,levels=c('Low latency','Med. latency','High latency'))
abcd$graph_block<-factor(abcd$graph_block,levels=c('wrmp','base','ltnc','post'))
abcd$block<-factor(abcd$graph_block,levels=c('base','wrmp','ltnc','post'))

base_ltnc <- sqldf("
 select a.conv, b.ltnc_ms, c.ltnc_cat, c.ltnc_cat2,
    b.overlap_trans_ratio - a.overlap_trans_ratio otr_diff,
    b.trans_rate - a.trans_rate trans_rate_diff,
    b.overlap_spm - a.overlap_spm overlap_spm_diff,
    b.gap_spm - a.gap_spm gap_spm_diff
   from abcd a
    join abcd b on a.conv = b.conv and a.graph_block = 'base' 
    join conv c on c.conv = a.conv
   where b.graph_block = 'ltnc'
")

base_post <- sqldf("
 select a.conv, c.ltnc_ms, c.ltnc_cat, c.ltnc_cat2,
    b.overlap_trans_ratio - a.overlap_trans_ratio otr_diff,
    b.trans_rate - a.trans_rate trans_rate_diff,
    b.overlap_spm - a.overlap_spm overlap_spm_diff,
    b.gap_spm - a.gap_spm gap_spm_diff,
    b.mean_gap - a.mean_gap mean_gap_diff
   from abcd a
    join abcd b on a.conv = b.conv and a.graph_block = 'base' 
    join conv c on c.conv = a.conv
   where b.graph_block = 'post'
")
base_post$ltnc_cat2<-factor(base_post$ltnc_cat2,levels=c('Low latency','Med. latency','High latency'))

wrmp_post <- sqldf("
 select a.conv, c.ltnc_ms, c.ltnc_cat, c.ltnc_cat2,
    b.overlap_trans_ratio - a.overlap_trans_ratio otr_diff,
    b.trans_rate - a.trans_rate trans_rate_diff,
    b.overlap_spm - a.overlap_spm overlap_spm_diff,
    b.gap_spm - a.gap_spm gap_spm_diff,
    b.mean_gap - a.mean_gap mean_gap_diff
   from abcd a
    join abcd b on a.conv = b.conv and a.graph_block = 'wrmp' 
    join conv c on c.conv = a.conv
   where b.graph_block = 'post'
")
wrmp_post$ltnc_cat2<-factor(wrmp_post$ltnc_cat2,levels=c('Low latency','Med. latency','High latency'))


trans_base <- sqldf("
 select y.*, (y.cf1 + y.cf2)/2 call_freq
 from
 (
 select x.*, 
  case when c.gender1 = c.gender2 then 'same' else 'diff' end gender_sm_df,
  case
    when gender1 = 'Female' and gender2 = 'Male' then 'f-m' 
    when gender1 = 'Male' and gender2 = 'Female' then 'f-m'
    when gender1 = 'Female' and gender2 = 'Female' then 'f-f'
    when gender1 = 'Male' and gender2 = 'Male' then 'm-m'
    else 'other'
  end gen ,
  (closeness1 + closeness2)/2 conv_closeness,
  (age1 + age2)/2 conv_age,
  abs(age1 - age2) age_diff,
  (ifnull(feel_pre1,feel_pre2) + ifnull(feel_pre2,feel_pre1))/2 conv_feel_pre,
  ifnull((ifnull(feel_pre1,feel_pre2) + ifnull(feel_pre2,feel_pre1))/2,90.7) conv_feel_pre_x,
  (feel_post1 + feel_post2)/2 conv_feel_post,
  case
    when call_freq1 = 'Rarely, if ever' then 1
    when call_freq1 = 'A few times a month' then 3
    when call_freq1 = 'Weekly, more or less' then 5
    when call_freq1 = 'A few times per week' then 15
    when call_freq1 = 'Almost every day' then 27
    when call_freq1 = 'Multiple times per day' then 75
  end cf1,
  case
    when call_freq2 = 'Rarely, if ever' then 1
    when call_freq2 = 'A few times a month' then 3
    when call_freq2 = 'Weekly, more or less' then 5
    when call_freq2 = 'A few times per week' then 15
    when call_freq2 = 'Almost every day' then 27
    when call_freq2 = 'Multiple times per day' then 75
  end cf2
 from trans x
   join all_conv_ptcp_wide c on c.conv = x.conv
 where x.block not in ('init','ltnc','post')
 ) y
")
