# Loading the packages
library(data.table)
library(dplyr)
library(ggplot2)
library(lubridate)
library(gridExtra)
library(rlang)
library(randomForest)
library(caret)
library(ROSE)

# Loading the file
train_sample <- fread('train_sample.csv') # dataset for training

# Checking if there are missing values
if(nrow(train_sample) !=  nrow(na.omit(train_sample))){
  print("One or more missing values were found")
}else{
  print("No missing values were found")
}

# DATA EXPLORATION
# Premises:
# 1 - Variables which a high number of downloads have the potential to be strategical;
# 2 - Being part of the most downloads and having a high rate of download, these variables will be suggested
# as strategical for probably having a strong conection with the success
# 3 - Strategical variables are important to be put in details, to bring up possible patterns and be explored
# in a trying to get betters results. (This exploration can't be done with this dataset)

# Checking the importance to keep attributed_time in the data set
# Assuming that attributed_time is filled only if is_attributed is setted with 1,
# the count of occurrences should return 0 if it's OK. Otherwise, if the return is
# more than 0, there are inconsistences
count(train_sample %>%
        select(attributed_time, is_attributed) %>%
        filter(attributed_time != '' & is_attributed == 0))

# As expected, the return was 0. So, it's being considered redundant to work with both variables.

# Verifying the difference in days, between the date of click, and the date of the download
# Assuming that, to consider the download as consequence of the advertising, the interval
# in days between the click on the ad and the start of the download has to be less than 1 day.
# So, if there aren't intervals over 1 day, it's possible to consider either attributed_time or
# click_time to make analysis regarding time.
if(count(train_sample %>%
         select(attributed_time, click_time) %>%
         filter(attributed_time != '') %>%
         mutate(difference = as.Date(attributed_time) - as.Date(click_time)) %>%
         filter(difference > 1)) > 0){
  print("The interval between de click and the download aren't connected")
} else {
  print('The interval is irrelevant')
}
# As expected, the interval is irrelevant. So, at this point, attributed_time will be discarded.
colnames(train_sample)
train_sample <- train_sample[, -7]

# The variable IP should represent the id of the connection, what could be the id of an user, or a network
# A premise for IP: if there are only unique values, so it should not be representative to explore. On the
# other hand, it should be included in other analysis.
nrow(data.frame(table(train_sample$ip)) %>% filter(Freq > 1) %>% select(Freq))
# As established before, with 17.434 occurencies of two or more clicks, it may be kept at this point

# ANALYSIS OF DOWNLOAD RATES ALONG PERIODS OF DAY

# Data set with the date and status of the download
period_download <- train_sample %>% select(click_time, is_attributed)

# hour_download to analyse the download rate along the day
hour_download <- period_download %>%
  mutate(hour = sapply(click_time, hour))

# Clustering the periods of the day
# from 00:00 to 07:59 am = 1
# from 08:00 to 04:59 pm = 2
# from 5:00pm to 11:59 pm = 3
set_period <- function(x){
  if(x <= 7){
    return(1)
  } else if (x <= 16){
    return(2)
  } else {
    return(3)
  }
}

# period_download to analyse the download rate along the periods of the day
period_download <- period_download %>% mutate(period = sapply(hour(click_time), set_period))

# is_attributed's being considered as numeric to calculate the rate of download
period_download$is_attributed <- as.numeric(period_download$is_attributed)
str(period_download)

# Calculating the download rate by period
period_download <- distinct(period_download %>%
                              group_by(period) %>%
                              mutate(
                                total_clicks = n(),
                                total_downloads = sum(is_attributed),
                                download_rate = (total_downloads / total_clicks) * 100
                              ) %>%
                              select(period, download_rate), period, .keep_all = TRUE)

# Setting hour and period as factor
period_download$period <- as.factor(period_download$period)

# Plot of download rate by period of the day
period_plot <- ggplot(period_download) +
  geom_col(aes(period, download_rate), fill = 'lightblue', color = 'darkblue', alpha = 0.7) +
  ggtitle('DOWNLOAD RATE BY PERIOD OF THE DAY') +
  xlab('Period') +
  ylab('Download Rate') +
  theme(plot.title = element_text(hjust = 0.5, vjust = 0.5, face = 'bold'))

# is_attributed's being considered as numeric to calculate the rate of download
hour_download$is_attributed <- as.numeric(hour_download$is_attributed)
str(hour_download)

