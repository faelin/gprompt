#!/bin/sh



## ---------------- ##
##   gprompt main
## ---------------- ##


# while test $# -gt 0; do
#   case "$1" in
#     -h|--help)
#       echo "$package - attempt to capture frames"
#       echo " "
#       echo "$package [options] application [arguments]"
#       echo " "
#       echo "options:"
#       echo "-h, --help                show brief help"
#       echo "-a, --action=ACTION       specify an action to use"
#       echo "-o, --output-dir=DIR      specify a directory to store output in"
#       exit 0
#       ;;
#     -a)
#       shift
#       if test $# -gt 0; then
#               export PROCESS=$1
#       else
#               echo "no process specified"
#               exit 1
#       fi
#       shift
#       ;;
#     --action*)
#       export PROCESS=`echo $1 | sed -e 's/^[^=]*=//g'`
#       shift
#       ;;
#     -o)
#       shift
#       if test $# -gt 0; then
#               export OUTPUT=$1
#       else
#               echo "no output dir specified"
#               exit 1
#       fi
#       shift
#       ;;
#     --output-dir*)
#       export OUTPUT=`echo $1 | sed -e 's/^[^=]*=//g'`
#       shift
#       ;;
#     *)
#       exit 1
#       ;;
#   esac
# done


## --------------------- ##
##   gprompt utilities
## --------------------- ##

## Loads existing gprompt values from conf (this will trigger a   gprompt_reset   if no conf file is found)
#      • stores the previous PS1 variable, which will be used when disabling gprompt
#      • sets the PS1 prompt variable to display the newly loaded gprompt format
#      • this should only be used when logging into a new shell session, or after you have manually disabled gprompt if you wish to turn it back on.
#
gprompt_init() {
  export GPROMPT_OFF=${PS1}
  gprompt_reload
  export PS1='$( gprompt_generate )'
}

## Resets the gprompt format back to the default values
#      NOTE: this will overwrite your custom prompt formatting! Please back up your   ~/.gprompt/.gprompt_conf   before attempting a reset!
#
gprompt_reset() {
  export GPROMPT_FORMAT='{\c{1;93}[\c22{%r}:\c1{%b}{\c91~{%~}}{\c92+{%+}}{ {\c96<{%s}>}{\c95({%u})}}\c93]\c0}%p $>'
  export GPROMPT_WRAPPER=' '
  gprompt_save
}

## Reads the currently stored gprompt definitions from the gprompt conf file
#      • if the conf file cannot be found, gprompt will reset the existing gprompt defintions and store them to disk
#      • only the first instance of each definition will be used
#
gprompt_reload() {
  mkdir ~/.gprompt 2> /dev/null

  if [ -f ~/.gprompt/.gprompt_conf ]
  then
    gprompt_format_loaded="$(grep -m 1 -E "^GPROMPT_FORMAT='.*'" ~/.gprompt/.gprompt_conf)" && eval "export $gprompt_format_loaded"
    gprompt_wrapper_loaded="$(grep -m 1 -E "^GPROMPT_WRAPPER='.*'" ~/.gprompt/.gprompt_conf)" && eval "export $gprompt_wrapper_loaded"
  else
    gprompt_reset
  fi
}

## Disables gprompt and sets your PS1 back to the value it had before GPROMPT was initialized
#
gprompt_off() {
  export PS1=${GPROMPT_OFF}
}


## Sets the gprompt format
#     EXAMPLE FORMATS:
#       {%d[%r:%b%~%+ <%s>(%u)]}%p $>
#       {[%r:%b%~%+{(%c)} <%s>(%u)] Git://%r}%p $>
#       {%d%r}%p{ [%b%~%+{(%c)} <%s>(%u)]} $>
#
gprompt_set_format() {
  export GPROMPT_FORMAT=$1
}

## Short string used to pad your prompt, recommended default is ' ' (single blank space)
#     provided string is split at midpoint (round down) to create left- and right-wrappers,
#     thus a wrapper '[]' yields '[<gprompt>]'
#     while a wrapper '[(]' yields '[<gprompt>(]'
gprompt_set_wrapper() {
  export GPROMPT_WRAPPER=$1
}

## Overwrites the existing gprompt conf file with the currently exported gprompt definitions for your session.
#
gprompt_save() {
  (
    echo "GPROMPT_FORMAT='$( sed -e "s/'/\'/g" <<< "$GPROMPT_FORMAT" )'" ;
    echo "GPROMPT_WRAPPER='$( sed -e "s/'/\'/g" <<< "$GPROMPT_WRAPPER" )'" ;
  ) > ~/.gprompt/.gprompt_conf
}



## -------------------------- ##
##   gprompt core functions
## -------------------------- ##

