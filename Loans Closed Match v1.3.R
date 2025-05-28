#Match a Client's closed loans/sales to records from the database to identify which campaign converted
#Author: Ryan Daniel
#Version: 1.3

library(openxlsx)
#library(XLConnect)
library(sqldf)
library(RMySQL)

#Set connection to AWS server
mydb = dbConnect(MySQL() 
                 , user='xxx'
                 , password='xxxxx'
                 , dbname='x'
                 , host='xxxxxx.amazonaws.com')

#Coalesce Function
coalesce <- function(...) {
  apply(cbind(...), 1, function(x) {
    x[which(!is.na(x))[1]]
  })
}

#Returns string w/o leading or trailing white space
trim <- function (x) gsub("^\\s+|\\s+$", "", x)

#Read in Closed Loans File (Standardized)
Closed <- "C:/Users/Ryan Daniel/Desktop/Closed Loans from x client.xlsx"
ClosedDF <- read.xlsx(Closed,sheet=1,colNames=T)

#Create Matchkey Field for Uniqueness, Acting as a foregin key
ClosedDF$MATCHKEY <- paste0(substr(ClosedDF$Address.Line.1, 1, 40), substr(ClosedDF$ZIP.Code, 1, 5))

#Spot Check cloeddf Records
head(ClosedDF)

#SQL query for all records in presumed closed range#
DF1_recipients <- "SELECT *
                        , CONCAT(LEFT(ADDRESSLINE1, 40),LEFT(ZIP,5)) AS MATCHKEY
                    FROM recipients
                    WHERE client_name = 'x'
                    AND MAIL_DATE BETWEEN '2024-11-01' AND '2025-03-31'"

DF1 <- dbGetQuery(mydb, DF1_recipients)

#Spot Check DF1 Records
nrow(DF1)
head(DF1)

detach("package:RMySQL", unload=TRUE)
#JOIN the 'DF1_recipients' information to 'ClosedDF' records based on Matchkey
joined_df <- sqldf("SELECT ClosedDF.*, DF1.*
                    FROM ClosedDF
                    LEFT JOIN DF1
                    ON ClosedDF.MATCHKEY = DF1.MATCHKEY")


sqldf("select count(*) as count
              , count(distinct Offer_code) as dist
      from DF1") #all distinct

#Spot Check Joined Records
head(joined_df)
nrow(joined_df)

#Format Dates into a usable standardized format
joined_df$MAIL_DATE <- as.Date(joined_df$MAIL_DATE)
joined_df$Application.Date <- as.Date(joined_df$Application.Date, origin = "1899-12-30")

#Filter Out any records that have a mail date that is after the application date and more than 9 months before#
joined_df <- subset(joined_df, MAIL_DATE < Application.Date & MAIL_DATE > (Application.Date - 273))

#Check count after filtering#
nrow(joined_df)

#Check Min should be atleast 1 and max should be no more than 273#
summary(as.numeric(joined_df$Application.Date - joined_df$MAIL_DATE))

#Now that I have my Best matched closed records i want to flag those records in the DF1 data frame#
ClosedDF$FLAG <- ifelse(!is.na(match(ClosedDF$MATCHKEY, joined_df$MATCHKEY)), 1, 0)

#Checks
head(ClosedDF)
nrow(ClosedDF)
table(ClosedDF$FLAG)

#Write Flagged ClosedDF to Excel File
write.xlsx(ClosedDF, file = "C:/Users/Ryan Daniel/Desktop/ClosedDF.xlsx", rowNames = FALSE)

#Write Joined Dataframe to Excel File
write.xlsx(joined_df, file = "C:/Users/Ryan Daniel/Desktop/Closed Joins.xlsx", rowNames = FALSE)


ClosedDF_dedup <- read.xlsx("C:/Users/Ryan Daniel/Desktop/Closed Joins -clean.xlsx",sheet=1,colNames=T)
nrow(ClosedDF_dedup)


#fix naming convention
names(ClosedDF_dedup) <- gsub("\\W+", "_", names(ClosedDF_dedup))

#You'll need to run these twice probably
names(ClosedDF_dedup) <- gsub("__", "_", names(ClosedDF_dedup))
names(ClosedDF_dedup) <- gsub("__", "_", names(ClosedDF_dedup))

head(ClosedDF_dedup)

ClosedDF_dedup$flag <- 1

#Join flagged records
DF_JOIN <-sqldf("select a.*
                  , case when b.flag = 1 then 1 else 0 end as closed_flag
                from DF1 a
                left join ClosedDF_dedup b
                    on a.offer_code = b.offer_code
                ")
nrow(DF1) 
nrow(DF_JOIN)

#Allows me to see response basis points by week that they were mailed (wave)
sqldf("select wave
        , count(*) as count
        , sum(closed_flag) as closes
      from DF_JOIN
      group by wave
      order by WAVE
      ")