# Calculating the download rate by hour
hour_download <- distinct(hour_download %>%
                            group_by(hour) %>%
                            mutate(
                              total_clicks = n(),
                              total_downloads = sum(is_attributed),
                              download_rate = (total_downloads / total_clicks) * 100,
                              period = sapply(hour, set_period)
                            ) %>%
                            select(hour, download_rate, period), hour, .keep_all = TRUE)

# Setting hour and period as factors
hour_download$hour <- as.factor(hour_download$hour)
hour_download$period <- as.factor(hour_download$period)

# Plot of download rate per hour
hour_plot <- ggplot(hour_download, aes(hour, download_rate, group = 1)) +
  geom_point(aes(color = factor(period, labels = c('First', 'Second', 'Third'))), size = 4) +
  theme(legend.position = 'bottom') +
  labs(color = 'Period') +
  geom_line() +
  ggtitle('DOWNLOAD RATE PER HOUR') +
  xlab('Hour') +
  ylab('Download Rate') +
  theme(plot.title = element_text(hjust = 0.5, vjust = 0.5, face = 'bold'),
        legend.title = element_text(face = 'bold'))

grid.arrange(period_plot, hour_plot, nrow = 2)

# FIRST CONCLUSIONS
# As shown in the plots, the first period has the highest rate of download with a shorter variation,
# even though there's not much difference from others, which turns it difficult to make explicit conclusions.
# Since there are few dates and few download variation rate along the day, it's being considered
# only the hours of the click as a time variable.
train_sample <- train_sample %>% mutate(hour = sapply(click_time, hour)) %>% select(-click_time)

# ADDITIONAL ANALYSIS
# Calculating the download rate, frequency of download and cumulative frequency of download by app,
# device, os and channel

# Function to capitalize the first letter
cap_first <- function(x) {
  txt <- strsplit(x, " ")[[1]]
  paste(toupper(substring(txt, 1,1)), substring(txt, 2),
        sep="", collapse=" ")
}

# Function to calculate and plot the analysis
down_rate <- function(variable){
  target <- parse_quosure(variable) # quo
  df <- data.frame(train_sample %>% select(!!target, is_attributed))
  number <- length(unique(df[, variable])) # calculating the number of the target uniques
  
  # Calculating the total of clicks and downloads, and download rate
  df <- distinct(df %>%
                   group_by(!!target) %>%
                   mutate(
                     total_clicks = n(),
                     total_downloaded = sum(is_attributed),
                     download_rate = (total_downloaded / total_clicks) * 100
                   ) %>%
                   select(!!target, total_clicks, total_downloaded, download_rate))
  
  # Reordering the data set by total_clicks
  setorder(df, -total_downloaded)
  
  # Calculating the cumulative clicks and cumulative frequency of clicks
  df <- df %>% transform(download_cum = cumsum(total_downloaded), download_freq = prop.table(total_downloaded))
  df <- df %>% transform(down_freq_cum = cumsum(download_freq)) %>%
    select(!!target, total_clicks, total_downloaded, download_rate, down_freq_cum)
  
  # Plotting targets which represents 80% of the download total
  df[, variable] <- as.factor(df[, variable])
  if(nrow(df %>% filter(down_freq_cum <= 0.8)) <= 1){
    df <- df[1:2,]
  } else if (nrow(df %>% filter(down_freq_cum <= 0.8)) > 20){
    df <- df[1:20,]
  } else{
    df <- df %>% filter(down_freq_cum <= 0.8)
  }
  cumulative_freq <- max(df$down_freq_cum)
  
  ggplot(df) +
    geom_col(aes(!!target, download_rate), fill = 'lightblue', color = 'darkblue', alpha = 0.7) +
    coord_flip() +
    theme(legend.position = 'bottom') +
    ggtitle(paste(
      'DOWNLOAD RATE OF THE ',
      toupper(variable),
      ' WHICH SUM ABOUT ',
      round(cumulative_freq * 100),
      '% OF THE DOWNLOADS'
      , sep = '')) +
    xlab(cap_first(variable)) +
    ylab('Download Rate') +
    labs(subtitle = paste(
      round((nrow(df) / number)*100, 2),
      '% of the ',
      variable,
      's represent about ',
      round(cumulative_freq * 100),
      '% of the downloads',
      sep = '')) +
    geom_text(
      data = df,
      aes(x = !!target, y = download_rate, label = paste(round(download_rate, 2), '%', sep = '')),
      hjust = -0.1) +
    theme(plot.title = element_text(hjust = 0.5, vjust = 0.5, face = 'bold'),
          plot.subtitle = element_text(hjust = 0.5, vjust = 0.5)) +
    ylim(0, 100)
}

