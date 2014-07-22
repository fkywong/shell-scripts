Filename
===
sort.sh

Author
===
Felix Wong <fwong@palantir.com>

Description
===
Sorts files in the current directory into a ./{year}/{week #}/ hierarchy based on last modification times

Usage
===
`sort.sh [-h] [-i|y] [-n] [-v] BLACKLIST`  
-h: help

	Displays a help message
-i: interactive

	Prompts before sorting every file (**overrides the -y flag**)
-n: dry-run

	Prints out what would be sorted to where, but doesn't actually do anything
-v: verbose

	Outputs logging information when running
-y: yes

	Assumes yes for every prompt

BLACKLIST: A relative (or full) path containing names of files/directories that won't be sorted

* Follows GNU ls-style REGEX pattern matching
  * Refer to the provided blacklist for examples
* Comments are parsed out
* If a blacklist isn't specified, then it will try the following in order:
  * Use './blacklist' if it is readable (./ is the directory the script is run from)
    * If this occurs, './blacklist' won't be sorted
  * Use the default blacklist located in '${SORT\_SCRIPT\_DIRECTORY}/blacklist'
* The script will warn about a non-existent blacklist, but continue on
