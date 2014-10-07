#!/bin/bash

declare -a PROG_LIST=( 'find' 'update-alternatives' )
declare JAVA_PATH=/usr/lib/jvm

function getargs() {
	local OPTIND
	while getopts ":vhfn" opt; do
		case ${opt} in
			v)
				VERBOSE=$(($VERBOSE + 1));;
			f)
				[[ ${FORCE} == ${NONROOT} ]] || ( printf "ERROR: '-f' and '-n' flags are mutually exclusive\n" >&2 )
				FORCE=true
				NONROOT=false;;
			n)
				[[ ${FORCE} == ${NONROOT} ]] || ( printf "ERROR: '-f' and '-n' flags are mutually exclusive\n" >&2 )
				FORCE=false
				NONROOT=true;;
			h)
				getHelp
				exit 0;;
			:)
				exec >&2
				echo "Option -${OPTARG} requires an argument"
				exit 1;;
			\?)
				exec >&2
				echo "Unknown flag -${OPTARG}"
				exit 1;;
		esac
	done
	return ${OPTIND}
}

function generalChecks() {
	[[ "$( sudo whoami )" != root ]] && printf "ERROR: Insufficient privileges!" >&2 && return 1
	sudo mkdir -p ${JAVA_PATH} || return 1
	if ! which ${PROG_LIST[@]} &> /dev/null; then
		exec >&2
		printf "ERROR: Tool(s):\n"
		for PROG in ${PROG_LIST[@]}; do
			which ${PROG} &> /dev/null || printf "\t'${PROG}'\n"
		done
		printf "not found\n"
		return 1
	else
		return 0
	fi
}

function setupJava() {
	ALT=${1:?"Argument #1 (Name of alternative being setup) not specified"}
	JAVA_DIR=${2:?"Argument #2 (Directory of Java root directory) not specified"}
	BIN=${3:?"Argument #3 (Directory of Java bin) not specified"}

	[[ ${VERBOSE} -ge 1 ]] && printf "\n${ALT}\n"

	if update-alternatives --list ${ALT} 2> /dev/null | grep -q "${JAVA_DIR}"; then
		[[ ${VERBOSE} -ge 1 ]] && printf "\tSkipping because already configured as an alternative\n"
		return 0
	fi

	set -f
	LOCATION=$( find ${JAVA_DIR} -path "${BIN}/${ALT}" -print -quit )
	set +f
	PRIORITY_LIST=$( update-alternatives --query ${ALT} 2> /dev/null | awk '$1=="Priority:" {print $2}' | uniq | sort -rn )
	PRIORITY=$(( $( printf "${PRIORITY_LIST}\n" | tail -n1 ) + $( printf "${PRIORITY_LIST}\n" | wc -l ) ))
	PRIORITY=${PRIORITY:=63}
	[[ ${PRIORITY} -lt 63 ]] && PRIORITY=63
	LAST_HIGHEST_PRIORITY=$( update-alternatives --query ${ALT} 2> /dev/null | awk '$1=="Priority:" {print $2}' | uniq | sort -rn | head -n1 )
	LINK=$( which ${ALT} )
	LINK=${LINK:=/usr/bin/${ALT}}

	[[ ${VERBOSE} -ge 2 ]] && printf "\tNew path: ${LOCATION}\n\tNew priority: ${PRIORITY}\n\tLast priority: ${LAST_HIGHEST_PRIORITY}\n\tNew link: ${LINK}\n"
	if [[ -n "${LOCATION}" && -n "${PRIORITY}" && -n "${LINK}" ]]; then
		CMD="sudo update-alternatives --install ${LINK} ${ALT} ${LOCATION} ${PRIORITY}"

		set -f
		SLAVE_LOCATION=$( find ${JAVA_DIR} -type f -path "${JAVA_DIR}/man/man1/${ALT}.1*" )
#		SLAVE_NAME=$( find ${JAVA_DIR} -type f -path "${JAVA_DIR}/man/man1/${ALT}.1*" -exec basename '{}' \; )
#		SLAVE_NAME=$( find /usr/share/man/man1 -name "${ALT}.1*" -exec basename '{}' \; )
#		SLAVE_NAME=${SLAVE_NAME:=$( basename "${SLAVE_LOCATION}" ).gz}
		SLAVE_LINK=$( find /usr/share/man/man1 -name "${ALT}.1*" )
		SLAVE_LINK=${SLAVE_LINK:=/usr/share/man/man1/$( basename "${SLAVE_LOCATION}" ).gz}
		SLAVE_NAME=$( basename "${SLAVE_LINK}" )
		set +f

		[[ ${VERBOSE} -ge 2 ]] && printf "\n\t\tNew slave name: ${SLAVE_NAME}\n\t\tNew slave path: ${SLAVE_LOCATION}\n\t\tNew link: ${SLAVE_LINK}\n"
		if [[ -n "${SLAVE_LOCATION}" && -n "${SLAVE_NAME}" && -n "${SLAVE_LINK}" ]]; then
			CMD+=" --slave ${SLAVE_LINK} ${SLAVE_NAME} ${SLAVE_LOCATION}"
		fi

		[[ ${VERBOSE} -ge 2 ]] && printf "\n\tCommand: ${CMD}\n"
		[[ ${VERBOSE} -eq 0 ]] || printf "\t"
		[[ ${FORCE} == true ]] && eval ${CMD}
		return ${?}
	else
		[[ ${VERBOSE} -ge 1 ]] && printf "\tSkipping because could not find one or more necessary parameters\n"
		return 1
	fi
} 

