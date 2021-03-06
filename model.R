# Best method to remove variables in R Memory

# rm(list=setdiff(ls(), removed))

# where x could be name of any file present

# Another Option : change List to Grid and delete 

# This step more useful as it helps in efficient memory usage


removed <- c(test_raw, train_raw, cl, class_new, class_old, depth, cnames, dtrain, dval, eta, f, 
             
             feature.names, i, j, len, levels, nam, name, numberOfClasses, start, time_taken, 
             
             watchlist, my.f2cnt, my.f3cnt, tmp_str, tmp_new, lnth
             
             )

rm(list=setdiff(ls(), removed))


#feature hashing

train_hash <- train

train_hash[is.na(train_hash)] <- 0

split <- createDataPartition(y = train_hash$TripType, p = 0.9, list = F) 

training <- train_hash[split,]

validation <- train_hash[-split,]

training_hash = hashed.model.matrix(~., data=training[,feature.names],  hash.size=2^16,  
                                    
                                    transpose=FALSE, create.mapping=TRUE, is.dgCMatrix = TRUE)

validation_hash = hashed.model.matrix(~., data=validation[,feature.names],  hash.size=2^16,  
                                      
                                      transpose=FALSE, create.mapping=TRUE, is.dgCMatrix = TRUE)

response_val <- train_hash$TripType[-split]

response_train <- train_hash$TripType[split]

dval <- xgb.DMatrix(data=validation_hash, label = response_val )

dtrain <- xgb.DMatrix(data=training_hash,  label = response_train)

watchlist <- list(val=dval, train=dtrain)

clf <- xgb.train(params = param, data = dtrain, nrounds = 500, watchlist = watchlist,
                 
                 verbose = 1, maximize = T)



#################################################################################################

#normal training method

feature.names <- names(train)[-c(179) ]

tra <- train[, feature.names]

split <- createDataPartition(y = train_raw$TripType, p = 0.9, list = F) 

response_val <- train_raw$TripType[-split]

response_train <- train_raw$TripType[split]

dval <- xgb.DMatrix( data = data.matrix(tra[-split,]),  label = response_val )

dtrain <- xgb.DMatrix( data = data.matrix(tra[split,]), label = response_train)

#sum(is.na(train)); sum(is.na(test)) # test if found NA error

watchlist <- list(val=dval, train=dtrain)

#basic training----------------------------------------------------------------------------------

numberOfClasses <- max(train_raw$TripType) + 1

param <- list(objective = "multi:softprob",
              
              eval_metric = "mlogloss",
              
              num_class = numberOfClasses,
              
              max_depth = 12,
              
              eta = 0.01,
              
              colsample_bytree = 0.8,
              
              subsample = 0.8
              
)

gc()


cl <- makeCluster(detectCores()); registerDoParallel(cl)


start <- Sys.time()


#############################################################################################################


clf <- xgb.train(params = param, data = dtrain, nrounds = 20, watchlist = watchlist,
                 
                 verbose = 1, maximize = T, nthread = 2
)


time_taken <- Sys.time() - start


#############################################################################################################


#grid search

for (depth in c(10, 15, 20,25)) {
  
  for(eta in c(0.03, 0.02, 0.01)){
    
    # train
    param <- list(objective = "multi:softprob",
                  
                  eval_metric = "mlogloss",
                  
                  num_class = numberOfClasses,
                  
                  max_depth = depth ,
                  
                  eta = eta
                  
    )
    
    
    clf <- xgb.train(params = param, data = dtrain, watchlist = watchlist, nrounds = 5,
                     
                     verbose = 1, maximize = T, nthread = 2)
    gc()
    
    
    xgb.save(clf, paste0("D:/kaggle/walmart_seg/models/", "clf","_", depth, "_", eta, ".R") )
    
    #scoring to be done -- issues with function scoring
    
  }     
}



Time_Taken <- Sys.time() - start


# NOT USING THE SUBMISSION FUNCTION PRED FUNCTION FOR NOW 11-10-2015

#submit(clf, test, "1172015.csv")

pred <- predict(clf, data.matrix(test[, feature.names])) 

pred <- matrix(pred, nrow=38, ncol=length(pred)/38) #there are total 38 classes 

pred <-  data.frame(t(pred))

sample <- read_csv("D:/kaggle/walmart_seg/Data/sample_submission.csv") 

cnames <- names(sample)[2:ncol(sample)] 

names(pred) <- cnames

submission <- cbind.data.frame(VisitNumber = visit_num , pred) 

submission <- setDT(submission)

submission <- (submission[ , lapply(.SD, mean), by = VisitNumber])

write_csv(submission, "D:/kaggle/walmart_seg/submission/11202015_1.csv")


####################################################################################################################


#save and retrain model later


ptrain <- predict(clf, dtrain, outputmargin = T)


setinfo(dtrain, "base_margin", ptrain)


clf_extra <- xgboost(params = param, data = dtrain, nround = 1500)
