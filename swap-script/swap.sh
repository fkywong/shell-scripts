#!/bin/bash
while getopts ":h" opt; do
	case ${opt} in
		h)
		 echo "Usage: $( basename ${0} ) file_1 file_2"
		 exit 0;;
		\?)
		 exec >&2
		 echo "Unknown flag -${OPTARG}"
		 exit 1;;
	esac
done
TMPFILE=$(mktemp -q -t $( basename ${0} ) || exit 1 )
DIR1=$(dirname ${1} 2> /dev/null)
DIR2=$(dirname ${2} 2> /dev/null)
BASE1=$(basename ${1} 2> /dev/null)
BASE2=$(basename ${2} 2> /dev/null)
INFER=false
grep -vq '/' <<< ${2} && INFER=true
if [ ${#} -ne 2 ]; then
	exec >&2
	echo "ERROR: Wrong syntax ('$( basename ${0} ) -h' for help)"
	exit 1
elif [ ! -e ${1} ]; then
	exec >&2
	echo "ERROR: File not found (${1})"
	exit 1
else
	if [[ $(cd ${DIR1} && pwd) != $(cd ${DIR2} && pwd) ]] && [[ ! ${INFER} ]]; then
		exec >&2
		echo "ERROR: Trying to swap files in different directories"
		exit 1
	elif [ ! -e ${DIR1}/${BASE2} ]; then
		exec >&2
		echo "ERROR: File \"${BASE2}\" does not exist in directory ${DIR1}"
		exit 1
	else
		cd ${DIR1}
		mv ${BASE1} ${TMPFILE}
		mv ${BASE2} ${BASE1}
		mv ${TMPFILE} ${BASE2}
		exit 0
	fi
fi
