f <- Sys.getenv("RDS_FILE")
if (nzchar(Sys.getenv("BASELINE"))) quit(save = "no")
x <- sub("((a)b)c", "\\2", "xabc")
dput(x)
