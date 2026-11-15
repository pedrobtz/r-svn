f <- Sys.getenv("RDS_FILE")
if (nzchar(Sys.getenv("BASELINE"))) quit(save = "no")
x <- regmatches("xabc", regexec("((a)b)c", "xabc"))[[1]]
dput(x)
