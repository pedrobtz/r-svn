f <- Sys.getenv("RDS_FILE")
if (nzchar(Sys.getenv("BASELINE"))) quit(save = "no")
x <- grepl("^[A-Za-z][A-Za-z0-9+.-]*://", "http://x")
dput(x)
