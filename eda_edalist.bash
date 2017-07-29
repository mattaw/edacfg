#!/bin/bash
# File for listing the available eda files
#  Based on the work by Dr. Mark Johnson, Purdue University
# Now sourced via edastart.bash on demand.
# Copyright Mark Johnson and Matthew Swabey matthew@swabey.org.
#
# Improvements to be done:
#  - If called with edalist <arg> look for <arg> list of tools and only print 
#      them

if [ "$edastart" != "executed" ]; then
  echo "edalist.bash: ERROR"
  echo "  Please execute, don't source"
  return 10000
fi 

info "eda_edalist.bash: INFO"
error "eda_edalist.bash: ERROR"

function process_config_file () {
  info "File \"${1}\"."

  comments=""

  while IFS= read line
  do
    read -r -a tokens <<< "${line}"

    case "${tokens[0]}" in
      \#*)
        info "#: Found a comment!"
        comments="${tokens[@]:1}"
        comments="${comments}\n"
        ;;
      NAME)
        name="${tokens[1]}"
        info "NAME: ${tokens[1]}"
        ;;
      VERSION)
        ver="${tokens[1]}"
        info "VERSION: $ver"
        ;;
      DESC)
        desc="${tokens[@]:1}"
        info "INFO: $desc"
        ;;
    esac
  done <"${1}"

  echo "$name $ver"
  echo "  $desc"
  echo -e "  $comments"
  echo "    If running bash: "
  echo "    source ${EDA_CFG_ROOT}/setup/edacfg.bash $(basename $file)"
  echo "    If running tcsh: "
  echo "    source ${EDA_CFG_ROOT}/setup/edacfg.tcsh $(basename $file)"
  echo " "

  return 0
}

echo " "
echo EDA Software Installed for Linux
echo For each set of software, a short description is given
echo followed by the command that needs to be added to your .bashrc
echo or .cshrc echo file to use that software
echo " "
echo Note: "edalist.bash -v" will list all installed versions of EDA tools,
echo not just the default versions. 
echo " "

while getopts ":v" opt; do
  case $opt in
    v)
      listall="true"
      ;;
    h)
      echo " "
      echo Notes: 
      echo " "
      echo Multiple entries can be combined on a single edacfg line,
      echo for example
      echo " "
      echo source /usr/site/ece/bin/edacfg.bash ic msim
      echo " "
      echo "or"
      echo source /usr/site/ece/bin/edacfg.tcsh ic msim
      echo " "
      echo will configure both Cadence virtuoso and Mentor Graphics modelsim
      ;;
    \?)
      echo -e "ERROR: edalist.bash\n Invalid option: -${OPTARG}" >&2
      ;;
  esac
done 

for file in ${EDA_CFG_FILES}/*.${EDA_CFG_FILE_EXT}; do
  if [ -z "$listall" ]; then
    if [ -h "$file" ]; then
      process_config_file "$file"
    fi
  else
    if [ ! -h "$file" ]; then
      process_config_file "$file"
    fi
  fi
done

