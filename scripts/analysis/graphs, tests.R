library(lme4)
library(lmerTest)
library(ggplot2)
intercept <- 0
opt <- lmerControl(optimizer = "bobyqa", optCtrl=list(maxfun=8e5))
opt2 <- lmerControl(optimizer = "Nelder_Mead", optCtrl=list(maxfun=8e5))
opt3 <- lmerControl(optimizer = "nloptwrap", optCtrl=list(maxeval=8e5))
opt4 <- lmerControl(optimizer = "nlminbwrap", optCtrl=list(maxfun=8e5))
opt5 <- lmerControl(optimizer = "optimx", optCtrl=list(maxit=8e5,method="L-BFGS-B"))

#Trans rate by minute (for comparison w/ CH/CF) (3p)
ggplot(data=minute,aes(y=trans_cnt, x= minute)) +
  theme_bw() +
  stat_summary(fun=mean, geom="point", shape = 1,size=2) + 
  stat_summary(fun.data = mean_se, geom = "errorbar", linewidth=1,aes(color=graph_block)) +
  ylab("Transitions per minute") +
  xlab("Minute") +
  stat_smooth(method="loess",formula=y~x, span=0.5) +
  labs(color="Block:") +
  theme(legend.position = "bottom")
ggsave(filename="C:\\Users\\david\\OneDrive - University of Texas at Arlington\\latency\\images\\tr by min.jpg",device="jpg",width = 6, height = 4,dpi = 300)


##planned

lm.od.bl.a <- lm(overlap_spm_diff ~ ltnc_ms, data=base_ltnc)
summary(lm.od.bl.a)

ggplot(data=base_ltnc, aes(x=ltnc_ms,y=overlap_spm_diff)) +
  geom_point() +
  theme_bw() +
  geom_smooth(method="lm", formula=y~x) +
  ylab("Difference in overlap duration (s/min)") +
  xlab("Latency (ms)")
ggsave(filename="C:\\Users\\david\\OneDrive - University of Texas at Arlington\\latency\\images\\base_ltnc od diff 3p.jpg",device="jpg",width = 6, height = 4,dpi = 300)

#alt comparison, forcing intercept to zero
lm.od.bl.b <- lm(I(overlap_spm_diff - intercept) ~ 0 + ltnc_ms, data=base_ltnc)
summary(lm.od.bl.b)

ggplot(data=base_ltnc, aes(x=ltnc_ms,y=overlap_spm_diff)) +
  geom_point() +
  #geom_text(aes(label=conv),size=3)+
  theme_bw() +
  geom_smooth(method="lm", formula=y~x+0) +
  ylab("Difference in overlap duration (s/min)") +
  xlab("Latency (ms)")
#ggsave(filename="C:\\Users\\david\\OneDrive - University of Texas at Arlington\\latency\\images\\base_ltnc od diff 3p 0 int.jpg",device="jpg",width = 6, height = 4,dpi = 300)

lm.otr.bl.a <- lm(otr_diff ~ ltnc_ms, data=base_ltnc)
summary(lm.otr.bl.a)

ggplot(data=base_ltnc, aes(x=ltnc_ms,y=otr_diff)) +
  geom_point() +
  #geom_text(aes(label=conv))+
  theme_bw() +
  geom_smooth(method="lm", formula=y~x) +
  ylab("Difference in overlaps per transition") +
  xlab("Latency (ms)")
ggsave(filename="C:\\Users\\david\\OneDrive - University of Texas at Arlington\\latency\\images\\base_ltnc otr diff 3p.jpg",device="jpg",width = 6, height = 4,dpi = 300)

#alt
#lm.otr.bl.b <- lm(I(otr_diff - intercept) ~ 0 + ltnc_ms, data=base_ltnc)
#summary(lm.otr.bl.b)

#in-conv perspectives
lm.otr.bl1.a <- lm(otr_diff ~ ltnc_ms, data=base_ltnc1)
summary(lm.otr.bl1.a)
lm.otr.bl2.a <- lm(otr_diff ~ ltnc_ms, data=base_ltnc2)
summary(lm.otr.bl2.a)

