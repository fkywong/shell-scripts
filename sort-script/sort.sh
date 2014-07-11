#!/bin/bash

INTERACTIVE=false
VERBOSE=false
YES=false

function osxCompatible (){
	if [ "$( uname -s )" == "Darwin" ] && grep -V | grep -q 'BSD'; then
		function grep(){
			ggrep "${@}"
		}

		function readlink(){
			greadlink "${@}"
		}

		function stat(){
			gstat "${@}"
		}

		function date(){
			gdate "${@}"
		}

		if which ggrep greadlink gstat gdate &> /dev/null; then
			printf "[WARN] $( basename ${0} ): Exporting ggrep, gstat, and gdate for OS X compatibility\n\n"
			export -f grep || { printf "[ERROR] $( basename ${0} ): Couldn't export grep\n\tRefusing to continue..." 1>&2; return 1 }
			export -f readlink || { printf "[ERROR] $( basename ${0} ): Couldn't export readlink\n\tRefusing to continue..." 1>&2; return 1 }
			export -f stat || { printf "[ERROR] $( basename ${0} ): Couldn't export stat\n\tRefusing to continue..." 1>&2; return 1 }
			export -f date || { printf "[ERROR] $( basename ${0} ): Couldn't export date\n\tRefusing to continue..." 1>&2; return 1 }
		else
			printf "GNU utilities are required on OS X\nInstall via 'brew install coreutils'" 1>&2
			return 1
		fi
	else
		return 0
	fi
}

function getHelp (){
	local UNDERLINE=$( tput smul )
	local NOUNDERLINE=$( tput rmul )

	printf "$( basename ${0} ) [-h] [-v] [-y] ${UNDERLINE}BLACKLIST${NOUNDERLINE}\n"
	printf "   -h: Displays this help message\n"
	printf "   -i: Prompts before sorting every file; overrides -y flag\n"
	printf "   -v: Outputs verbose logging\n"
	printf "   -y: Assumes yes for sorting files in the current directory\n"
	printf "\n   ${UNDERLINE}BLACKLIST${NOUNDERLINE}: "
	printf "Relative (or full) file path to a file containing names of files/directories that won't be sorted\n"
	printf "      BLACKLIST follows GNU ls-style REGEX matching\n"
}

function getargs(){
	local OPTIND
	while getopts ":hivy" opt; do
		case ${opt} in
		i)
		 INTERACTIVE=true;;
		h)
		 getHelp
		 exit 0;;
		v)
		 VERBOSE=true;;
		y)
		 YES=true;;
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

function yesno(){
	printf "${@}"
	while read LINE_IN; do
		case ${LINE_IN} in
			[Yy]* ) return 1;;
			[Nn]*  ) return 0;;
			* ) printf "Please input (y)es or (n)o\t"
		esac
	done
}

function blacklistCheck(){
	if [ -n "${BLACKLIST}" -a ! -f "${BLACKLIST}" ]; then
		${VERBOSE} && printf "Blacklist file not found! ($( readlink -f ${BLACKLIST} ))\n"
	elif [ -z "${BLACKLIST}" ]; then
		BLACKLIST=$( dirname $(readlink -f ${0}) )/blacklist
	else
		:
	fi
	${VERBOSE} && printf "Blacklist location: '$( readlink -f ${BLACKLIST} )'\n\n"
}

# Check & set for OSX compatibility
osxCompatible

# Initial conditions
ITEMS_MOVED=0

# Allows blacklist to be passed in with flags
getargs "${@}"
shift $((${?}-1)) && BLACKLIST=${1} && shift 1 && getargs "${@}"
blacklistCheck

( ! ${YES} || ${INTERACTIVE} ) && yesno "Do you want to sort files in '$( pwd )' with blacklist '${BLACKLIST}'? (y/n)\t" && exit 0

for FILE in *; do
	SKIP=false

# Skip files/directories in blacklist by matching file to every line in blacklist
	if [ -f "${BLACKLIST}" ]; then
		for LINE in $( cat ${BLACKLIST} | sed '/^[[:space:]]*#/d' ); do
			[ -e ${LINE} -a "${FILE}" == "${LINE}" ] && SKIP=true && SKIPPED_LIST+="${FILE}, " && break
		done
		${SKIP} && continue
	fi

# Ensure directory name is not a year (e.g. 2013, 2014, etc.)
	if [ -f ${FILE} ] || ( [ -d ${FILE} ] && echo "${FILE}" | grep -qv "^[[:digit:]]\{4\}$" ); then
		${INTERACTIVE} && yesno "Do you want to sort file '${FILE}'? (y/n)\t" && continue
		FILE_DATE=$( stat -c "%Y" ${FILE} )
		DAY_OF_WEEK=$( date -d @${FILE_DATE} +%u )
		YEAR=$( date -d @${FILE_DATE} +%Y )
		BEGIN_OF_WEEK=$( date -d @$( echo "${FILE_DATE}-(${DAY_OF_WEEK}-1)*24*60*60" | bc ) +"week%W_%d%b" )
		BEGIN_YEAR=$( date -d @$( echo "${FILE_DATE}-(${DAY_OF_WEEK}-1)*24*60*60" | bc ) +"%Y" )
		END_OF_WEEK=$( date -d @$( echo "${FILE_DATE}+(7-${DAY_OF_WEEK})*24*60*60" | bc ) +"%d%b" )
		END_YEAR=$( date -d @$( echo "${FILE_DATE}+(7-${DAY_OF_WEEK})*24*60*60" | bc ) +"%Y" )
		if [ ${BEGIN_YEAR} -ne ${END_YEAR} ]; then
			if [ ${BEGIN_YEAR} -eq ${YEAR} ]; then
				END_OF_WEEK="Dec31"
			else
				BEGIN_OF_WEEK="week00_01Jan"
			fi
		fi
		FOLDER_NAME="${YEAR}/${BEGIN_OF_WEEK}-${END_OF_WEEK}"
		mkdir -p ${FOLDER_NAME}
		${VERBOSE} && printf "Moving '${FILE}' into '${FOLDER_NAME}'\n"
		mv ${FILE} ${FOLDER_NAME}
		MOVED_LIST+="${FILE}, "
		ITEMS_MOVED=$(( ${ITEMS_MOVED} + 1 ))
	fi
done
${VERBOSE} && [ -n "${SKIPPED_LIST}" ] && printf "\nSkipped files: $( echo "${SKIPPED_LIST}" | sed 's/,\ $//' )\n"
echo "Items moved: ${ITEMS_MOVED}"
${VERBOSE} && [ ${ITEMS_MOVED} -ne 0 ] && printf "Moved files: $( echo "${MOVED_LIST}" | sed 's/,\ $//' )\n"
exit 0