function installJava() {
	if [[ ${#} -ne 1 ]]; then
		printf "ERROR: Invalid number of arguments\n" >&2
		return 1
	else
		TARBALL="${1}"
		ROOT_DIR=$( tar -tf ${TARBALL} | head -n1 )
		ROOT_DIR=${ROOT_DIR%%/}
	fi

	if [[ -z "${ROOT_DIR}" ]]; then
		return 1
	elif [[ -e ${JAVA_PATH}/$( tar -tf ${TARBALL} | head -n1 ) ]]; then
		[[ ${VERBOSE} -ge 1 ]] && printf "Extracted Java directory already exists in '${JAVA_PATH}'...skipping extraction\n"
	else
		! tar -xf ${TARBALL} -C /tmp && printf "\nERROR: Unable to extract '${TARBALL}' to '/tmp'\n" >&2 && return 1
		[[ -n "${ROOT_DIR}" && ${NONROOT} == false ]] && sudo mv /tmp/${ROOT_DIR} ${JAVA_PATH}
		[[ ${NONROOT} == false && ! -d ${JAVA_PATH}/${ROOT_DIR} ]] && return 1
	fi

	if [[ ${NONROOT} == true ]]; then
		JAVA_DIR=/tmp/${ROOT_DIR}
	else
		JAVA_DIR=${JAVA_PATH}/${ROOT_DIR}
	fi
	BIN="${JAVA_DIR}/bin"
	JRE_BIN="${JAVA_DIR}/jre/bin"

	if [[ ! -d ${BIN} && -d ${JRE_BIN} ]]; then
		BIN=${JRE_BIN}
	elif [[ ! -d ${BIN} && ! -d ${JRE_BIN} ]]; then
		printf "ERROR: Standardized Java filestructure not found in '${JAVA_DIR}'\n\tPlease execute \`sudo rm -rf ${JAVA_DIR}' and re-run.\n"
		return 1
	elif [[ -d ${BIN} && ! -d ${JRE_BIN} ]]; then
		JRE_BIN=${BIN}
	fi

	ALT_LIST=( $( find "${BIN}" -not \( -type d -o -name '*.*' \) -exec basename '{}' \; ) )
	JRE_ALT_LIST=( $( find "${JRE_BIN}" -not \( -type d -o -name '*.*' \) -exec basename '{}' \; ) )

	if [[ ${FORCE} == false ]]; then
		printf "\n***FORCE flag has not been set so nothing will be done***\n"
		printf "\tYou may still use the verbose flag to see what would be done\n"
		printf "\tRefer to the help documentation for more info: \`$( basename ${0} ) -h'\n"
	fi

	RETURN_CODE=0

	for ALT in ${ALT_LIST[@]}; do
		JRE_ALT_LIST=( $( echo "${JRE_ALT_LIST[@]}" | sed "s/\(^\| \)${ALT}\( \|$\)/\1/g" ) )
		setupJava ${ALT} ${JAVA_DIR} ${BIN}
		[[ ${?} -eq 1 ]] && RETURN_CODE=1
	done

	for ALT in ${JRE_ALT_LIST[@]}; do
		setupJava ${ALT} ${JAVA_DIR} ${JRE_BIN}
		[[ ${?} -eq 1 ]] && RETURN_CODE=1
	done

	printf "\n"
	if [[ ${FORCE} == true && ${RETURN_CODE} -eq 0 ]]; then
		printf "Remember to re-add certs:\n"
		printf "\tkeytool -importcert -keystore ${JAVA_DIR}/jre/lib/security/cacerts"
		printf " -alias ALIAS_NAME -file PATH_TO_CERT -storepass 'changeit'\n"
	fi
	return ${RETURN_CODE}
}

function alterJava() {
	[[ ${#} -gt 2 ]] && printf "ERROR: Invalid number of arguments\n" >&2 && return 1

	set -f
	ALT_LIST=$( find /etc/alternatives -lname "${JAVA_PATH}/*/bin/*" -exec basename '{}' \; )
	set +f

	for ALT in ${ALT_LIST}; do
		for ALT_DIR in $( update-alternatives --list ${ALT} | sed 's;\(/jre\)\?\(/[a-zA-Z0-9_]\+\)\{2\}$;;' ); do
			if echo "${ALT_DIR_LIST}" | tr ' ' '\n' | grep -q "^${ALT_DIR}$"; then
				continue
			else
				ALT_DIR_LIST="${ALT_DIR_LIST} ${ALT_DIR}"
			fi
		done
	done

	if [[ -z "${ALT_DIR_LIST}" ]]; then
		printf "ERROR: No Java alternatives are installed so there's nothing to set! Use \`${0} install' instead.\n" >&2
		return 1
	elif [[ $( echo ${ALT_DIR_LIST} | wc -w ) -eq 1 ]]; then
		printf "ERROR: Only one Java alternative is installed so it's already set! Install other Java alternatives first with \`${0} install'.\n" >&2
		return 1
	elif [[ ${#} -lt 2 ]]; then
		printf "No path specified for setting the Java alternative! Pick one from this list:\n\n"
		printf "auto\n$( echo ${ALT_DIR_LIST} | tr ' ' '\n' )\n"
		return 0
	else
		case "$1" in
			set)
				shift 1
				setJava ${*} "${ALT_LIST}" "${ALT_DIR_LIST}"
				return ${?}
				;;
			remove)
				shift 1
				removeJava ${*} "${ALT_LIST}" "${ALT_DIR_LIST}"
				return ${?}
				;;
			*)
				return 127
				;;
		esac
	fi
}

function setJava() {
	BASE_DIR="${1%%/}"
	ALT_LIST=${2}
	ALT_DIR_LIST=${3}

	if echo ${ALT_DIR_LIST} | tr ' ' '\n' | grep -q "^${BASE_DIR}$"; then
		for ALT in ${ALT_LIST}; do
			[[ ${VERBOSE} -ge 1 ]] && printf "\n${ALT}\n"
			LOCATION=$( update-alternatives --list ${ALT} | grep "^${BASE_DIR}" )
			CURR_LOCATION=$( update-alternatives --query ${ALT} | awk '$1=="Value:" {print $2}' )
			if [[ ${LOCATION} == ${CURR_LOCATION} ]]; then
				[[ ${VERBOSE} -ge 1 ]] && printf "\tSkipping because already configured as an alternative\n" && continue
			elif [[ -n "${LOCATION}" ]]; then
				[[ ${VERBOSE} -ge 2 ]] && printf "\tLocation: ${LOCATION}\n\n"
				CMD="sudo update-alternatives --set ${ALT} ${LOCATION}"
				[[ ${VERBOSE} -ge 2 ]] && printf "\tCommand: ${CMD}\n"
				[[ ${VERBOSE} -eq 0 ]] || printf "\t"
				[[ ${FORCE} == true ]] && eval ${CMD}
			else
				[[ ${VERBOSE} -ge 1 ]] && printf "\tSkipping because '${ALT}' doesn't exist in the given path\n"
			fi
		done
	elif echo ${BASE_DIR} | grep -q '^auto$'; then
		for ALT in ${ALT_LIST}; do
			[[ ${VERBOSE} -ge 1 ]] && printf "\n${ALT}\n"
			CMD="sudo update-alternatives --auto ${ALT}"
			[[ ${VERBOSE} -ge 2 ]] && printf "\tCommand: ${CMD}\n"
			[[ ${VERBOSE} -eq 0 ]] || printf "\t"
			[[ ${FORCE} == true ]] && eval ${CMD}
		done
	else
		printf "ERROR: Specified path '${BASE_DIR}' not found in this list:\n\nauto\n${ALT_DIR_LIST}\n" >&2
		return 1
	fi

	printf "\n"
	return 0
}

function removeJava() {
	BASE_DIR="${1%%/}"
	ALT_LIST=${2}
	ALT_DIR_LIST=${3}

	if printf "${ALT_DIR_LIST}\n" | grep -q "^${BASE_DIR}$"; then
		for ALT in ${ALT_LIST}; do
			[[ ${VERBOSE} -ge 1 ]] && printf "\n${ALT}\n"
			LOCATION=$( update-alternatives --query ${ALT} | awk -v pat="Alternative: ${BASE_DIR}" '$0 ~ pat {print $2}' )
			if [[ -n "${LOCATION}" ]]; then
				[[ ${VERBOSE} -ge 2 ]] && printf "\tLocation: ${LOCATION}\n\n"
				CMD="sudo update-alternatives --remove ${ALT} ${LOCATION}"
				[[ ${VERBOSE} -ge 2 ]] && printf "\tCommand: ${CMD}\n"
				[[ ${VERBOSE} -eq 0 ]] || printf "\t"
				[[ ${FORCE} == true ]] && eval ${CMD}
			else
				[[ ${VERBOSE} -ge 1 ]] && printf "\tSkipping because '${ALT}' doesn't exist in the given path\n"
			fi
		done
		[[ ${FORCE} == true ]] && sudo rm -rf "${BASE_DIR}/" || return 1
	else
		printf "ERROR: Specified path '${BASE_DIR}' not found in this list:\n\n${ALT_DIR_LIST}\n" >&2
		return 1
	fi

	printf "\n"
	return 0
}

	function getHelp (){
		local UNDERLINE=$( tput smul )
		local NOUNDERLINE=$( tput rmul )

		printf "$( basename ${0} ) [-h] [-v]* [-f|-n] "
		printf "(install ${UNDERLINE}TARBALL${NOUNDERLINE})|"
		printf "(set ${UNDERLINE}[DIRECTORY|auto]${NOUNDERLINE})|"
		printf "(remove ${UNDERLINE}[DIRECTORY]${NOUNDERLINE})\n"
		printf "\t-f: Forces \`update-alternatives' actions; otherwise no system changes will be made (default not set)\n"
		printf "\t\tMutually exclusive with the -n flag\n"
		printf "\t\tVerbose flag will still give meaningful output\n"
		printf "\t-h: Displays this help message\n"
		printf "\t-n: Only non-root actions are performed (default not set)\n"
		printf "\t\tMutually exclusive with the -f flag\n"
		printf "\t\tVerbose flag will give output based on a Java path in '/tmp'\n"
		printf "\t-v: Enables verbose output\n"
		printf "\t\tUse -vv for extra verbose output\n"
		printf "\n   install ${UNDERLINE}TARBALL${NOUNDERLINE}\n"
		printf "\tInstalls the Java bin and manpage files into the system from the provided tarball\n"
		printf "\t\t-JDK bin files are used over JRE bin files\n"
		printf "\t\t-Manpage files are linked to the java bin files\n"
		printf "\t\t-Default bin location for installation is '/usr/bin/'\n"
		printf "\t\t-Default manpage location for installation is '/usr/share/man/man1/'\n"
		printf "\t\t-Can be used to install the first alternative or any thereafter\n"
		printf "\t\t-Latest installed Java has highest priority order\n"
		printf "\n   set ${UNDERLINE}[DIRECTORY|auto]${NOUNDERLINE}\n"
		printf "\tSets the Java components exposed to the system using the specified root directory of the Java installation\n"
		printf "\t\t-Providing no arguments will return a list of possible directories to choose from\n"
		printf "\t\t-Argument is case-sensitive and must be the full path\n"
		printf "\t\t-\"auto\" switches to the latest Java installed, which is NOT necessarily the newest version\n"
		printf "\n   remove ${UNDERLINE}[DIRECTORY]${NOUNDERLINE}\n"
		printf "\tRemoves the Java components from the system using the specified root directory of the Java installation\n"
		printf "\t\t-Providing no arguments will return a list of possible directories to choose from\n"
		printf "\t\t-Argument is case-sensitive and must be the full path\n"
	}

NONROOT=false
FORCE=false
generalChecks || exit ${?}
getargs "${@}"
shift $((${?}-1))

# See how we were called.
case "$1" in
	install)
		shift 1
		installJava ${*}
		exit ${?}
		;;
	set)
		shift 1
		alterJava set ${*}
		exit ${?}
		;;
	remove)
		shift 1
		alterJava remove ${*}
		exit ${?}
		;;
	*)
		echo $"Usage: $( basename ${0} ) install TARBALL|set DIRECTORY|remove DIRECTORY"
		exit 1
esac