lm.od.bl1.a <- lm(overlap_spm_diff ~ ltnc_ms, data=base_ltnc1)
summary(lm.od.bl1.a)
lm.od.bl2.a <- lm(overlap_spm_diff ~ ltnc_ms, data=base_ltnc2)
summary(lm.od.bl2.a)

#for tables 4 & 5
sqldf("select block, avg(overlap_spm), avg(overlap_trans_ratio) from abcd group by block")
sqldf("select block, avg(overlap_spm), avg(overlap_trans_ratio) from abcd1 group by block")
sqldf("select block, avg(overlap_spm), avg(overlap_trans_ratio) from abcd2 group by block")

##trans level
#Mean gap by graph_block
#note: higher in post than base, and comparable to ltnc
ggplot(data=trans.wt.winit,aes(y=gap, x= graph_block_perspective,color=graph_block)) +
  theme_bw() +
  stat_summary(fun=mean, geom="point", shape = 1,size = 2) + 
  stat_summary(fun.data = mean_se, geom = "errorbar", linewidth=1) +
  theme(legend.position = "none") +  
  ylab("Gap length (s)") +
  scale_x_discrete(name=element_blank())  
ggsave(filename="C:\\Users\\david\\OneDrive - University of Texas at Arlington\\latency\\images\\mean gap by graph_block.jpg",device="jpg",width = 3, height = 2,dpi = 300)

lmer.gap.wt.block <- lmer(gap ~ block + (block | conv),  data = trans.wt, weight=wt, REML="TRUE")
summary(lmer.gap.wt.block)
#confint(lmer.gap.wt.block,oldNames=FALSE)

#Mean gap by minute
#ggplot(data=trans[trans$minute<25,],aes(y=gap, x= minute_f, color=min_block)) +
#  theme_bw() +
#  theme(legend.title = element_blank()) +
#  stat_summary(fun=mean, geom="point", shape = 1,size = 2) + 
#  stat_summary(fun.data = mean_se, geom = "errorbar", linewidth=1) +
#  ylab("Gap length (s)") +
#  scale_x_discrete(name=element_blank())  +
#  labs(color="Block:") +
#  theme(legend.position = "bottom")
#ggsave(filename="C:\\Users\\david\\OneDrive - University of Texas at Arlington\\latency\\images\\mean gap by min.jpg",device="jpg",width = 6, height = 4,dpi = 300)

#mean gap by graph_block, excluding initial minute, broken up by latency category
ggplot(data=trans.wt,aes(y=gap, x= graph_block_perspective,color=graph_block)) +
  theme_bw() +
  stat_summary(fun=mean, geom="point", shape = 1,size =2) + 
  stat_summary(fun.data = mean_se, geom = "errorbar",linewidth=1) +
  theme(legend.position = "none") +  
  ylab("Gap length (s)") +
  scale_x_discrete(name=element_blank())  +
  facet_wrap(. ~ ltnc_cat2) 
#no significant effect of latency category (or latency as a numeric value), but perhaps a behavioral increase w/ any latency that only leads to more overlap with higher latency values??
ggsave(filename="C:\\Users\\david\\OneDrive - University of Texas at Arlington\\latency\\images\\mean gap by ltnc cat2.jpg",device="jpg",width = 6, height = 3,dpi = 300)

#boxplot
ggplot(data=trans1.woinit,aes(y=gap, x= min_block,color=min_block)) +
  theme_bw() +
  geom_boxplot(notch=FALSE) + 
  scale_x_discrete(name=element_blank())  +
  ylab("Gap length (s)") +
  facet_wrap(. ~ ltnc_cat2) +
  coord_cartesian(ylim=c(-0.4,0.6))+
  theme(legend.position = "none")
ggsave(filename="C:\\Users\\david\\OneDrive - University of Texas at Arlington\\latency\\images\\trans1 gap boxplot by ltnc cat2.jpg",device="jpg",width = 5, height = 4,dpi = 300)

