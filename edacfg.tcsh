##
#
# New edacfg code to support shell agnostic tool config file
#
##

# Debug support
if ( $?EDA_CFG_DEBUG ) then
  if ("$EDA_CFG_DEBUG" == "2" ) then
    set verbose
    set echo
  endif
endif

# Error support
set error_msg = "edacfg: ERROR"
alias error 'eval set error_msg = \"${error_msg}\\n \!*\"'

# Info support
set info_msg = "edacfg: INFO"
alias info 'eval set info_msg = \"${info_msg}\\n \!*\"'

# Find out where we are
set rootdir = `/usr/bin/dirname $0`       # may be relative path
set rootdir = `cd ${rootdir} && pwd`    # ensure absolute path
set EDA_CFG_DIR = ${rootdir}

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
      exit 10
      breaksw
  endsw
end

foreach tool ($*)

set file = "${EDA_CFG_FILES}/$tool.${EDA_CFG_FILE_EXT}"
if (-f $file) then
  info "Found ${EDA_CFG_FILE_EXT} file:"
  info "${EDA_CFG_FILES}/${tool}.${EDA_CFG_FILE_EXT}"

  # Parse and load the tool file
  #
  # First run check the name doesn't already exist
  foreach line ( "`cat $file`" )
    set tokens = ($line)
    switch ($tokens[1])
      case NAME:
        if ($?EDA_CFG_ACTIVE_TOOLS == 1) then
          if ("$EDA_CFG_ACTIVE_TOOLS" !~  *"$tokens[2]"*) then
            setenv EDA_CFG_ACTIVE_TOOLS ${EDA_CFG_ACTIVE_TOOLS}:$tokens[2]
          else
            error "File $file."
            error "Only one tool of name \"${tokens[1]}\" allowed to be active at a time."
            echo $error_msg
            exit 10
          endif
        else # create path if doesn't exist
          setenv EDA_CFG_ACTIVE_TOOLS $tokens[2]
        endif
        info "NAME: $tokens[2]"
        breaksw
    endsw
  end

  # Second run actually process the file
  foreach line ( "`cat $file`" )
    set tokens = ($line)
    switch ($tokens[1])
      case \#*:
        info "#: Found a comment!"
        breaksw
      case ENV:
        set var = `eval echo $tokens[2]`
        set val = `eval echo $tokens[3]`
        setenv $var $val
        info "ENV: setenv $var $val"
        breaksw
      case VERSION:
        eval set ver = $tokens[2]
        info "VERSION: $ver"
        breaksw
      case APPENDIF:
        set var = $tokens[2]
        set appendee = `eval echo $tokens[3]`
        if ( `eval echo \$\?$var` ) then
          set val = `eval echo \$$var`
          if ("$val" !~  *"$appendee"*) then
            eval setenv $var "${val}:${appendee}"
          endif
        else # create path if doesn't exist
          eval setenv $var $appendee
        endif
        info "APPENDIF: added $var $appendee"
        breaksw
      case PREPENDIF:
        set var = $tokens[2]
        set prependee = `eval echo $tokens[3]`
        if ( `eval echo \$\?$var` ) then
          set val = `eval echo \$$var`
          if ("$val" !~  *"$prependee"*) then
            eval setenv $var "${prependee}:${val}"
          endif
        else # create path if doesn't exist
          eval setenv $var $prependee
        endif
        info "PREPENDIF: added $var $prependee"
        breaksw
      case NAME:
        breaksw
      default:
        error "File ${file}."
        error "Unknown token ${tokens[1]}."
        exit 10
        breaksw
    endsw
  end

else
  source ${EDA_CFG_ROOT}/setup/edacfg $tool
endif
