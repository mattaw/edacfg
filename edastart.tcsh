##
#
# New edastart code to support shell agnostic tool config file
# Then sources actual command
#
##

if ( `/usr/bin/id -u` == "0" ) then
  echo "edastart.tcsh: ERROR"
  echo "  Please don't run as root. This script has tons of arbitrary code execution paths in it due to eval's"
  exit 10000
endif

# Set marker to know that edastart.tcsh was called.
set edastart = "True"

# Debug support
if ( $?EDA_CFG_DEBUG ) then
  if ("$EDA_CFG_DEBUG" == "2" ) then
    set verbose
    set echo
  endif
endif

# Error support
set error_msg = "edacfg: ERROR"
alias error 'eval set error_msg = \"${error_msg}\\n  \!*\"'

# Info support
set info_msg = "edacfg: INFO"
alias info 'eval set info_msg = \"${info_msg}\\n  \!*\"'

# Find out where we are
set called=($_)
if ( "$called" != "" ) then
  set invoc="$called[2]"
  set script="${invoc:t}"
  set rootdir="${invoc:h}"
  set EDA_CFG_DIR = ${rootdir}
else
  echo "edastart.tcsh: ERROR"
  echo " Please source this script, do not execute it directly." 
  exit 10000
endif

echo "$invoc"
echo "${invoc:t}"
echo "${invoc:h}"

# We should not be sourced or called directly
if ( "$script" == "edastart.tcsh" ) then
  echo "edastart.tcsh: ERROR"
  echo " Please do not source this script directly."
  exit 10000
endif

# Find the edacfg_global_settings file and point file to it.
if ( $?EDA_CFG_SETTINGS ) then
  if (-f "$EDA_CFG_SETTINGS") then
    set file "$EDA_CFG_SETTINGS"
  else
    error "EDA_CFG_SETTINGS was used to override the default"
    error "  edacfg_global_settings file"
    error "  but is set to a non-file target: ${EDA_CFG_SETTINGS}"
    echo $error_msg
    exit 10
  endif
else if (-f "${EDA_CFG_DIR}/edacfg_global_settings") then
  set file = "${EDA_CFG_DIR}/edacfg_global_settings"
else
  error "No valid edacfg_global_settings file found in the script dir."
  error "  EDA_CFG_DIR=${EDA_CFG_DIR}"
  echo $error_msg
  exit 10
endif

# Parse and load the global settings file
foreach line ( "`cat $file`" )
  set tokens = ($line)
  switch ($tokens[1])
    case \#*:
      breaksw
    case ENV:
      set var = `eval echo $tokens[2]`
      set val = `eval echo $tokens[3]`
      setenv $var $val
      info "ENV: setenv $var $val"
      breaksw
    case UMASK:
      umask $tokens[2]
      info "UMASK: umask $tokens[2]"
      breaksw
    default:
      error "File ${file}."
      error "Unknown token ${tokens[1]}."
      echo "$error_msg"
      exit 10
      breaksw
  endsw
end

source "${rootdir}/eda_${script}" $*

