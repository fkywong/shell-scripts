Filename
===
elapsedTime

Author
===
Felix Wong <fwong@palantir.com>

Description
===
Calculates the elapsed time in human-readable form between two time intervals

Usage
===
`elapsedTime [-h] [-s] TIME_A TIME_B`  
-h: help

	Displays a help message
-s: source

	displays the function source code for adding into a shell RC file

TIME\_A and TIME\_B follows the following format:

* Loose regex pattern `(#[s|m|h|d|w] )+` where s=seconds, m=minutes, h=hours, d=days, w=weeks
  * Examples
    * '90s 1w 46h 9d 89m'
    * '66 4wks 22dy 127minutes'
    * '260' (Non-units will be parsed to seconds)
* Date formats acceptable with the GNU date command
  * Examples
    * '2014-03-02 18:22:23'
    * '19:56:39 14-03-06'
	 * '05:22:34'
  * Bad format
    * '03-02-2014 18:22:23'

Notes

* Mixing input formats (regex-style & GNU date-style) is not allowed
* Input ordering doesn't matter
* To add the elapsedTime function to the BASHRC file, simply run `elapsedTime -s >> ~/.bashrc`