# Analysis
variables <- c('ip', 'app', 'device', 'os', 'channel')
lapply(variables, down_rate)

# CONCLUSIONS
# Function to calculate the % of download by variable
calc_perc <- function(variable, value){
  target <- parse_quosure(variable) # quo
  perc <- round(
    (sum(train_sample %>%
           filter(!!target == value) %>%
           select(is_attributed)) / sum(train_sample$is_attributed) * 100)
    , 2)
  return(perc)
}

# IP
# Six IPs between the 11% most downloadable have 100% of download rate: 330861, 309576, 272894, 224120,
# 131029, 79001
calc_perc('ip', '330861')
calc_perc('ip', '309576')
calc_perc('ip', '272894')
calc_perc('ip', '224120')
calc_perc('ip', '131029')
calc_perc('ip', '79001')
# With 2.64% of the download total, these IPs could be more detailed trying to bring up some pattern
# and be strategic used to improve the ads.

# APP
# Between the APPs which represent about 80% of the downloads, the only which may be considered relevant
# for strategic actions is the 35, with 55.1% of download rate.
# This app represents 11.89% of the total of downloads
calc_perc('app', '35')

# DEVICE
# Two devices represent the total of 87% of the downloads. But, they shouldn't be considered strategically
# because of their low rate

# OS
# Between the OSs which represent about 80% of the downloads, the 61 could be considered strategicaly important
# once it has 100% of download rate. However, they represent only 1.76% of the downloads, which may be irrelevant
calc_perc('os', '61')

# CHANNEL
# Two channels are significant with 70.59% and 71.43% of download rate respectively: 274 and 5.
# Together they represent 7.49% of the downloads
calc_perc('channel', '274')
calc_perc('channel', '5')

# GENERAL
# Although there are features that can be strategic, alone they may be irrelevant. On the other hand, would
# be important to explore them with more details to check if it's possible to realize their strenghs and
# share them to other features.

# BUILDING THE MODEL
# Once the problem nature is a binary classification, the possible results must be balanced to reproduce
# a good performance for both one.

distribution <- data.frame(table(train_sample$is_attributed))
distribution <- distribution %>% mutate (perc = round((Freq / sum(Freq) * 100), 2))

# Checking the results distribution
unballanced <- ggplot(distribution) +
  geom_col(aes(x = Var1, y = Freq), fill = 'lightblue', color = 'darkblue', alpha = 0.7) +
  ggtitle('DISTRIBUTION OF RESULTS - BEFORE') +
  geom_text(data = distribution, aes(x = Var1, y = Freq, label = paste(perc, "%", sep='')), vjust = -1) +
  xlab('Result') +
  ylab('Frequency') +
  ylim(0, max(distribution$Freq) * 1.05) +
  theme(plot.title = element_text(hjust = 0.5, vjust = 0.5, face = 'bold')) +
  scale_x_discrete(labels = c('0' = 'Not downloaded', '1' = 'Downloaded'))


grid.arrange(unballanced, nrow = 1)

# As shown in the plot, the results aren't balanced. So in case of the first model don't be able to predict
# both, downloaded and not downloaded occurences, this information will must be considered.

#####################################################################

# Saving the original data set into a new set to train the model
new_sample <- train_sample
# Checking the format of the variables:
# ip, app, device, os, channel, hour and is_attributed are categorical variables. But, the uniques known variables
# are: is_attributed and hour
new_sample <- data.frame(new_sample)
categorical_train <- c('is_attributed', 'hour')
new_sample[, categorical_train] <- lapply(new_sample[, categorical_train], factor)

# Spliting the dataset into train_set and test_set with a ratio of 70% / 30% for train / test respectively
# Setting seed to reproduce the same values
set.seed(50)
values <- c(sample.int(nrow(new_sample), 0.7*nrow(new_sample), replace = FALSE))
train_set_1 <- new_sample[values, ]
test_set_1 <- new_sample[-values, ]

