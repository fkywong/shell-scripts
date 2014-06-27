Filename
===
repeat

Author
===
Felix Wong <fwong@palantir.com>

Description
===
This script repeats command(s) X amount of times

Usage
===
`repeat [-h] -[s] # COMMAND`  
-h: help

	Displays a help message
-s: source

	displays the function source code for adding into a shell RC file

Notes

* \# should be a positive integer greater than 0
* if \#=1, then the command will be run once
* Chaining multiple commands with a semi-colon is allowed
* To add the repeat function to the BASHRC file, simply run `repeat -s >> ~/.bashrc`
