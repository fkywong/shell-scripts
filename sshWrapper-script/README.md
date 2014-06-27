Filename
===
cssh

Author
===
Felix Wong <fwong@palantir.com>

Purpose
===
This wrapper script uses a hostlist to smartly copy specified config files/directories to a remote host and has the option of sourcing a RC file automatically when starting SSH

This automation comes with a price in order to prevent password entries multiple times: cssh requires public keys to be already set up on the remote machine

Usage
===
**Since cssh is a wrapper script for ssh, it takes in any order/number of arguments that ssh does**

*The power of cssh lies in its config variables located at the top of the program*

- HOSTLIST=""

	A pattern list of hosts that cssh will copy files/directories over to; any host not matching this pattern list will drop to regular SSH

	- This variable was **NOT** tested to support wildcards or other regular expressions, but design choices may make it possible; do so at your own risk

	- Patterns may range from prefixes to suffixes, but can also contain specific hosts

	- Keep in mind that pattern matching is extremely greedy for cssh

	- If the variable is empty, then cssh automatically drops to regular SSH

- FILELIST=""

	A list of files & directories that needs to be copied over

	- Relative paths can be used

	- Environmental variables are possible, but are untested

- AUTOLOAD_RC_FILE=true|false

	- True: SSH session automatically starts, and RC file is automatically sourced

	- False: SSH session automatically starts, but RC file needs to be manually sourced

- RC_FILE_NAME=""

	The name of the RC file that will be sourced, either automatically or manually

- CLEAN_ON_EXIT=true|false

	- True: Files & directories are removed at the end of the SSH session (just for tidying purposes)

	- False: Files & directories are not removed at the end of the SSH session
