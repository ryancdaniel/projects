#Supervisor requested info on how often we mail the same address but different individual
#Author: Ryan Daniel
#Version: 1

library(openxlsx)
library(sqldf)
library(RMySQL)

#Set connection to AWS server
mydb = dbConnect(MySQL() 
                 , user='xxx'
                 , password='xxxxx'
                 , dbname='x'
                 , host='x.amazonaws.com')


#Coalesce Function
coalesce <- function(...) {
  apply(cbind(...), 1, function(x) {
    x[which(!is.na(x))[1]]
  })
}

#Returns string w/o leading or trailing whitespace
trim <- function (x) gsub("^\\s+|\\s+$", "", x)

#SQL query for records with same Address Info but different name, excluding seed addresses, and internet data
dist_individual_query <- "SELECT CONCAT(LEFT(ADDRESSLINE1, 40),LEFT(ZIP,5)) AS MATCHKEY, 
        	                       COUNT(*) AS total_mailings, 
                                 COUNT(DISTINCT FNAME) AS unique_individuals,
                                 MIN(WAVE) AS first_week_mailed,
                                 MAX(WAVE) AS last_week_mailed
                          FROM recipients
                          WHERE CLIENT_NAME = 'X'
                            AND TYPE NOT LIKE '%INTERNET%'
                            AND MAIL_DATE BETWEEN '2025-01-01' AND curdate()
                            AND NOT ADDRESSLINE1 = '3475 PIEDMONT RD NE STE 1000'
                            AND NOT ADDRESSLINE1 = '22342 AVENIDA EMPRESA STE 100'
                          GROUP BY MATCHKEY
                          ORDER BY total_mailings DESC, unique_individuals DESC;"

df <- dbGetQuery(mydb, dist_individual_query)

#Check a couple rows/headers for output
head(df)

#Total unique addresses
nrow(df)

#Addresses with multiple individuals
sum(df$unique_individuals > 1)

#output as a CSV if needed for further analysis
write.csv(df,file="C:/Users/Ryan Daniel/Desktop/distinct address.CSV", row.names=FALSE,na = "")
