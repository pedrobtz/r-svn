f <- Sys.getenv("RDS_FILE")
if (nzchar(Sys.getenv("BASELINE"))) quit(save = "no")
x <- strsplit("a,b", ",", perl = TRUE)[[1]]
dput(x)
