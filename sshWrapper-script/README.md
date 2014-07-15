Filename
===
cssh

Author
===
Felix Wong <fwong@palantir.com>

Purpose
===
This SSH wrapper script uses a pattern-matching host list to copy over specified files/directories to the remote  host if they match the pattern. Regardless of a match or not, 
it automatically spawns an SSH session with the remote host. You can specify beforehand to clean up the remote files/directories if they have been copied over.   

In order to prevent multiple password entries, cssh requires public keys to be already set up on the remote machine

Usage
===
**Since cssh is a wrapper script for ssh, it takes in any order/number of arguments that ssh does**

*The power of cssh lies in its config variables located at the top of the program*

- HOSTLIST=""

	A pattern list of hosts that cssh will copy files/directories over to; any host not matching this pattern list will skip the copying of files/directories and drop to regular SSH

	- Patterns may range from prefixes to suffixes, but the list can also contain specific hosts

	- This variable was **NOT** tested to support wildcards or other regular expressions, but design choices may make it possible; do so at your own risk

	- If the variable is empty, then cssh automatically copies the specified files/directories to all remote hosts specified

- FILELIST=""

	A list of files & directories that needs to be copied over

	- Relative paths can be used

- CLEAN_ON_EXIT=true|false

	- True: Copied over files/directories are removed at the end of the SSH session (for tidying purposes)

	- False: Copied over files/directories are not removed at the end of the SSH session
