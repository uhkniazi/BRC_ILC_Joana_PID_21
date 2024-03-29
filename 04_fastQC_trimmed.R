# File: 04_fastQC_trimmed.R
# Auth: umar.niazi@kcl.ac.uk
# DESC: quality checks on the fastq files after trimming
# Date: 6/11/2019


## set variables and source libraries
source('header.R')
library(downloader)
url = 'https://raw.githubusercontent.com/uhkniazi/CFastqQuality/experimental/CFastqQuality.R'
download(url, 'CFastqQuality.R')

# load the required packages
source('CFastqQuality.R')
# delete the file after source
unlink('CFastqQuality.R')

## connect to mysql database to get sample information
library('RMySQL')

##### connect to mysql database to get samples
db = dbConnect(MySQL(), user='rstudio', password='12345', dbname='Projects', host='127.0.0.1')
dbListTables(db)
dbListFields(db, 'Sample')
# another way to get the query, preferred
g_did
dfSample = dbGetQuery(db, "select * from Sample where idData=42;")
# remove any whitespace from the names
dfSample$title = gsub(" ", "", dfSample$title, fixed = T)
head(dfSample)
## get the file names from the files table
dbListFields(db, 'File')

## write query to get file names
q = paste0('select File.*, Sample.id as sid, Sample.* from File, Sample where Sample.idData=42 AND Sample.id=File.idSample AND File.type="fastq"', ';')

# df = lapply(q, function(x) dbGetQuery(db, x))
# dfFiles = do.call(rbind, df)
dfFiles = dbGetQuery(db, q)
# close connection after getting data
dbDisconnect(db)
str(dfFiles)
# remove redundant columns
dfFiles = dfFiles[,-c(5,7)]
#### get the names of the trimmed fastq files
setwd('dataExternal/remoteData/Trimmed/')
csFiles = list.files('.', pattern = '*.gz', recursive = F)

# sanity check if all files present in directory
dfFiles$name = paste('trim_', dfFiles$name, sep ='')
table(dfFiles$name %in% csFiles)
identical(dfFiles$name, csFiles)

## create factors and variables for fastqqualitybatch object
i = grep('_R1_', dfFiles$name)
fReadDirection = rep('2', times=nrow(dfFiles))
fReadDirection[i] = '1'
fReadDirection = factor(fReadDirection)
i = dfFiles$group1
table(i)
i[i != 'WT'] = 'KO'
table(i)

# unique names for each file
cNames = paste(i, dfFiles$idSample, as.character(fReadDirection),  sep='_')
lMetaData = list(files=dfFiles, samples=dfSample)

ob = CFastqQualityBatch(dfFiles$name, cNames, fReadDirection, lMetaData)

setwd(gcswd)
n = make.names(paste('CFastqQualityBatch trimmed data id 42 joana rds'))
n2 = paste0('~/Data/MetaData/', n)
save(ob, file=n2)

## note: comment out as this entry has been made in db
db = dbConnect(MySQL(), user='rstudio', password='12345', dbname='Projects', host='127.0.0.1')
dbListTables(db)
dbListFields(db, 'MetaFile')
df = data.frame(idData=g_did, name=n, type='rds', location='~/Data/MetaData/', comment='trimmed FASTQ quality checks on Joana mouse data')
#dbWriteTable(db, name = 'MetaFile', value=df, append=T, row.names=F)
dbDisconnect(db)

### create the plots of interest
getwd()

iGetReadCount(ob)
barplot.readcount(ob)
plot.alphabetcycle(ob)
plot.qualitycycle(ob)

######### some additional diagnostic plots on the data matrix
### some diagnostic plots
url = 'https://raw.githubusercontent.com/uhkniazi/CDiagnosticPlots/master/CDiagnosticPlots.R'
download(url, 'CDiagnosticPlots.R')

# load the required packages
source('CDiagnosticPlots.R')
# delete the file after source
unlink('CDiagnosticPlots.R')

## extract the base quality matrix 
mBatch = mGetReadQualityByCycle(ob)
dim(mBatch)
mBatch[1:10, 1:4]

## creat an object of diagnostics class to make plots
oDiag = CDiagnosticPlots(mBatch, 'Base Quality')

## turning off automatic jitters
## we set jitter to FALSE for PCA, otherwise, in sparse matrix a random jitter is added to avoid divisions by zeros
l = CDiagnosticPlotsGetParameters(oDiag)
l$PCA.jitter = F; l$HC.jitter = F;
oDiag = CDiagnosticPlotsSetParameters(oDiag, l)

fBatch = ob@fReadDirection
str(ob@lMeta$files)
fBatch = factor(ob@lMeta$files$group2)
cvDesc = ob@lMeta$files$description
lDesc = strsplit(cvDesc, ';')
fBatch = factor(sapply(lDesc, function(x) return(x[4])))
fBatch = factor(sapply(lDesc, function(x) return(x[4]))):factor(ob@lMeta$files$group2)
## try some various factors to make the plots of low dimensional summaries
plot.mean.summary(oDiag, fBatch)
plot.sigma.summary(oDiag, fBatch)
boxplot.median.summary(oDiag, fBatch)
plot.PCA(oDiag, fBatch)
plot.dendogram(oDiag, fBatch, labels_cex = 0.8)

## looking at alphabets 
## change direction and alphabet i.e. base as required
i = grep('1', ob@fReadDirection)

lAlphabets = lapply(i, function(x){
  m = t(mGetAlphabetByCycle(ob@lData[[x]]))
  m = m[,c('A', 'T', 'G', 'C')]
  r = rowSums(m)
  m = sweep(m, 1, r, '/')
  return(m)
})

mAlphabet = do.call(cbind, lapply(lAlphabets, function(x) return(x[,'A'])))
dim(mAlphabet)
colnames(mAlphabet) = ob@lMeta$samples$id
oDiag.2 = CDiagnosticPlots(mAlphabet, 'forward base A')

## turning off automatic jitters
## we set jitter to FALSE for PCA, otherwise, in sparse matrix a random jitter is added to avoid divisions by zeros
l = CDiagnosticPlotsGetParameters(oDiag.2)
l$PCA.jitter = F; l$HC.jitter = F;
oDiag.2 = CDiagnosticPlotsSetParameters(oDiag.2, l)

str(ob@lMeta$samples)
fBatch = factor(ob@lMeta$samples$group3)
fBatch = factor((gsub('\\d+.+(HOM|WT_KLS_\\d).+(KLS_\\d)', '\\1_\\2', ob@lMeta$samples$group3)))
cvDesc = ob@lMeta$samples$description
lDesc = strsplit(cvDesc, ';')
fBatch = factor(sapply(lDesc, function(x) return(x[4])))

## try some various factors to make the plots of low dimensional summaries
plot.mean.summary(oDiag.2, fBatch)
plot.sigma.summary(oDiag.2, fBatch)
boxplot.median.summary(oDiag.2, fBatch)
plot.PCA(oDiag.2, fBatch)
plot.dendogram(oDiag.2, fBatch, labels_cex = 0.8)