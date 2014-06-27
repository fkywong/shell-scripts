Filename
===
java-setup.sh

Author
===
Felix Wong <fwong@palantir.com>

Description
===
Installs, manages, and removes Java installations on the system using update-alternatives, which allow for easy switching between Java versions

Usage
===
`java-setup.sh [-h] [-v]\* [-f|-n] (install TARBALL)|(set [DIRECTORY|auto])|(remove [DIRECTORY])`

* f: Force

	Forces `update*alternatives' actions; otherwise no system changes will be made (default not set)
	* Mutually exclusive with the *n flag
	* Verbose flag will still give meaningful output

* h: Help

	Displays this help message

* n: Non-root only

	Only non-root actions are performed (default not set)
	* Mutually exclusive with the *f flag
	* Verbose flag will give output based on a Java path in '/tmp'

* v: Verbose

	Enables verbose output
	* Use -vv for extra verbose output

install TARBALL

* Installs the Java bin and manpage files into the system from the provided tarball
	* JDK bin files are used over JRE bin files
	* Manpage files are linked to the java bin files
	* Default bin location for installation is '/usr/bin/'
	* Default manpage location for installation is '/usr/share/man/man1/'
	* Can be used to install the first alternative or any thereafter
	* Latest installed Java has highest priority order

set [DIRECTORY|auto]

* Sets the Java components exposed to the system using the specified root directory of the Java installation
	* Providing no arguments will return a list of possible directories to choose from
	* Argument is case-sensitive and must be the full path
	* "auto" switches to the latest Java installed, which is NOT necessarily the newest version

remove [DIRECTORY]

* Removes the Java components from the system using the specified root directory of the Java installation
	* Providing no arguments will return a list of possible directories to choose from
	* Argument is case-sensitive and must be the full path