# Training and evaluating the performance of the model
model_1 = randomForest(is_attributed ~ ., data = train_set_1, ntree = 10, nodesize = 10)
prediction_1 = data.frame(obs = test_set_1$is_attributed,
                      pred = predict(model_1, newdata = test_set_1))

model_1
# The first model returns a low error rate, but with a FALSE NEGATIVE error by 88.67%
confusionMatrix(prediction_1$obs, prediction_1$pred)
# Although the Accuracy of testing the model with de test_set reaches 99.78%, the result of False Negative
# represents a low performance, as previous expected.
# So, the first trying to improve the general performance, is ballancing the results of the data set.
over_new_sample <- new_sample

over_new_sample <- ovun.sample(is_attributed ~ .,
                               data = new_sample,
                               method = "over",
                               N = nrow(new_sample) + nrow(new_sample %>% filter(is_attributed == 0)))$data

distribution_over <- data.frame(table(over_new_sample$is_attributed))
distribution_over <- distribution_over %>% mutate (perc = round((Freq / sum(Freq) * 100), 2))

# Checking the results distribution
ballanced <- ggplot(distribution_over) +
  geom_col(aes(x = Var1, y = Freq), fill = 'lightblue', color = 'darkblue', alpha = 0.7) +
  ggtitle('DISTRIBUTION OF RESULTS - AFTER') +
  geom_text(data = distribution_over, aes(x = Var1, y = Freq, label = paste(perc, "%", sep='')), vjust = -1) +
  xlab('Result') +
  ylab('Frequency') +
  ylim(0, max(distribution_over$Freq) * 1.05) +
  theme(plot.title = element_text(hjust = 0.5, vjust = 0.5, face = 'bold')) +
  scale_x_discrete(labels = c('0' = 'Not downloaded', '1' = 'Downloaded'))

grid.arrange(unballanced, ballanced, ncol = 2)

# Training and evaluating the second model
# Spliting the data set into train_set and test_set with a ratio of 70% / 30% for train / test respectively
# Setting seed to reproduce the same values
set.seed(50)
values <- c(sample.int(nrow(over_new_sample), 0.7*nrow(over_new_sample), replace = FALSE))
train_set_2 <- over_new_sample[values, ]
test_set_2 <- over_new_sample[-values, ]

# Training and evaluating the performance of the model
model_2 = randomForest(is_attributed ~ ., data = train_set_2, ntree = 10, nodesize = 10)
prediction_2 = data.frame(obs = test_set_2$is_attributed,
                      pred = predict(model_2, newdata = test_set_2))

model_2
# With the balanced data set, the error rate and the FALSE NEGATIVE were reduced as expected, on the other
# hand there was an increasement in FALSE POSITIVE
confusionMatrix(prediction_2$obs, prediction_2$pred)
# With an accuracy of 99.88% testing with the test_set, this model is even better than the first.
# Trying to reach a better performance for FALSE POSITIVE and FALSE NEGATIVE, it was tested
# the importance of the variables

model_2_imp <- randomForest(is_attributed ~ ., data = train_set_2, ntree = 10, nodesize = 10, importance = TRUE)
varImpPlot(model_2_imp)

# With device being the minus important in Mean Decrease Accuracy, and the second one in Mean Decrease Gini
# at this time this variable isn't being considered for the third model
# Setting seed to reproduce the same values
set.seed(50)
values <- c(sample.int(nrow(over_new_sample), 0.7*nrow(over_new_sample), replace = FALSE))
train_set_3 <- over_new_sample[values, ]
colnames(train_set_3)
train_set_3 <- train_set_3[, -3]
test_set_3 <- over_new_sample[-values, ]
test_set_3 <- test_set_3[, -3]

# Training and evaluating the performance of the model
model_3 = randomForest(is_attributed ~ ., data = train_set_3, ntree = 10, nodesize = 10)
prediction_3 = data.frame(obs = test_set_3$is_attributed,
                          pred = predict(model_3, newdata = test_set_2))

model_3
# With the balanced data set, the error rate and the FALSE NEGATIVE were reduced as expected, but there was
# a increasement in FALSE POSITIVE
confusionMatrix(prediction_3$obs, prediction_3$pred)
# With an accuracy reaching 99.9% and a better ballance between FALSE POSTIVE
# and FALSE NEGATIVE, this model is quite better than the other two.