## Updates gprompt, does not provide output
#     returns 0 before git-status variables would be updated, if PWD is not a git repo
#
gprompt_git_status() {
  full_path=$( pwd )
  repo_name=$( basename -s .git $( git config --get remote.origin.url ) 2> /dev/null )
  repo_path=$( [[ -n $repo_name ]] && sed -nE "s|^(.*)/$repo_name(/.*)?$|\2|p" <<< "$full_path" || echo "$full_path" )

  if [[ -n $repo_name ]]
  then
    branch_status=$( git branch -v 2> /dev/null | grep '^* ' )

    staged_count=$( git status --porcelain=1 2> /dev/null | grep -e '^[^?! ]' | wc -l | sed -E 's|0||' | xargs )
    unstag_count=$( git status --porcelain=1 2> /dev/null | grep -e '^.[^ ]'  | wc -l | sed -E 's|0||' | xargs )

    branch_name=$(  sed -nE 's|^[[:blank:]]*\*[[:blank:]]+([^[[:blank:]]+)[[:blank:]]+[^[:blank:]]+[[:blank:]]+.*|\1|p' <<< "$branch_status" | xargs  )
    commit_name=$(  sed -nE 's|^[[:blank:]]*\*[[:blank:]]+[^[[:blank:]]+[[:blank:]]+([^[:blank:]]+)[[:blank:]]+.*|\1|p' <<< "$branch_status" | xargs  )
    ahead_count=$(  sed -nE 's|^[[:blank:]]*\*[[:blank:]]+[^[:blank:]]+[[:blank:]]+[^[:blank:]]+[[:blank:]]+(\[ahead[[:blank:]]+([[:digit:]]+)\])?.*|\2|p' <<< "$branch_status" | xargs  )
    behind_count=$( sed -nE 's|^[[:blank:]]*\*[[:blank:]]+[^[:blank:]]+[[:blank:]]+[^[:blank:]]+[[:blank:]]+(\[behind[[:blank:]]+([[:digit:]]+)\])?.*|\2|p' <<< "$branch_status" | xargs )

    lead_path=$( sed -nE "s|^(.*)/$repo_name(/.*)?$|\1|p" <<< "$full_path" )
  fi
}

## Replaces gprompt-specific escapes with printf-parsible ANSI color escape wrapped in PS1-parsible non-printing-characters brackets
#     exclamation points ('!') in  sed  substitutions are purely to increase legibility amonst a lot of backslashes
#
gprompt_parse_format() {
  sed -E '
            s!\\c(([[:digit:]]+)|{([[:digit:];]+)})(\\c(([[:digit:]]+)|{([[:digit:];]+)}))?!\\001\\033[\2\3;\5\6m\\002!g;
            # s!((\\e\[([[:digit:]]+;)+m)+)!\[\1\]!g;
            # s!\\t<([[:digit:]]+)>!\e[\2\3m!g;
         ' <<< "$GPROMPT_FORMAT"
}

## Outputs the a populated git-prompt based on the contents of GPROMPT_FORMAT (see the `gprompt_set_format` function description for more information)
#
gprompt_populate_prompt() {
  gprompt_git_status
  
  gprompt_string="$( sed -e "s|%p|$repo_path|g" <<< "$(gprompt_parse_format)" )"

  if [[ -n $repo_name ]]
  then
    # if in a git-repo, populate all format-strings
    sed -e "
            s|%r|$repo_name|g;
            s|%d|$lead_path|g;
            s|%p|$repo_path|g;
            s|%b|$branch_name|g;
            s|%+|$ahead_count|g;
            s|%~|$behind_count|g;
            s|%s|$staged_count|g;
            s|%u|$unstag_count|g;

           " <<< "$gprompt_string"
  else
    # if not a git-repo, strip all formatting characters
    sed -e "s|%[[:alnum:]~+]||g" <<< "$gprompt_string"
  fi
}

## Removes blank/useless values wrapped in curly-braces, then subsequently removes ALL unescaped curly-braces!
#     blank/useless is defined as any value that DOES NOT contain non-formatting alphanumeric characters
#
gprompt_cleanup_prompt() {
  gprompt_string=$1

  ## strip all blank/useless curly-brace wrapped content, recursively from the inside out
  while [[ $( grep -m 1 -E '(^|[^\\]){((\\001\\033\[[[:digit:];]+m\\002|%[[:alpha:]~+]|[^{}[:alnum:]]*)+|[[:blank:]]+)}' <<< "$gprompt_string" ) ]]
  do
    gprompt_string="$( sed -E 's/(^|[^\\]){((\\001\\033\[[[:digit:];]+m\\002|%[[:alpha:]~+]|[^{}[:alnum:]]*)+|[[:blank:]]+)}/\1/g' <<< "$gprompt_string"  )"
  done

  ## strip all non-escaped curly braces, from left to right
  while [[ $( grep -m 1 -E '(^|[^\\])[{}]' <<< "$gprompt_string" ) ]]
  do
    gprompt_string="$( sed -E 's/(^|[^\\])[{}]/\1/g' <<< "$gprompt_string"  )"
  done

  echo "$gprompt_string"
}

## Generates a fully formatted/colored/populated git-prompt that can be fed directly into your shell prompt variable
#     intended usage is   export PS1='$( gprompt_generate )'   or equivalent
#
gprompt_generate() {
  gprompt_string=`gprompt_cleanup_prompt "$( gprompt_populate_prompt )"`


  # this chunk formates the gprompt wrapper variables, which are used to pad the gprompt string
  #     for more info, see the   gprompt_set_wrapper()   description
  gprompt_wrapper_length=${#GPROMPT_WRAPPER}
  gprompt_wrapper_midpoint=$(($gprompt_wrapper_length/2))
  if [ $gprompt_wrapper_midpoint -gt 0 ]
  then
    gprompt_wrapper_left=$( echo "${GPROMPT_WRAPPER:0:$gprompt_wrapper_midpoint}" )
    gprompt_wrapper_right=$( echo "${GPROMPT_WRAPPER:$gprompt_wrapper_midpoint:$gprompt_wrapper_length}" )
  else
    gprompt_wrapper_left="${GPROMPT_WRAPPER}"
    gprompt_wrapper_right="${GPROMPT_WRAPPER}"
  fi


  printf "${gprompt_wrapper_left}${gprompt_string}${gprompt_wrapper_right}"
}

