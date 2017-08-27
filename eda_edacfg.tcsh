##
#
# New edacfg code to support shell agnostic tool config file
# Sourced by edastart.tcsh
#
##

if ( ! $?edastart ) then
  echo "edacfg.tcsh: ERROR"
  echo " Please source this script using edastart.tcsh, don't use it directly." 
  exit 10000
endif
if ( "$edastart" != "sourced" ) then
  echo "edacfg.tcsh: ERROR"
  echo " Please source this script, don't execute it." 
  exit 10000
endif

info  "eda_edacfg.tcsh: INFO"
error "eda_edacfg.tcsh: ERROR"

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
              set name=$tokens[2]
            else
              info "File $file."
              info "Tool of name ${tokens[2]} is already active."
              goto SKIP
            endif
          else # create path if doesn't exist
            set name=$tokens[2]
          endif
          info "NAME: $tokens[2]"
          breaksw
        case VERSION:
          eval set ver = $tokens[2]
          info "VERSION: $ver"
          breaksw
      endsw
    end
  
    if ($?ver == 1) then
      set desc = "Setting up environment for $name $ver"
    else
      set desc = "Setting up environment for $name"
    endif
  
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
        case DESC:
          set desc = ($line)
          shift desc
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
        case ALIAS:
          set new_alias = ($line)
          shift new_alias
          set new_alias_name = $new_alias[1]
          shift new_alias
          set new_alias_body = ($new_alias)
          eval alias $new_alias_name "$new_alias_body"
          info "ALIAS: added $new_alias_name $new_alias_body"
          breaksw
        case NAME:
          breaksw
        case VERSION:
          breaksw
        default:
          error "File ${file}."
          error "Unknown token ${tokens[1]}."
  	echo "$error_msg"
          exit 10
          breaksw
      endsw
    end
    # Only append the tool name if everything else worked.
    if ($?EDA_CFG_ACTIVE_TOOLS == 0) then
      setenv EDA_CFG_ACTIVE_TOOLS "$name"
    else
      setenv EDA_CFG_ACTIVE_TOOLS ${EDA_CFG_ACTIVE_TOOLS}:$name
    endif
    echo "$desc"
    SKIP:  #Break from above if tool is already defined. icky!
  
  else
    source ${EDA_CFG_ROOT}/setup/edacfg $tool
  endif
  
end

