library( tidyverse )
library( VGAM )  # proportional odds models
library( nnet )  # for multinomial logit models
library( survey ) # for modeling complex survey data
library( RNHANES ) # for downloading raw NHANES data
library( haven ) # for reading in foreign file formats (eg., .XPT files)


### Read-in Data/Data-Wrangling ###
# ---------------------------------------------------------------------------------------------------------------------------------------------------------

# read in raw data file
d <- read.csv( "01-Data-Raw/ca_hei.csv")

# read in helper function
source( "R/utils.R")

## read in NHANES data to get correct SDMVPSU and SDMVSTRA and weights ##
## the raw dataset povided has a number of missing values for these critical variables ##

# read/assign data from `RHANES` package
cycs <- paste0( "0", c( 7, 9, 11, 13 ) )
yrs <- c( "2007-2008", "2009-2010", "2011-2012", "2013-2014")

for ( i in 1:length( yrs ) ){
  
assign( paste0( "dem.", cycs[i] ) , nhanes_load_data( "DEMO", yrs[i] ) )
  
}

# manually import 2015-16 and 2017-18 data
dem.015 <- read_xpt( file = 'https://wwwn.cdc.gov/Nchs/Nhanes/2015-2016/DEMO_I.XPT' )
dem.017 <- read_xpt( file = 'https://wwwn.cdc.gov/Nchs/Nhanes/2017-2018/DEMO_J.XPT' )

# row bind the relevant columns
bind.sdvm <- rbind( dem.07[, c( "SEQN", "SDMVSTRA", "SDMVPSU", "WTINT2YR" ) ],
       dem.09[, c( "SEQN", "SDMVSTRA", "SDMVPSU", "WTINT2YR"  ) ], 
       dem.011[, c( "SEQN", "SDMVSTRA", "SDMVPSU", "WTINT2YR"  ) ], 
       dem.013[, c( "SEQN", "SDMVSTRA", "SDMVPSU", "WTINT2YR"  ) ], 
       dem.015[, c( "SEQN", "SDMVSTRA", "SDMVPSU", "WTINT2YR"  ) ],
       dem.017[, c( "SEQN", "SDMVSTRA", "SDMVPSU", "WTINT2YR"  ) ] )



# compute quartiles only on cancer survivors and generate normalized weights (note: first adjust weights based on number of cycles in the analysis)
( d.2 <- d %>%
  filter( CA == 1 ) %>%   # filter cancer survivors
  mutate( hei.q4 = as.factor( quant_cut( "HEI2015_TOTAL_SCORE", 4, . ) ),
          fafh.q4 = as.factor( quant_cut( "FAFH", 4, . ) ) ) %>% # rank variables for HEI and FAFH
  full_join( d, . ) %>% # full join back to original data to keep all rows intact for analysis
  select( -c( SDMVPSU, SDMVSTRA, WTINT2YR ) ) %>%
  left_join( . , bind.sdvm, by = "SEQN" ) %>%
  mutate( WTINT5YR = WTINT2YR / 5,
          norm.wt = WTINT5YR / mean( bind.sdvm$WTINT2YR, na.rm = T ) ) )%>% # recompute weights and compute normalized weights
  write.csv( ., "02-Data-Wrangled/hei-correct-wts.csv")

# datasets for stratified analyses #
d.2.fi <- d %>% # food insecure
  filter( CA == 1 & foodsec_bin == 1 ) %>%   # filter cancer survivors and food insecure
  mutate( hei.q4 = as.factor( quant_cut( "HEI2015_TOTAL_SCORE", 4, . ) ),
          fafh.q4 = as.factor( quant_cut( "FAFH", 3, . ) ) ) %>% # rank variables for HEI and FAFH
  full_join( d, . ) %>% # full join back to original data to keep all rows intact for analysis
  select( -c( SDMVPSU, SDMVSTRA, WTINT2YR ) ) %>%
  left_join( . , bind.sdvm, by = "SEQN" ) %>%
  mutate( WTINT5YR = WTINT2YR / 5,
          norm.wt = WTINT5YR / mean( bind.sdvm$WTINT2YR, na.rm = T ) ) # recompute weights and compute normalized weights