#By minute, showing only base, latency, and post-latency graph_blocks, using trans1
ggplot(data=trans1[ trans1$minute>6 & trans1$minute<25,],aes(y=gap, x= minute_f,color=min_block)) +
  theme_bw() +
  geom_boxplot(notch=FALSE) + 
  xlab("Minute") +
  ylab("Gap length (s)") +
  facet_wrap(. ~ ltnc_cat2) +
  coord_cartesian(ylim=c(-0.4,0.6))+
  theme(legend.title = element_blank()) +
  theme(legend.position = "bottom")
ggsave(filename="C:\\Users\\david\\OneDrive - University of Texas at Arlington\\latency\\images\\trans1 gap boxplot by minute by ltnc cat2.jpg",device="jpg",width = 8.5, height = 4,dpi = 300)
lmer.gap.wt.block.min <- lmer(gap ~ block + block:minute + (block + block:minute | conv),  data = trans.wt, weight=wt, REML="TRUE",control=opt5)
summary(lmer.gap.wt.block.min)
#in addition to not being significantly different from zero, the slopes for ltnc & post are negative (so no general trend of increasing gaps each minute)

##block_level
sqldf("select ltnc_cat2, graph_block_persp, 
    avg(overlap_trans_ratio), avg(trans_rate), avg(overlap_spm), avg(gap_spm),
    median(overlap_trans_ratio), median(trans_rate), median(overlap_spm), median(gap_spm)
 from \"abcd.wt\"
 group by ltnc_cat2, graph_block_persp
")

#block_level otr
ggplot(data=abcd.wt,aes(y=overlap_trans_ratio, x= graph_block_persp,color=graph_block)) +
  theme_bw() +
  stat_summary(fun=mean, geom="point", shape = 1,size =2) + 
  stat_summary(fun.data = mean_se, geom = "errorbar",linewidth=1) +
  theme(legend.position = "none") +  
  ylab("Overlaps per transition") +
  scale_x_discrete(name=element_blank())
ggsave(filename="C:\\Users\\david\\OneDrive - University of Texas at Arlington\\latency\\images\\block_level otr.jpg",device="jpg",width = 3, height = 2,dpi = 300)

lmer.otr.abcd.wt.block <- lmer(overlap_trans_ratio ~ block + (block | conv) , data=abcd.wt, , weight=wt, REML="TRUE", control=opt)
summary(lmer.otr.abcd.wt.block)


#a little more difference in overlap duration, but still not much (n.s.)
ggplot(data=abcd.wt,aes(y=overlap_spm, x= graph_block_persp,color=graph_block)) +
  theme_bw() +
  stat_summary(fun=mean, geom="point", shape = 1,size =2) + 
  stat_summary(fun.data = mean_se, geom = "errorbar",linewidth=1) +
  theme(legend.position = "none") +  
  ylab("Overlap duration (s/min)") +
  scale_x_discrete(name=element_blank()) 
ggsave(filename="C:\\Users\\david\\OneDrive - University of Texas at Arlington\\latency\\images\\block_level od.jpg",device="jpg",width = 3, height = 2,dpi = 300)

lmer.od.abcd.wt.block <- lmer(overlap_spm ~ block + (block | conv) , data=abcd.wt, weight=wt, REML="TRUE")
summary(lmer.od.abcd.wt.block)

#not much tr differnce post v base
ggplot(data=abcd.wt,aes(y=trans_rate, x= graph_block_persp,color=graph_block)) +
  theme_bw() +
  stat_summary(fun=mean, geom="point", shape = 1,size =2) + 
  stat_summary(fun.data = mean_se, geom = "errorbar",linewidth=1) +
  theme(legend.position = "none") +  
  ylab("Transitions per min") +
  scale_x_discrete(name=element_blank())  
ggsave(filename="C:\\Users\\david\\OneDrive - University of Texas at Arlington\\latency\\images\\block_level tr.jpg",device="jpg",width = 3, height = 2,dpi = 300)

lmer.tr.abcd.wt.block <- lmer(trans_rate ~ block + (block | conv) , data=abcd.wt, weight=wt, REML="TRUE",control=opt)
summary(lmer.tr.abcd.wt.block)

#more gap in ltnc & post than base
ggplot(data=abcd.wt,aes(y=gap_spm, x= graph_block_persp,color=graph_block)) +
  theme_bw() +
  stat_summary(fun=mean, geom="point", shape = 1,size =2) + 
  stat_summary(fun.data = mean_se, geom = "errorbar",linewidth=1) +
  theme(legend.position = "none") +  
  ylab("Between-Speaker Silence\nDuration (s/min)") +
  scale_x_discrete(name=element_blank())
ggsave(filename="C:\\Users\\david\\OneDrive - University of Texas at Arlington\\latency\\images\\block_level gd.jpg",device="jpg",width = 3.1, height = 2.1,dpi = 300)

lmer.gd.abcd.wt.block <- lmer(gap_spm ~ block + (block | conv), data=abcd.wt, weight=wt, REML="TRUE")
summary(lmer.gd.abcd.wt.block)

ggplot(data=base_post,aes(y=mean_gap_diff, x= ltnc_ms)) +
  geom_point() +
  theme_bw() +
  stat_smooth(formula=y~x, method="lm") +
  xlab("Latency (ms)") +
  ylab("Difference in mean gap (s)")
ggsave(filename="C:\\Users\\david\\OneDrive - University of Texas at Arlington\\latency\\images\\base_post mean_gap_diff vs ltnc_ms.jpg",device="jpg",width = 6, height = 4,dpi = 300)

mean(base_post$mean_gap_diff)
#sd(base_post$mean_gap_diff)
#median(base_post$mean_gap_diff)

ggplot(data=base_post,aes(x=mean_gap_diff)) +
  theme_bw() +
  geom_histogram(bins=9,fill="dark blue") +
  xlab("Difference in mean gap (s)") +
  ylab("Count") 
#  geom_freqpoly(bins=9, color="red",linewidth=1) 
ggsave(filename="C:\\Users\\david\\OneDrive - University of Texas at Arlington\\latency\\images\\base_post mean_gap_diff hist.jpg",device="jpg",width = 3.5, height = 2.5,dpi = 300)

#lm.gap.bp.a <- lm(mean_gap_diff ~ ltnc_ms, data=base_post)
#summary(lm.gap.bp.a)

##force zero
#ggplot(data=base_post,aes(y=mean_gap_diff, x= ltnc_ms)) +
#  geom_point() +
#  theme_bw() +
#  stat_smooth(formula=y~x, method="lm") +
#  xlab("Latency (ms)") +
#  ylab("Difference in mean gap")
#lm.gap.bp.b <- lm(I(mean_gap_diff- intercept) ~ 0 + ltnc_ms, data=base_post)
#summary(lm.gap.bp.b)

#ggplot(data=base_post,aes(y=gap_spm_diff, x= ltnc_ms)) +
#  geom_point() +
#  theme_bw() +
#  stat_smooth(formula=y~x+0, method="lm") +
#  xlab("Latency (ms)") +
#  ylab("Difference in positive gap duration (s/min)")
#lm.gd.bp.b <- lm(I(gap_spm_diff- intercept) ~ 0 + ltnc_ms, data=base_post)
#summary(lm.gd.bp.b)

#lm.gd.bp.a <- lm(gap_spm_diff ~ ltnc_ms, data=base_post)
#summary(lm.gd.bp.a)

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
  stat_summary(fun=mean, geom="point", shape = 1,size =2) + 
  stat_summary(fun.data = mean_se, geom = "errorbar",linewidth=1) +
  ylab("Gap length (s)") +
  xlab("Gender")
ggsave(filename="C:\\Users\\david\\OneDrive - University of Texas at Arlington\\latency\\images\\gender conv gap length.jpg",device="jpg",width = 3, height = 2,dpi = 300)

lmer.gap.gen <- lmer(gap ~ gender_sm_df + (gender_sm_df| conv),  data = trans_base, REML="TRUE", control=opt)
summary(lmer.gap.gen)