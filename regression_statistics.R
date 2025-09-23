require(tidyverse)
library(dplyr)
library(ggplot2)
#library(psych) 
library(GGally)
options(warn=-1)
options(scipen=999)
#library(crosstable)

path <- "/mount/studenten/DH_Master/compounding/regression"

varimp_10_files_list  <- path %>% 
  
  # get csvs full paths. (?i) is for case insentitive
  list.files(pattern = "varimp_10000_.*.*\\.csv$", full.names = TRUE)

varimp_10_files_agnostic_list  <- path %>% 
  
  # get csvs full paths. (?i) is for case insentitive
  list.files(pattern = "varimp_10000_.*Agnostic.*\\.csv$", full.names = TRUE)

varimp_10_df<-Reduce(bind_rows,lapply(varimp_10_files_list,read.csv))

varimp_10_df %>% dim()

varimp_10_agnostic_df <-Reduce(bind_rows,lapply(varimp_10_files_agnostic_list,read.csv))

varimp_10_df[is.na(varimp_10_df)] <- 0
statistics_varimp_df<-varimp_10_df %>% select(-features) %>% group_by(corpus,tag,ppmi,setting,impute,dataset,y,pattern,timespan,cutoff) %>% 
  summarise_all(mean)


varimp_10_agnostic_df[is.na(varimp_10_agnostic_df)] <- 0
statistics_varimp_agnostic_df<-varimp_10_agnostic_df %>% select(-features) %>% group_by(corpus,tag,ppmi,setting,impute,dataset,y,pattern,timespan,cutoff) %>% 
  summarise_all(mean)




# in one pipeline:
rsquared_files_list  <- path %>% 
  
  # get csvs full paths. (?i) is for case insentitive
  list.files(pattern = "rsquared_.*\\.csv$", full.names = TRUE)


rsquared_df<-Reduce(bind_rows,lapply(rsquared_files_list, function(x) {
  if (ncol(read.csv(x))>1) {
    return(read.csv(x))
  }
}))


rsquared_df %>% 
  filter(y=='compound') %>% 
  group_by(corpus,features) %>% 
  summarise(TrainRsquared=round(max(TrainRsquared),2),TestRsquared=round(max(TestRsquared,na.rm = TRUE),2),
            TrainSpearman=round(max(TrainSpearman),2),TestSpearman=round(max(TestSpearman,na.rm = TRUE),2)) %>% 
  View()