# datasets for stratified analyses #
d.2.fs <- d %>% # food secure
  filter( CA == 1 & foodsec_bin == 0 ) %>%   # filter cancer survivors and food secure
  mutate( hei.q4 = as.factor( quant_cut( "HEI2015_TOTAL_SCORE", 4, . ) ),
          fafh.q4 = as.factor( quant_cut( "FAFH", 3, . ) ) ) %>% # rank variables for HEI and FAFH
  full_join( d, . ) %>% # full join back to original data to keep all rows intact for analysis
  select( -c( SDMVPSU, SDMVSTRA, WTINT2YR ) ) %>%
  left_join( . , bind.sdvm, by = "SEQN" ) %>%
  mutate( WTINT5YR = WTINT2YR / 5,
          norm.wt = WTINT5YR / mean( bind.sdvm$WTINT2YR, na.rm = T ) ) # recompute weights and compute normalized weights

# ---------------------------------------------------------------------------------------------------------------------------------------------------------




### Fit Models ###
# ---------------------------------------------------------------------------------------------------------------------------------------------------------

## proportional odds model (not used) ##
mod3 <- vglm( factor( hei.q4, ordered = T ) ~ fafh.q4 + Gender2 +
                Age + Race2 +HHSize2 + IncPovRat2 + EDU + MartitalStat_cat +
                FoodAsstP2 + SmokStat + ALCUSE2,
              family = propodds( reverse = FALSE ), data = d.2, weights = norm.wt  )

summary( mod3 )


## multinomial logistic regression models ##


# fit on entire sample
mult.mod <- multinom( factor( hei.q4, ordered = T ) ~ fafh.q4 + Gender2 +
            Age + Race2 +HHSize2 + IncPovRat2 + EDU + MartitalStat_cat +
            FoodAsstP2 + SmokStat + ALCUSE2,
            data = d.2, weights = norm.wt )

# fit on food insecure subset
mult.mod.fi <- multinom( factor( hei.q4, ordered = T ) ~ fafh.q4 + Gender2 +
                        Age + Race2 +HHSize2 + IncPovRat2 + EDU + MartitalStat_cat +
                        FoodAsstP2 + SmokStat + ALCUSE2,
                      data = d.2.fi, weights = norm.wt )

# fit on food secure subset
mult.mod.fs <- multinom( factor( hei.q4, ordered = T ) ~ fafh.q4 + Gender2 +
                           Age + Race2 +HHSize2 + IncPovRat2 + EDU + MartitalStat_cat +
                           FoodAsstP2 + SmokStat + ALCUSE2,
                         data = d.2.fs, weights = norm.wt )

# ---------------------------------------------------------------------------------------------------------------------------------------------------------


### Results-Generating Function ###
# ---------------------------------------------------------------------------------------------------------------------------------------------------------

# create function to generate results #

res_fun <- function( model.object ){
  
# save model summary
sum.mm <- summary(model.object)

# exponentiate coefficients to get OR's
odds <- exp( sum.mm$coefficients )

# confidence intervals
ci <- exp( confint( model.object) ) # generates an object of class `array` with tables for CI's that are exponentiated so we get confidence bounds for ORs
dim.ci <- dim( ci )[3] # dimensions in `ci` array
len.ci <- dim( ci )[1] # length in `ci` array
ci.df <- data.frame( coln = 1: len.ci ) # initialize data.frame for results storage

# loop for table of confidence intervals
for( i in 1:dim.ci ){
  
  extr.ci <- ci[,,i] # extract ith dimension from the array
  ci.df <- cbind( ci.df, extr.ci ) # append data frame ith dimension to existing df
  ci.df <- cbind( ci.df, data.frame( rep( "", len.ci[1] ) ) ) # add a blank space in between ci df's
  colnames( ci.df )[ ncol( ci.df ) ] <- paste0( "blank.", i ) # rename blank columns
}


# mean predicted probabilities across levels of FAFH
pp <- predict( model.object, type = "probs" ) %>% # fitted values (probability)
  data.frame() %>% # convert to df
  mutate( id = rownames( . ) ) %>% # create id variable using rownames for subsequent join
  left_join( ., d.2 %>%
               mutate( id = rownames( . ) ) %>%
               dplyr::select( id, fafh.q4 ) )  # left_join FAFH variable from original data

pp.by <- by( pp[1:4], pp$fafh.q4, colMeans) # compute mean predicted probabilities across classes of FAFH

# generate final table for save and export
pp.tab <- data.frame(do.call("rbind", pp.by ) ) %>%
  mutate( FAFH = paste0( "FAFH", 1:4) ) %>%
  relocate( FAFH, .before = X1 )

colnames( pp.tab ) <- c( "FAFH", paste0( "HEI.Q", 1:4 ) )

return( list( coefs = odds, conf.int = ci.df, pred.probs = pp.tab ) )
}
# ---------------------------------------------------------------------------------------------------------------------------------------------------------



