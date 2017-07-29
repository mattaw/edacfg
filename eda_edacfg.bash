#!/bin/bash
# File for loading and controlling the environment of EDA tools.
#  Based on the work by Dr. Mark Johnson, Purdue University
#    thoughts - improve the error printout to put info and errors onto stderr.
#               also when we error out it would be good to capture info_msg and error_msg
# Now sourced via edastart.bash on demand.
# Copyright Mark Johnson and Matthew Swabey matthew@swabey.org.

if [ "$edastart" != "sourced" ]; then
  echo "edacfg.bash: ERROR"
  echo "  Please source instead of execute."
  return 10000
fi 

info  "eda_edacfg.bash: INFO"
error "eda_edacfg.bash: ERROR"

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
      ALIAS)
	new_alias="function ${tokens[1]} { ${tokens[@]:2}; }"
	eval "$new_alias"
        info "ALIAS: $new_alias"
	export -f "${tokens[1]}"
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

# Loop over tools passed as arguments
for tool in $@; do
  file="${EDA_CFG_FILES}/${tool}.${EDA_CFG_FILE_EXT}"
  if [ -s "${file}" ]; then
    process_tool_file "${file}"
    if [ $? -ne 0 ]; then
      error "Processing tool file \"$file\" failed."
      print_msgs
      return 10
    fi
  else
    echo -e "ERROR: edacfg.bash:\n  Usage: source edacfg.bash eda_tool\n  eda_tool $file not found."
    return 10
  fi
done

