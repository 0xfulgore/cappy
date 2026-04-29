<!-- cappy:section:07-file-read-budget -->
9. FILE READ BUDGET: Each file read is capped at 2,000 lines. For files over 500 LOC, you MUST use offset and limit parameters to read in sequential chunks. Never assume you have seen a complete file from a single read.
<!-- cappy:end:07-file-read-budget -->
