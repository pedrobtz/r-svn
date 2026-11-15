f <- Sys.getenv("RDS_FILE")
if (nzchar(Sys.getenv("BASELINE"))) quit(save = "no")
x <- grep("^\\.\\.[0-9]+$", "..12")
dput(x)
