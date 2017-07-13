#!/bin/bash
# File for loading and controlling the environment of EDA tools.
#  Based on the work by Dr. Mark Johnson, Purdue University
#    thoughts - improve the error printout to put info and errors onto stderr.
#               also when we error out it would be good to capture info_msg and error_msg

if [[ $EUID -eq 0 ]]; then
  echo "edacfg.bash: ERROR"
  echo "  Please don't run as root. This script has tons of arbitrary code execution paths in it due to eval's"
  return 10000
fi

if [ "${EDA_CFG_DEBUG}" == "2" ]; then
  debug=true
  echo "${note}\n  Running edacfg in debug mode..."
  set -xv
  PS4='$LINENO: '
fi

# Variables and function for pretty printing errors.
error_msg="edacfg.bash: ERROR"
function error () {
  local indent=''
  for ((i=1; i < ${#FUNCNAME[@]}; i++)); do
    indent+='  '
  done
  error_msg="${error_msg}\n${indent}${BASH_LINENO[0]} ${FUNCNAME[1]}: ${1}"
  return 0
}

# Variables and function for pretty printing INFO.
info_msg="edacfg.bash: INFO"
function info () {
  local indent=''
  for ((i=1; i < ${#FUNCNAME[@]}; i++)); do
    indent+='  '
  done
  info_msg="${info_msg}\n${indent}${BASH_LINENO[0]} ${FUNCNAME[1]}: ${1}"
  return 0
}

# Function appendif & prependif var string
#  var is a : separated list of paths/names not including :
function appendif () {
  var=${!1}
  if [[ ":$var:" != *":$2:"* ]]; then
    export $1="${var:+"$var:"}$2"
    return 0
  else
    return 1
  fi
}

function prependif () {
  var=${!1}
  if [[ ":$var:" != *":$2:"* ]]; then
    export $1="$2${var:+":$var"}"
    return 0
  else
    return 1
  fi
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

function process_tool_file () {
  #First read the file to check that there is only one NAME. Prevent destructive alterations.
  info "File \"${1}\"."
  while IFS= read line
  do
    read -r -a tokens <<< "${line}"
    case "${tokens[0]}" in
      NAME)
        if [[ ":${EDA_CFG_ACTIVE_TOOLS}:" != *":${tokens[1]}:"* ]]; then
          name=${tokens[1]}
	else
          info "File \"${1}\"."
          info "Tool of name \"${tokens[1]}\" is already active."
          return 0
        fi
        name="${tokens[1]}"
        info "NAME: ${tokens[1]}"
        ;;
      VERSION)
        ver="${tokens[1]}"
        info "VERSION: $ver"
        ;;
    esac
  done <"${1}"

  desc="Setting up environment for $name $ver"

  # Second run process tokens
  info "Processing File \"${1}\"."
  while IFS= read line
  do
    read -r -a tokens <<< "${line}"

    case "${tokens[0]}" in
      \#*)
        info "#: Found a comment!"
        ;;
      NAME)
        ;;
      VERSION)
        ;;
      DESC)
        desc="${tokens[@]:1}"
        info "INFO: $desc"
        ;;
      ENV)
        eval env="${tokens[2]}"
        export ${tokens[1]}="$env"
        info "ENV: exported ${tokens[1]}=$env"
        ;;
      APPENDIF)
        eval var="${tokens[2]}"
        info "APPENDIF: ${var} ${tokens[1]}"
        appendif "${tokens[1]}" "$var"
        if [ $? -eq 1 ]; then
          info "  \"${var}\" already in ${tokens[1]}."
        fi
        ;;
      PREPENDIF)
        eval var="${tokens[2]}"
        info "PREPENDIF: ${var} ${tokens[1]}"
        prependif "${tokens[1]}" "$var"
        if [ $? -eq 1 ]; then
          info "  \"${var}\" already in ${tokens[1]}."
        fi
        ;;
      *)
        error "File \"${1}\"."
        error "Unknown token \"${tokens[0]}\"."
        return 10
        ;;
    esac
  done <"${1}"
  # Only append the tool name if everything else worked.
  appendif EDA_CFG_ACTIVE_TOOLS "$name"
  echo "$desc"

  return 0
}

##
#
# MAIN PROCESSING BEGINS
#
##

# Find out where we are
EDA_CFG_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Find and set file to full path of global_settings
if [ -n "${EDA_CFG_SETTINGS}" ]; then
  if [ -s "${EDA_CFG_SETTINGS}" ]; then
    file="${EDA_CFG_SETTINGS}"
  else
    error "\$EDA_CFG_SETTINGS was used to override the default"
    error "  edacfg_global_settings file"
    error "  but is set to a non-file target: ${EDA_CFG_SETTINGS}"
    echo -e "${error_msg}"
    return 10
  fi
elif [ -f "${EDA_CFG_DIR}/edacfg_global_settings" ]; then
  file="${EDA_CFG_DIR}/edacfg_global_settings"
else
  error "No valid edacfg_global_settings file found in the script dir."
  error "  \$EDA_CFG_DIR=${EDA_CFG_DIR}"
  echo -e "${error_msg}"
  return 10
fi
process_settings_file $file

# Loop over tools passed as arguments
for tool in "$@"; do
  file="${EDA_CFG_FILES}/${tool}.${EDA_CFG_FILE_EXT}"
  if [ -s "${file}" ]; then
    process_tool_file "${file}"
    if [ $? -ne 0 ]; then
      error "Processing tool file \"$file\" failed."
      echo -e "${error_msg}"
      echo -e "${info_msg}"
      return 10
    fi
  else
    error "Usage: source edacfg.bash eda_tool"
    echo -e "${error_msg}"
    echo -e "${info_msg}"
    return 10
  fi
done

# Cleanup, unset debug nastiness and capture information
if [ "${EDA_CFG_DEBUG}" == "2" ]; then
  set +xv
  unset PS4
  echo -e "${info_msg}"
  echo -e "${info_msg}" > edacfg.bash.info
  env > edacfg.bash.env
fi

if [ "${EDA_CFG_DEBUG}" == "1" ]; then
  echo -e "${info_msg}"
  echo -e "${info_msg}" > edacfg.bash.info
fi

