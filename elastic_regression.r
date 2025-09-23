library(tidyverse)
library(caret)
library(glmnet)
library(dplyr)
#library(psych) 
library(readr)
library(GGally)
options(warn=-1)
options(scipen=999)
library(doParallel)
library(missMethods)
cl <- makePSOCKcluster(40)
registerDoParallel(cl)
set.seed(1111)

caret_spearman <- function(data, lev = NULL, model = NULL) {
  spearman_val <- cor(x = data$pred, y = data$obs, method = "spearman")
  c(Spearman = spearman_val)
}

caret_adjustedR2 <- function(data, lev = NULL, model = NULL) {
  
  rsq <- R2(data$obs, data$pred)
  n <- length(data$obs)
  p <- ncol(model.matrix(~ ., data.frame(data$obs))) - 1  
  
  adjR2 <- 1 - ((1 - rsq) * ((n - 1) / (n - p - 1)))
  
  return(c(adjR2 = adjR2))
}



needed_cols<-c('modifier','head','avgModifier','stdevModifier','avgHead','stdevHead','compositionality','stdevHeadModifier','is_adj','compound','source','is_original')

cordeiro_cols<-c('arith_mean_sim.','beta.','geom_mean_sim.','sim_cpf_0.','sim_cpf_100.','sim_cpf_25.','sim_cpf_50.','sim_cpf_75.','sim_cpf_beta.')

sim_cpf_beta_cols<-c('sim_cpf_beta.')

cosine_sim_cols<-c("sim_bw_constituents.",'sim_with_head.','sim_with_modifier.')

with_setting_cols<-c("sim_bw_settings_comp.","sim_bw_settings_head.","sim_bw_settings_modifier.")
info_theory_cols<-c("local_mi.","log_ratio.","ppmi.")
log_freq_cols<-c("log_comp_freq.","log_head_freq.","log_mod_freq.")
tf_cols<-c("comp_tf.","head_tf.","mod_tf.")
freq_cols<-c("comp_freq.","head_freq.","mod_freq.")
prod_cols<-c("head_prod.","mod_prod.")
family_size_cols<-c("head_family_size.","mod_family_size.")
temporal_cols<-c("change_comp.","change_head.","change_mod.")

save_path<-"/mount/studenten/DH_Master/compounding/regression/"
load_path<-"/mount/studenten/DH_Master/compounding/"


m<-1
v<-1
#list_of_vi <- vector(mode="list", length=5)
#names(list_of_vi) <- c('10000', '10', '20', '50', '100')

list_of_vi_10000<-list()
list_of_vi_10<-list()
list_of_vi_20<-list()
list_of_vi_50<-list()
list_of_vi_100<-list()
list_of_rsqr=list()

corpus_list<-c("coha","google")


tagged_list<-c("UnTagged")
ppmi_setting_list<-c("PPMI")
comp_setting_list<-c("Aware","Agnostic")
impute_list<-c("na")
to_predict_list<-c("compound")

cut_off<-c(1000)
time_off<-c(10)
#time_off<-c(10)

lambda <- 10^seq(-4, 4, length = 200)
alpha<-seq(0,1,length=10)

nsamples <- 5 * 10

seeds <- vector(mode = "list", length = nsamples + 1)
for (i in 1:nsamples) {
  seeds[[i]] <- sample.int(length(alpha) * length(lambda), size = length(alpha) * length(lambda))  
}
seeds[[nsamples + 1]] <- sample.int(1000, 1) 

setwd('~/dh/repos/Compounding_github/')

reddy90_df <- read_delim("data/reddy_90.txt", 
                       delim = "\t", escape_double = FALSE, 
                       trim_ws = TRUE)
cordeiro90_df <- read_delim("data/cordeiro_90.txt", 
                       delim = "\t", escape_double = FALSE, 
                       trim_ws = TRUE)
cordeiro100_df <- read_delim("data/cordeiro_100.txt", 
                          delim = "\t", escape_double = FALSE, 
                          trim_ws = TRUE)

compounds_df<-bind_rows(reddy90_df,cordeiro90_df,cordeiro100_df)

