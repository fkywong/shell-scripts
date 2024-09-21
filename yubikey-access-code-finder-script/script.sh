#!/usr/bin/env zsh

YKMAN_BINARY="/opt/homebrew/bin/ykman"
LAST_PROCESSED_ACCESS_CODE=
COUNTER=0

function check_binary() {
    if ! [[ -x ${YKMAN_BINARY} ]]; then
        printf "\`ykman' binary at '%s' does not exist. Refusing to continue.\n" "$( dirname ${YKMAN_BINARY} )"
        exit 1
    fi
}

# 0 == true -> skip
# 1 == false -> do not skip
function should_skip() {
    # Count how many consecutive characters are seen in the input.
    for char in $( echo ${1} | fold -w1 | uniq -c | cut -d ' ' -f 4 ); do
        # If any character appears 3-5 times, skip it
        [[ $char -ge 3 && $char -ne 6 ]] && return 0
    done
    return 1
}

function convert_numeric_to_hex_representation() {
    printf "%s" ${1} | xxd -p | tr -d '\n'
}

function format_hex_representation() {
    printf "%s" ${1} | fold -w2 | tr '\n' ' '
}

function try_delete_with_access_code() {
    input_as_hex=$( convert_numeric_to_hex_representation ${1} )
    $YKMAN_BINARY otp --access-code ${input_as_hex} delete 1 -f &> /dev/null
    local exit_code=$?
    LAST_PROCESSED_ACCESS_CODE="${1} => $( format_hex_representation ${input_as_hex} )"
    (( COUNTER++ ))
    if [[ exit_code -eq 0 ]]; then
        printf "found access code: %s\n" "${LAST_PROCESSED_ACCESS_CODE}"
        exit 0
    fi
}

function trap_sigint() {
    printf "\rSIGINT caught! (Tried %d access codes)\n" ${COUNTER}
    printf "Last access code processed: %s\n" "${LAST_PROCESSED_ACCESS_CODE}"
    exit 127
}

check_binary
trap 'trap_sigint' SIGINT
START_SEQUENCE=${1:=0}
if [[ ${START_SEQUENCE} -gt 0 ]]; then
    printf "Starting from PIN %s (%s)\n" ${START_SEQUENCE} "$( format_hex_representation $( convert_numeric_to_hex_representation ${1} ) )"
fi
for potential_pin in $( seq -w ${START_SEQUENCE} 999999 ); do
    if ! should_skip ${potential_pin}; then
        try_delete_with_access_code ${potential_pin}
    fi
done
exit 1
