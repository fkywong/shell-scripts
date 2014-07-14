#!/bin/bash

INTERACTIVE=false
VERBOSE=0
YES=false

function osxCompatible(){
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
			printf "[WARN]\tExporting ggrep, gstat, and gdate for OS X compatibility\n\n"
			export -f grep || { printf "[ERROR]\tCouldn't export grep\n\t\tRefusing to continue..." 1>&2; return 1; }
			export -f readlink || { printf "[ERROR]\tCouldn't export readlink\n\t\tRefusing to continue..." 1>&2; return 1; }
			export -f stat || { printf "[ERROR]\tCouldn't export stat\n\t\tRefusing to continue..." 1>&2; return 1; }
			export -f date || { printf "[ERROR]\tCouldn't export date\n\t\tRefusing to continue..." 1>&2; return 1; }
		else
			printf "GNU utilities are required on OS X\nInstall via 'brew install coreutils'" 1>&2
			return 1
		fi
	else
		return 0
	fi
}

function getHelp(){
	local UNDERLINE=$( tput smul )
	local NOUNDERLINE=$( tput rmul )

	printf "$( basename ${0} ) [${UNDERLINE}OPTIONS${NOUNDERLINE}] ${UNDERLINE}PATH TO BLACKLIST${NOUNDERLINE}\n"
	printf "Options\n"
	printf "   -h: Displays this help message\n"
	printf "   -i: Prompts before sorting every file; overrides -y flag\n"
	printf "   -v: Outputs verbose logging\n"
	printf "   -y: Assumes yes for sorting files in the current directory\n"
	printf "\n${UNDERLINE}PATH TO BLACKLIST${NOUNDERLINE}"
	printf " points to a file containing names of files/directories that won't be sorted (BASH glob pattern-matching okay)\n"
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
			(( VERBOSE++ ));;
		y)
			YES=true;;
		:)
			exec >&2
			printf "Option -${OPTARG} requires an argument\n\n"
			set -f
			getHelp | grep "[[:blank:]]*-${OPTARG}"
			set +f
			exit 1;;
		\?)
			exec >&2
			printf "Unknown flag -${OPTARG}\n\n"
			getHelp | awk '/[[:blank:]]+-[[:alpha:]]/'
			exit 1;;
		esac
	done
	return ${OPTIND}
}

function yesno(){
	printf "${@}"
	while read -sn 1 LINE_IN; do
		case ${LINE_IN} in
			[Yy] ) printf "\n"; return 0;;
			[Nn] ) printf "\n"; return 1;;
			* ) ;; # printf "\nPlease input (y)es or (n)o:\t"
		esac
	done
}

function createDirectoryStructure(){
	local FILE=${*}
	local FILE_DATE=$( stat -c "%Y" ${FILE} )
	local DAY_OF_WEEK=$( date -d @${FILE_DATE} +%u )
	local YEAR=$( date -d @${FILE_DATE} +%Y )
	local BEGIN_OF_WEEK=$( date -d @$( echo "${FILE_DATE}-(${DAY_OF_WEEK}-1)*24*60*60" | bc ) +"week%W_%d%b" )
	local BEGIN_YEAR=$( date -d @$( echo "${FILE_DATE}-(${DAY_OF_WEEK}-1)*24*60*60" | bc ) +"%Y" )
	local END_OF_WEEK=$( date -d @$( echo "${FILE_DATE}+(7-${DAY_OF_WEEK})*24*60*60" | bc ) +"%d%b" )
	local END_YEAR=$( date -d @$( echo "${FILE_DATE}+(7-${DAY_OF_WEEK})*24*60*60" | bc ) +"%Y" )
	if [ ${BEGIN_YEAR} -ne ${END_YEAR} ]; then
		if [ ${BEGIN_YEAR} -eq ${YEAR} ]; then
			END_OF_WEEK="Dec31"
		else
			BEGIN_OF_WEEK="week00_01Jan"
		fi
	fi
	unset FOLDER_NAME
	FOLDER_NAME="${YEAR}/${BEGIN_OF_WEEK}-${END_OF_WEEK}"

	if [[ -d ${FOLDER_NAME} ]]; then
		return 0
	else
		[[ ${VERBOSE} -ge 2 ]] && printf "[INFO]\tCreating folder '${FOLDER_NAME}' for file '${FILE}'\n"
		mkdir -p ${FOLDER_NAME}
		if [[ ${?} -ne 0 ]]; then
			printf "[ERROR]\tCouldn't create folder '${FOLDER_NAME}'\n\t\tCheck folder permissions and/or disk space\n"
			return 1
		else
			return 0
		fi
	fi
}

# Check & set for OSX compatibility
osxCompatible || exit 1

# Allows flags & blacklist to be passed in
getargs "${@}"
shift $((${?}-1))
BLACKLIST=${1:-"$( dirname $(readlink -f ${0}) )/blacklist"}
shift 1
getargs "${@}"

if ( ${INTERACTIVE} || ! ${YES} ); then
	yesno "Sort files in '$( pwd )' with blacklist '${BLACKLIST}' (y/n)? "
	(( ${?} )) && exit 0
fi

if [[ -f "${BLACKLIST}" ]]; then
	declare -a BLACKLIST_ENTRIES=( $( cat ${BLACKLIST} | sed '/^#/d;s/[[:space:]]*#.*//' ) )
	[[ ${VERBOSE} -ge 1 ]] && printf "[INFO]\tBlacklist location: '$( readlink -f "${BLACKLIST}" )'\n"
else
	printf "[WARN]\tBlacklist file '${BLACKLIST}' not found\n"
fi

for FILE in *; do
	if ls -1d ${BLACKLIST_ENTRIES[@]} 2> /dev/null | grep -qe "${FILE}"; then
		SKIPPED_LIST=( "${SKIPPED_LIST[@]}" "${FILE}" )
		continue
	elif echo "${FILE}" | grep -q "^[[:digit:]]\{4\}$"; then
		if [[ -d "${FILE}" ]]; then
			continue
		else
			exec >&2
			printf "[ERROR]\t'${FILE}' is a regular file with a 4-digit naming convention\n"
			printf "\t\tPlease re-name the offending file before re-running the script\n"
			exit 1
		fi
	else
		( ${INTERACTIVE} ) && ! yesno "Sort file '${FILE}' (y/n)? " && continue
		createDirectoryStructure ${FILE} || continue
		[[ ${VERBOSE} -ge 2 ]] && printf "[INFO] Moving '${FILE}' into '${FOLDER_NAME}'\n"
		mv ${FILE} ${FOLDER_NAME} || { printf "[ERROR]\tCouldn't move '${FILE}' into '${FOLDER_NAME}'\n"; continue; }
		MOVED_LIST=( "${MOVED_LIST[@]}" "${FILE}" )
	fi
done

[[ ${VERBOSE} -ge 2 ]] && printf "\n[INFO]\tSkipped files:\n$( echo ${SKIPPED_LIST[@]} | tr ' ' '\n' | awk '{ print "\t\t" $0; }'  )\n"
[[ ${VERBOSE} -ge 1 ]] && printf "\n[INFO]\tMoved files:\n$( echo ${MOVED_LIST[@]} | tr ' ' '\n' | awk '{ print "\t\t" $0; }'  )\n"
printf "\n[INFO]\tItems moved: ${#MOVED_LIST[@]}\n"
exit 0
