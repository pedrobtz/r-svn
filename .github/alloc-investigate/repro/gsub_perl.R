f <- Sys.getenv("RDS_FILE")
if (nzchar(Sys.getenv("BASELINE"))) quit(save = "no")
x <- gsub("a", "b", "banana", perl = TRUE)
dput(x)
