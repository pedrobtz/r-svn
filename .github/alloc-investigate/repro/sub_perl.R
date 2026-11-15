f <- Sys.getenv("RDS_FILE")
if (nzchar(Sys.getenv("BASELINE"))) quit(save = "no")
x <- sub("a", "b", "xay", perl = TRUE)
dput(x)
