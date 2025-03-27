library(ggplot2)
library(lme4)
library(lmerTest)
library(agricolae)
opt <- lmerControl(optimizer = "bobyqa", optCtrl=list(maxfun=8e5))
opt2 <- lmerControl(optimizer = "Nelder_Mead", optCtrl=list(maxfun=8e5))
opt3 <- lmerControl(optimizer = "nloptwrap", optCtrl=list(maxeval=8e5))
opt4 <- lmerControl(optimizer = "nlminbwrap", optCtrl=list(maxfun=8e5))
opt5 <- lmerControl(optimizer = "optimx", optCtrl=list(maxit=8e5,method="L-BFGS-B"))

#transitions by minute
ggplot(data=minute,aes(y=trans_cnt, x= minute)) +
  theme_bw() +
  stat_summary(fun=mean, geom="point", shape = 1,size=2) + 
  stat_summary(fun.data = mean_cl_boot, geom = "errorbar", linewidth=1,aes(color=graph_block)) +
  ylab("Transitions per minute") +
  xlab("Minute") +
  stat_smooth(method="loess",formula=y~x, span=0.5, se=FALSE) +
  labs(color="Block:") +
  theme(legend.position = "bottom")
ggsave(filename="C:\\Users\\david\\documents\\synced\\dissertation\\latency\\images\\tr by min.jpg",device="jpg",width = 6, height = 4,dpi = 300)

