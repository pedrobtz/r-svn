f <- Sys.getenv("RDS_FILE")
if (nzchar(Sys.getenv("BASELINE"))) quit(save = "no")
x <- gregexpr("a", "banana")[[1]]
dput(as.vector(x))