for (c in corpus_list){
  for (t in tagged_list) {
    
    for (p in ppmi_setting_list){
      for (a in comp_setting_list){
        for (i in time_off) {
          
          for (j in cut_off) {
            
            for (im in impute_list) {
              cur_path<-paste0(load_path,"/",c,"/features_Compound",a,"_withSetting_",p,"_",t,"_",i,"_",j,"_",im,".csv")
              print(cur_path)
              input_df<-read.csv(cur_path,sep = '\t')
              #input_df <- input_df %>% distinct()

              
              if (i != 10000) {
                temporal_path<-paste0(load_path,"/",c,"/temporal_Compound",a,"_withSetting_",p,"_",t,"_",i,"_",j,"_",im,".csv")
                temporal_df<-read.csv(temporal_path,sep = '\t')
                input_df<-merge(input_df,temporal_df,by=intersect(colnames(input_df),colnames(temporal_df)),all=TRUE,no.dups=TRUE)
                
                all_features<-c(cordeiro_cols,cosine_sim_cols,with_setting_cols,info_theory_cols,log_freq_cols,tf_cols,freq_cols,prod_cols,family_size_cols,temporal_cols)
                feature_setting_list<-c("all","sim_cpf_beta","cordeiro","cosine_sim","with_setting","info_theory","freq","log_freq","family_size","prod","temporal")
                
              } else {
                all_features<-c(cordeiro_cols,cosine_sim_cols,with_setting_cols,info_theory_cols,log_freq_cols,tf_cols,freq_cols,prod_cols,family_size_cols)
                feature_setting_list<-c("all","sim_cpf_beta","cordeiro","cosine_sim","with_setting","info_theory","freq","log_freq","family_size","prod")
              }
              
              input_df$is_adj<-as.logical(input_df$is_adj)
              input_df$is_original<-as.logical(input_df$is_original)             
              input_df<-rows_patch(input_df,compounds_df, by=intersect(colnames(compounds_df),colnames(input_df)))

              input_df<-input_df %>% filter(is_original==TRUE)
              input_df<-impute_median(input_df)
            
              train_df<-input_df %>% filter(source %in% c("reddy","cordeiro90"))
              test_df<-input_df %>% filter(source %in% c("cordeiro100"))
              
              df_features_train<-train_df %>% select(-needed_cols) %>% select(-one_of("comp_freq_bins"))
              df_features_train<-df_features_train %>% select(starts_with(all_features))              
              #df_features_train<- Filter(function(x) sd(x) != 0,df_features_train)
              train_cols<-Filter(function(x) sd(x) != 0,df_features_train) %>% colnames()
              
              df_features_test<-test_df %>% select(-needed_cols) %>% select(-one_of("comp_freq_bins"))
              df_features_test<-df_features_test %>% select(starts_with(all_features))              
              #df_features_test<- Filter(function(x) sd(x) != 0,df_features_test)
              test_cols<-Filter(function(x) sd(x) != 0,df_features_test) %>% colnames()
              
              common_cols<-intersect(train_cols,test_cols)
              
              df_features_train<-df_features_train %>% select(common_cols)
              df_features_test<-df_features_test %>% select(common_cols)
              
              for (f in feature_setting_list) {
                
                if(f=="cordeiro"){
                  trainX<-df_features_train %>% select(starts_with(cordeiro_cols))
                  testX<-df_features_test %>% select(starts_with(cordeiro_cols))
                } else if(f=="sim_cpf_beta"){
                  trainX<-df_features_train %>% select(starts_with(sim_cpf_beta_cols))
                  testX<-df_features_test %>% select(starts_with(sim_cpf_beta_cols))
                } else if(f=="cosine_sim"){
                  trainX<-df_features_train %>% select(starts_with(cosine_sim_cols))
                  testX<-df_features_test %>% select(starts_with(cosine_sim_cols))
                } else if(f=="with_setting"){
                  trainX<-df_features_train %>% select(starts_with(with_setting_cols))
                  testX<-df_features_test %>% select(starts_with(with_setting_cols))
                } else if(f=="info_theory"){
                  trainX<-df_features_train %>% select(starts_with(info_theory_cols))
                  testX<-df_features_test %>% select(starts_with(info_theory_cols))
                } else if(f=="freq"){
                  trainX<-df_features_train %>% select(starts_with(freq_cols))
                  testX<-df_features_test %>% select(starts_with(freq_cols))
                } else if(f=="tf"){
                  trainX<-df_features_train %>% select(starts_with(tf_cols))
                  testX<-df_features_test %>% select(starts_with(tf_cols))
                } else if(f=="log_freq"){
                  trainX<-df_features_train %>% select(starts_with(log_freq_cols))
                  testX<-df_features_test %>% select(starts_with(log_freq_cols))
                } else if(f=="prod"){
                  trainX<-df_features_train %>% select(starts_with(prod_cols))
                  testX<-df_features_test %>% select(starts_with(prod_cols))
                } else if(f=="family_size"){
                  trainX<-df_features_train %>% select(starts_with(family_size_cols))
                  testX<-df_features_test %>% select(starts_with(family_size_cols))
                } else if(f=="temporal") {
                  trainX<-df_features_train %>% select(starts_with(temporal_cols))
                  testX<-df_features_test %>% select(starts_with(temporal_cols))
                } else {
                  trainX<-df_features_train    
                  testX<-df_features_test                    
                }
                
                if (dim(trainX)[1]<10 | dim(trainX)[2]==0) {
                  print(dim(trainX))
                  break
                }
                for (pr in to_predict_list){
                  
                  if (pr=="compound") {
                    trainY<-train_df %>% select(compositionality)
                    trainY<-trainY$compositionality
                    testY<-test_df %>% select(compositionality)
                    testY<-testY$compositionality
                  } else if (pr=="modifier") {
                    trainY<-train_df %>% select(avgModifier)
                    trainY<-trainY$avgModifier 
                    testY<-test_df %>% select(avgModifier)
                    testY<-testY$avgModifier
                  } else if (pr=="head") {
                    trainY<-train_df %>% select(avgHead)
                    trainY<-trainY$avgHead
                    testY<-test_df %>% select(avgHead)
                    testY<-testY$avgHead
                  }                               
                  
                  print(paste0(c," ",t," ",p," ",a," ",i," ",j," ",im," ",f," ",pr))
                  
                  preprocess_list<-c("nzv", "center", "scale")
                  
                  regression_error <- tryCatch( 
                    expr = {
                      elastic_rsquared_model <- train(trainX,trainY,method = "glmnet",metric = "Rsquared",
                                             trControl = trainControl("repeatedcv", number = 5, repeats = 10, seeds = seeds, search="grid"),
                                             tuneGrid = expand.grid(alpha = alpha, lambda = lambda),
                                             preProcess = preprocess_list)
                      elastic_adjrsquared_model <- train(trainX,trainY,method = "glmnet",metric = "adjR2",
                                                      trControl = trainControl("repeatedcv", number = 5, repeats=10,seeds = seeds, search="grid",summaryFunction = caret_adjustedR2),
                                                      tuneGrid = expand.grid(alpha = alpha, lambda = lambda),
                                                      preProcess = preprocess_list)
                      elastic_spearman_model <- train(trainX,trainY,method = "glmnet",metric = "Spearman",
                                                      trControl = trainControl("repeatedcv", number = 5, repeats=10,seeds = seeds, search="grid",summaryFunction = caret_spearman),
                                                      tuneGrid = expand.grid(alpha = alpha, lambda = lambda),
                                                      preProcess = preprocess_list)
                    },
                    error = function(e) {e}
                  ) 
                  if (inherits(regression_error, "error")) {next}
                  
                  final_Rsquared_model <- elastic_rsquared_model$finalModel
                  best_Rsquared_lambda <- elastic_rsquared_model$bestTune$lambda
                  final_Rsquared_coefs <- coef(final_Rsquared_model, s = best_Rsquared_lambda)
                  p_Rsquared <- length(which(final_Rsquared_coefs != 0)) - 1 
                  testRsquared<-elastic_rsquared_model %>% predict(newdata = testX) %>% R2(.,testY)
                  
                  final_adjRsquared_model <- elastic_adjrsquared_model$finalModel
                  best_adjRsquared_lambda <- elastic_adjrsquared_model$bestTune$lambda
                  final_adjRsquared_coefs <- coef(final_adjRsquared_model, s = best_adjRsquared_lambda)
                  p_adjRsquared <- length(which(final_adjRsquared_coefs != 0)) - 1 
                  n_adjRsquared<-nrow(testX)
                  testAdjRsquared<-elastic_adjrsquared_model %>% predict(newdata = testX) %>% R2(.,testY)
                  
                  
                  testAdjRsquared<-1 - ((1 - testAdjRsquared) * ((n_adjRsquared - 1) / (n_adjRsquared - p_adjRsquared - 1)))
                  
                  final_spearman_model <- elastic_spearman_model$finalModel
                  best_spearman_lambda <- elastic_spearman_model$bestTune$lambda
                  final_spearman_coefs <- coef(final_spearman_model, s = best_spearman_lambda)
                  p_spearman <- length(which(final_spearman_coefs != 0)) - 1 
                  testspearman<-elastic_spearman_model %>% predict(newdata = testX) %>% R2(.,testY)
                  
                  perf_elastic<-data.frame(corpus=c,tag=t,ppmi=p,setting=a,timespan=i,cutoff=j,impute=im,features=f,y=pr,
                                           train_dim=nrow(trainX),test_dim=n_adjRsquared,
                                           num_vars_rsquared=p_Rsquared,num_vars_adjrsquared=p_adjRsquared,num_vars_spearman=p_spearman,
                                           TrainRsquared=getTrainPerf(elastic_rsquared_model)[,"TrainRsquared"],TrainSpearman=getTrainPerf(elastic_spearman_model)[,"TrainSpearman"],TrainAdjRsquared=getTrainPerf(elastic_adjrsquared_model)[,"TrainadjR2"],
                                           TestRsquared=testRsquared,TestSpearman=testspearman,TestAdjRsquared=testAdjRsquared)
                  
                  print(perf_elastic)
                  varimp_elastic<-data.frame(corpus=c,tag=t,ppmi=p,setting=a,timespan=i,cutoff=j,impute=im,features=f,y=pr,train_dim=nrow(trainX),t(varImp(elastic_rsquared_model)$importance))
                  list_of_rsqr[[m]]<-perf_elastic
                  m<-m+1 
                  
                  if (i==10000) {
                    list_of_vi_10000[[v]]<-varimp_elastic
                    v<-v+1
                  } else if (i==10) {
                    list_of_vi_10[[v]]<-varimp_elastic
                    v<-v+1
                  }
                  
                  else if (i==20) {
                    list_of_vi_20[[v]]<-varimp_elastic
                    v<-v+1
                  } else if (i==50) {
                    list_of_vi_50[[v]]<-varimp_elastic
                    v<-v+1
                  } else if (i==100) {
                    list_of_vi_100[[v]]<-varimp_elastic
                    v<-v+1
                  }                                                                                                   
                  
                }
                rsquared_df<-bind_rows(list_of_rsqr)
                rsquared_df$cutoff<-as.factor(rsquared_df$cutoff)
                write.csv(rsquared_df,paste0(save_path,"rsquared_",c,"_",t,"_",p,"_",a,"_",i,"_",j,"_",im,"_",f,"_",pr,".csv"),row.names = FALSE)
                list_of_rsqr<-list()
                if (i==10000) {
                  varimp_10000_df<-bind_rows(list_of_vi_10000)
                  varimp_10000_df$cutoff<-as.factor(varimp_10000_df$cutoff)
                  varimp_10000_df[is.na(varimp_10000_df)] <- 0
                  print(varimp_10000_df)
                  write.csv(varimp_10000_df,paste0(save_path,"varimp_10000_",c,"_",t,"_",p,"_",a,"_",i,"_",j,"_",im,"_",f,"_",pr,".csv"),row.names = FALSE)
                  list_of_vi_10000<-list()
                  
                } else if (i==10) {
                  varimp_10_df<-bind_rows(list_of_vi_10)
                  varimp_10_df$cutoff<-as.factor(varimp_10_df$cutoff)
                  varimp_10_df[is.na(varimp_10_df)] <- 0
                  write.csv(varimp_10_df,paste0(save_path,"varimp_10_",c,"_",t,"_",p,"_",a,"_",i,"_",j,"_",im,"_",f,"_",pr,".csv"),row.names = FALSE)
                  list_of_vi_10<-list()
                } else if (i==20) {
                  varimp_20_df<-bind_rows(list_of_vi_20)
                  varimp_20_df$cutoff<-as.factor(varimp_20_df$cutoff)
                  varimp_20_df[is.na(varimp_20_df)] <- 0
                  write.csv(varimp_20_df,paste0(save_path,"varimp_20_",c,"_",t,"_",p,"_",a,"_",i,"_",j,"_",im,"_",f,"_",pr,".csv"),row.names = FALSE)
                  list_of_vi_20<-list()
                  
                } else if (i==50) {
                  varimp_50_df<-bind_rows(list_of_vi_50)
                  varimp_50_df$cutoff<-as.factor(varimp_50_df$cutoff)
                  varimp_50_df[is.na(varimp_50_df)] <- 0
                  write.csv(varimp_50_df,paste0(save_path,"varimp_50_",c,"_",t,"_",p,"_",a,"_",i,"_",j,"_",im,"_",f,"_",pr,".csv"),row.names = FALSE)
                  list_of_vi_50<-list()
                  
                } else if (i==100) {
                  varimp_100_df<-bind_rows(list_of_vi_100)
                  varimp_100_df$cutoff<-as.factor(varimp_100_df$cutoff)
                  varimp_100_df[is.na(varimp_100_df)] <- 0
                  write.csv(varimp_100_df,paste0(save_path,"varimp_100_",c,"_",t,"_",p,"_",a,"_",i,"_",j,"_",im,"_",f,"_",pr,".csv"),row.names = FALSE)
                  list_of_vi_100<-list()
                  
                } 
                
                
              }
            }
          }
        }
      }
    }
  }
  
  
}