#gender
conv_bw <- sqldf("
 select conv, gender_sm_df, avg(gap) mean_gap
 from
 (
 select x.*, 
  case when c.gender1 = c.gender2 then 'Same' else 'Different' end gender_sm_df
 from trans x
   join all_conv_ptcp_wide c on c.conv = x.conv
 where x.block not in ('init','ltnc','post')
 )
 group by conv, gender_sm_df
")
ggplot(data=conv_bw,aes(y=mean_gap, x= gender_sm_df)) +
  theme_bw() +
  stat_summary(fun=mean, geom="point", shape = 1,size =3) + 
  stat_summary(fun.data = mean_cl_boot, fun.args = list(conf.int = 0.99), geom = "errorbar",linewidth=1, width = 0.4) +
  ylab("Mean gap (s)") +
  xlab("Gender")
ggsave(filename="C:\\Users\\david\\documents\\synced\\dissertation\\latency\\images\\gender conv gap length.jpg",device="jpg",width = 3, height = 2,dpi = 300)

sqldf("
 select gender_sm_df, count(1), avg(conv_closeness), avg(mean_gap)
 from
 (
 select conv, conv_closeness, gender_sm_df, avg(gap) mean_gap
 from
 (
 select x.*, 
  case when c.gender1 = c.gender2 then 'Same' else 'Different' end gender_sm_df,
  (closeness1 + closeness2)/2 conv_closeness
 from trans x
   join all_conv_ptcp_wide c on c.conv = x.conv
 where x.block not in ('init','ltnc','post')
 )
 group by conv, conv_closeness, gender_sm_df
 )
 group by gender_sm_df
")
#reported gender dyad stats
lmer.gap.gen <- lmer(gap ~ gender_sm_df + (gender_sm_df| conv),  data = trans_base, REML="TRUE", control=opt)
summary(lmer.gap.gen)
#for reference
t.test(trans_base$gap[trans_base$gender_sm_df=='diff'],trans_base$gap[trans_base$gender_sm_df=='same'])
lm.gap.gen <- lm(gap ~ gender_sm_df,  data = trans_base)
summary(lm.gap.gen)

###

#block comparison from third-party perspective
trans$graph_block2<-trans$graph_block
levels(trans$graph_block2) <- c('Initial', 'Warmup', 'Baseline','Latency','Post')
ggplot(data=trans,aes(y=gap, x= graph_block2,color=graph_block2)) +
  theme_bw() +
  stat_summary(fun=mean, geom="point", shape = 1,size = 3) + 
  stat_summary(fun.data = mean_cl_boot, fun.args = list(conf.int = 0.99), geom = "errorbar", linewidth=1, width=0.4) +
  theme(legend.position = "none") +  
  ylab("Gap length (s)") +
  scale_x_discrete(name=element_blank())  
ggsave(filename="C:\\Users\\david\\Documents\\synced\\Dissertation\\Latency\\images\\mean gap by graph_block 3p.jpg",device="jpg",width = 4, height = 3,dpi = 300)

ggplot(data=trans[trans$minute<25,],aes(y=gap, x= minute,color=min_block)) +
  theme_bw() +
  stat_summary(fun=mean, geom="point", shape = 1,size = 3) + 
  stat_summary(fun.data = mean_cl_boot, fun.args = list(conf.int = 0.99), geom = "errorbar", linewidth=1, width=0.4) +
  theme(legend.position = "none") +  
  ylab("Gap length (s)")
ggsave(filename="C:\\Users\\david\\Documents\\synced\\Dissertation\\Latency\\images\\mean gap by min 3p.jpg",device="jpg",width = 4, height = 3,dpi = 300)

#w/ base as first factor and init as 2nd
trans$block2<-factor(trans$graph_block,levels=c('base','init','wrmp','ltnc','post'))

lmer.gap.block <- lmer(gap ~ block2 + (block2 | conv),  data = trans, REML="TRUE", control=opt)
summary(lmer.gap.block)

#boxplot, zoomed into relevant portion
ggplot(data=trans,aes(y=gap, x= graph_block2,color=graph_block2)) +
  theme_bw() +
  geom_boxplot(notch=TRUE) + 
  scale_x_discrete(name=element_blank())  +
  ylab("Gap length (s)") +
  coord_cartesian(ylim=c(-0.4,0.6))+
  theme(legend.position = "none")
ggsave(filename="C:\\Users\\david\\Documents\\synced\\Dissertation\\Latency\\images\\gap boxplot.jpg",device="jpg",width = 5, height = 4,dpi = 300)

##planned

lm.od.bl.a <- lm(overlap_spm_diff ~ ltnc_ms, data=base_ltnc)
summary(lm.od.bl.a)

ggplot(data=base_ltnc, aes(x=ltnc_ms,y=overlap_spm_diff)) +
  geom_point() +
  theme_bw() +
  geom_smooth(method="lm", formula=y~x) +
  ylab("Difference in overlap duration (s/min)") +
  xlab("Latency (ms)")
ggsave(filename="C:\\Users\\david\\Documents\\synced\\Dissertation\\Latency\\images\\base_ltnc od diff 3p.jpg",device="jpg",width = 6, height = 4,dpi = 300)
#base_post
#no rel between latency amt and mean gap in post-latency block
ggplot(data=base_post,aes(y=mean_gap_diff, x= ltnc_ms)) +
  geom_point() +
  theme_bw() +
  stat_smooth(formula=y~x, method="lm") +
  xlab("Latency (ms)") +
  ylab("Difference in mean gap (s)")
ggsave(filename="C:\\Users\\david\\Documents\\synced\\Dissertation\\Latency\\images\\base_post mean_gap_diff.jpg",device="jpg",width = 5, height = 4,dpi = 300)

lm.gap.bp.a <- lm(mean_gap_diff ~ ltnc_ms, data=base_post)
summary(lm.gap.bp.a)
#
with(trans,Median.test(gap,block,alpha=0.01))
#ntile to calc median test for top and bottom halfs
trans.test <- trans %>% group_by(block) %>% mutate(quartile = ntile(gap, 4)) %>% ungroup()
sqldf('select block, quartile, count(1) from \"trans.test\" group by block, quartile')

#median of bottom half (1st 2 quartiles)
with(trans.test[trans.test$quartile<3,],Median.test(gap,block,alpha=0.01))
#median of top half (top 2 quartiles)
with(trans.test[trans.test$quartile>2,],Median.test(gap,block,alpha=0.01))

ansari.test(trans$gap[trans$block=='base'],trans$gap[trans$block=='post'],conf.int=TRUE,conf.level=0.99)
ansari.test(trans$gap[trans$block=='base'],trans$gap[trans$block=='ltnc'],conf.int=TRUE,conf.level=0.99)
ansari.test(trans$gap[trans$block=='base'],trans$gap[trans$block=='wrmp'],conf.int=TRUE,conf.level=0.99)
ansari.test(trans$gap[trans$block=='base'],trans$gap[trans$block=='init'],conf.int=TRUE,conf.level=0.99)