### Generate Results ###
# ---------------------------------------------------------------------------------------------------------------------------------------------------------

## run function on entire sample ##
ent.samp <- res_fun( mult.mod )

# save tables in CSV format for entire sample
write.csv( ent.samp$coefs, "03-Tables-Figures/01-modelor.csv")
write.csv( ent.samp$conf.int, "03-Tables-Figures/01-modelci.csv")
write.csv( ent.samp$pred.probs, "03-Tables-Figures/01-modelpp.csv")


## run function on food insecure subset ##
fi.samp <- res_fun( mult.mod.fi )

# save tables in CSV format for fi sample
write.csv( fi.samp$coefs, "03-Tables-Figures/02-modelorfi.csv")
write.csv( fi.samp$conf.int, "03-Tables-Figures/02-modelcifi.csv")
write.csv( fi.samp$pred.probs, "03-Tables-Figures/02-modelppfi.csv")


## run function on food secure subset ##
fs.samp <- res_fun( mult.mod.fs )

# save tables in CSV format for fs sample
write.csv( fs.samp$coefs, "03-Tables-Figures/03-modelorfs.csv")
write.csv( fs.samp$conf.int, "03-Tables-Figures/03-modelcifs.csv")
write.csv( fs.samp$pred.probs, "03-Tables-Figures/03-modelppfs.csv")
# ---------------------------------------------------------------------------------------------------------------------------------------------------------



### Multiple Regression and Poisson Regression Models ###
# ---------------------------------------------------------------------------------------------------------------------------------------------------------

# use functions from `survey` package

# specify survey design
des <- svydesign( id = ~SDMVPSU, weights = ~WTINT5YR, strata = ~SDMVSTRA, 
          nest = TRUE, survey.lonely.psu = "adjust", data = d.2)

# subset the survey design appropriately using `subset` to specify the subset we will
# be working with
des.ca <- subset( des, CA == 1 )

# PercFAFH outcome variable
hist( d.2$PercFAFH, breaks = 30 ) # strong right skew, consider alternative modeling strategy
p.fafh <- svyglm( PercFAFH ~ factor( foodsec_bin ) + Gender2 +
          Age + Race2 +HHSize2 + IncPovRat2 + EDU + MartitalStat_cat +
          FoodAsstP2 + SmokStat + ALCUSE2, design = des.ca )

p.fafh.sum <- summary( p.fafh ) # store model results
coef.table.p.fafh <- p.fafh.sum$coefficients # coefficients table for saving

# FAFH outcome variable
hist( d.2$FAFH, breaks = 30 ) # strong right skew, consider alternative modeling strategy
fafh <- svyglm( FAFH ~ factor( foodsec_bin ) + Gender2 +
                    Age + Race2 +HHSize2 + IncPovRat2 + EDU + MartitalStat_cat +
                    FoodAsstP2 + SmokStat + ALCUSE2, design = des.ca )

fafh.sum <- summary( fafh )  # store model results
coef.table.fafh <- fafh.sum$coefficients # coefficients table for saving

# Mealsout outcome variable (used Poisson model given this is a count variable)
mlsout <- svyglm( Mealsout ~ factor( foodsec_bin ) + Gender2 +
                  Age + Race2 +HHSize2 + IncPovRat2 + EDU + MartitalStat_cat +
                  FoodAsstP2 + SmokStat + ALCUSE2, family = "poisson",
                design = des.ca )

mlsout.sum <- summary( mlsout )  # store model results
coef.table.mlsout <- data.frame( mlsout.sum$coefficients ) # coefficients table for saving
coef.table.mlsout$Estimate <- exp( coef.table.mlsout$Estimate )
# save coefficients tables
write.csv( coef.table.p.fafh, "03-Tables-Figures/04-perc-fafh-reg-coef.csv")
write.csv( coef.table.fafh, "03-Tables-Figures/05-fafh-reg-coef.csv")
write.csv( coef.table.mlsout, "03-Tables-Figures/06-mlsout-reg-coef.csv")
# ---------------------------------------------------------------------------------------------------------------------------------------------------------

