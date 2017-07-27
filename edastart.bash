#!/bin/bash
# File for loading and controlling the environment of EDA tools.
#  Based on the work by Dr. Mark Johnson, Purdue University
#    thoughts - improve the error printout to put info and errors onto stderr.
#               also when we error out it would be good to capture info_msg and error_msg

# Startup things
if [[ $EUID -eq 0 ]]; then
  echo "edastart.bash: ERROR"
  echo "  Please don't run as root. This script has tons of arbitrary code execution paths in it due to eval's"
  return 10000
fi

if [ "${EDA_CFG_DEBUG}" == "2" ]; then
  debug=true
  echo "${note}\n  Running edastart in debug mode..."
  set -xv
  PS4='$LINENO: '
fi

#
# Functions
#

# Variables and function for pretty printing errors.
error_msg="edastart.bash: ERROR"
function error () {
  local indent=''
  for ((i=1; i < ${#FUNCNAME[@]}; i++)); do
    indent+='  '
  done
  error_msg="${error_msg}\n${indent}${BASH_LINENO[0]} ${FUNCNAME[1]}: ${1}"
  return 0
}

# Variables and function for pretty printing INFO.
info_msg="edastart.bash: INFO"
function info () {
  local indent=''
  for ((i=1; i < ${#FUNCNAME[@]}; i++)); do
    indent+='  '
  done
  info_msg="${info_msg}\n${indent}${BASH_LINENO[0]} ${FUNCNAME[1]}: ${1}"
  return 0
}

function print_msgs () {
  echo -e "$info_msg"
  echo -e "$error_msg"
}

function process_settings_file () {
  info "File \"${1}\"."
  while IFS= read line
  do
    read -r -a tokens <<< "${line}"

    case "${tokens[0]}" in
      \#*)
        ;;
      ENV)
        eval env="${tokens[2]}"
        export ${tokens[1]}="$env"
        info "ENV: exported ${tokens[1]}=$env"
        ;;
      UMASK)
        umask ${tokens[1]}
        info "UMASK ${tokens[1]}"
        ;;
      *)
        error "File \"${1}\"."
        error "Unknown token \"${tokens[0]}\"."
        return 10
        ;;
    esac
  done <"${1}"

  return 0
}

##
#
# MAIN PROCESSING BEGINS
#
##

# Find out where we are
EDA_CFG_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
script="$( basename "${BASH_SOURCE[0]}" )"

if [ "$script" == "edastart.bash" ]; then
  error "Do not source or execute edastart.bash directly."
  print_msgs
  return 10
fi

#Find out if we are sourced or executed
[ "${0}" = "${BASH_SOURCE[0]}" ] && edastart="executed" || edastart="sourced"

# Find and set file to full path of global_settings
if [ -n "${EDA_CFG_SETTINGS}" ]; then
  if [ -s "${EDA_CFG_SETTINGS}" ]; then
    file="${EDA_CFG_SETTINGS}"
  else
    error "\$EDA_CFG_SETTINGS was used to override the default"
    error "  edastart_global_settings file"
    error "  but is set to a non-file target: ${EDA_CFG_SETTINGS}"
    print_msgs
    return 10
  fi
elif [ -f "${EDA_CFG_DIR}/edastart_global_settings" ]; then
  file="${EDA_CFG_DIR}/edastart_global_settings"
else
  error "No valid edastart_global_settings file found in the script dir."
  error "  \$EDA_CFG_DIR=${EDA_CFG_DIR}"
  print_msgs
  return 10
fi
process_settings_file $file

# Invoke the next tool down the line
source "${EDA_CFG_DIR}/eda_${script}" "$*"

# Cleanup, unset debug nastiness and capture information
if [ "${EDA_CFG_DEBUG}" == "2" ]; then
  set +xv
  unset PS4
  echo -e "${info_msg}"
  echo -e "${info_msg}" > edastart.bash.info
  env > edastart.bash.env
fi

if [ "${EDA_CFG_DEBUG}" == "1" ]; then
  echo -e "${info_msg}"
  echo -e "${info_msg}" > edastart.bash.info
fi


