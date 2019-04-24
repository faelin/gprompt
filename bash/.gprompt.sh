#!/bin/sh

gprompt_version='2019.04.23.1'
gprompt_source="$(dirname $BASH_SOURCE)"
gprompt_exports=(
                  GPROMPT_FORMAT
                  GPROMPT_WRAPPER
                  GPROMPT_PATHTYPE
                  GPROMPT_UPDATE_AUTO
                  GPROMPT_UPDATE_INTERVAL
                )

gprompt_updater_loop &> /dev/null &
gprompt_updater_loop_id=$!
#clear
#echo $gprompt_updater_loop_id

## ---------------- ##
##   gprompt main
## ---------------- ##

gprompt() {
  while (( "$#" ))
  do
    case "$1" in
      -v|--version)
        echo "gprompt - version $gprompt_version $( [ $gprompt_commit ] && echo "($gprompt_commit)" )"
        shift
        return 0
        ;;
      init)
        gprompt_init
        shift
        return 0
        ;;
      reset)
        gprompt_reset
        shift
        return 0
        ;;
      reload)
        gprompt_reload
        shift
        return 0
        ;;
      off)
        gprompt_off
        shift
        return 0
        ;;
      --get-format|format)
        echo "$GPROMPT_FORMAT"
        shift
        return 0
        ;;
      --get-wrapper|wrapper)
        echo "$GPROMPT_WRAPPER"
        shift
        return 0
        ;;
      --get-pathtype|pathtype)
        echo "$GPROMPT_PATHTYPE"
        shift
        return 0
        ;;
      --set-format|--format)
        if grep -m 1 -ve '^--?|^$' <<< "$2"
        then
          gprompt_set_format "$2"
          shift 2
        else
          echo "$GPROMPT_FORMAT"
          shift
          return 0
        fi
        ;;
      --set-wrapper|--wrapper)
        if grep -m 1 -ve '^--?/$^' <<< "$2"
        then
          gprompt_set_wrapper "$2"
          shift 2
        else
          echo "$GPROMPT_WRAPPER"
          shift
          return 0
        fi
        ;;
      --set-pathtype|--pathtype)
        if grep -m 1 -ve '^--?|^$' <<< "$2"
        then
          gprompt_set_pathtype "$2"
          shift 2
        else
          echo "$GPROMPT_PATHTYPE"
          shift
          return 0
        fi
        ;;
      --set-format=*|--format=*)
        local opt=$( sed -nE "s/^--(set-)?format=(.*)/\2/p" <<< $1 )
        if [[ -n $opt ]]
        then
          gprompt_set_format "$opt"
          shift
        else
          echo "    Option '$1' requires an argument."
          shift
          return 1
        fi
        ;;
      --set-wrapper=*|--wrapper=*)
        local opt=$( sed -nE "s/^--(set-)?wrapper=(.*)/\2/p" <<< $1 )
        if [[ -n $opt ]]
        then
          gprompt_set_wrapper "$opt"
          shift
        else
          echo "    Option '$1' requires an argument."
          shift
          return 1
        fi
        ;;
      --set-pathtype=*|--pathtype=*)
        local opt=$( sed -nE "s/^--(set-)?pathtype=(.*)/\2/p" <<< $1 )
        if [[ -n $opt ]]
        then
          gprompt_set_pathtype "$opt"
          shift
        else
          echo "    Option '$1' requires an argument."
          shift
          return 1
        fi
        ;;
      --save|save)
        gprompt_save
        shift
        ;;
      -h|--help|help|*)
        echo << EOHELP
GPROMPT — customizable git status in your command prompt!
    version $gprompt_version

usage: gprompt [--version] [--help] [-C <path>] 
EOHELP
        shift
        return 1
        ;;
    esac
  done

  while getopts "f:w:s" opt
  do
    case $opt in
      f)
        gprompt_set_format "$OPTARG"
        ;;
      w)
        gprompt_set_wrapper "$OPTARG"
        ;;
      s)
        gprompt_save
        ;;
      :)
        echo "    Option '-$OPTARG' requires an argument."
        return 1
        ;;
    esac
  done
}



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
  if gprompt_reload
  then
    export PS1='$( gprompt_generate )'
  else
    echo "gprompt - failed to load from .gprompt_conf!"
    return 1
  fi
}

## Reads the currently stored gprompt definitions from the gprompt conf file
#      • if the conf file cannot be found, gprompt will reset the existing gprompt defintions and store them to disk
#      • only the first instance of each definition will be used
#
gprompt_reload() {
  if [[ -f ~/.gprompt/.gprompt_conf ]] && [[ `wc -l ~/.gprompt/.gprompt_conf | xargs | cut -d' ' -f1` -gt 0 ]]
  then
    for xvar in "${gprompt_exports[@]}"
    do
      local gprompt_xvar_load="$(tail -r ~/.gprompt/.gprompt_conf | grep -m 1 -E "^$xvar='[^']*'$" )"
      [[ -n $gprompt_xvar_load ]] && eval "export $gprompt_xvar_load" || return 1
    done
  else
    gprompt_reset
  fi
}

## Resets the gprompt format back to the default values
#      NOTE: this will overwrite your custom prompt formatting! Please back up your   ~/.gprompt/.gprompt_conf   before attempting a reset!
#
gprompt_reset() {
  export GPROMPT_FORMAT='{\c{1;93}[\c22{%r}:\c1{%b}{\c91-{%-}}{\c92+{%+}}{ {\c96<{%s}>}{\c95({%u})}}\c93]\c0}%d $>'
  export GPROMPT_WRAPPER=' '
  export GPROMPT_PATHTYPE='abs'
  export GPROMPT_UPDATE_AUTO=0
  export GPROMPT_UPDATE_INTERVAL=600
  gprompt_save 1> /dev/null
}

## Disables gprompt and sets your PS1 back to the value it had before GPROMPT was initialized
#
gprompt_off() {
  export PS1="$GPROMPT_OFF"
}


## Sets the gprompt format
#
#     FORMAT CODES:
#         ANSI Color Escapes:
#              \c<integer>
#              \c{<integer>[;...]}
#
#
#     EXAMPLE FORMATS:
#       {%d[%r:%b%~%+ <%s>(%u)]}%p $>
#       {[%r:%b%~%+{(%c)} <%s>(%u)] Git://%r}%p $>
#       {%d%r}%p{ [%b%~%+{(%c)} <%s>(%u)]} $>
#
#
            # ## DIRECTORY INFO
            # s;%(d(ir(ectory)?)?|{d(ir(ectory)?)?});$local_path;g
            # s;%(p(arent)?|{p(arent)?});$parent_path;g;

            # ## REPO INFO
            # s;%(r(epo)?|{r(epo)?});$repo_name;g;
            # s;%(b(ranch)?|{b(ranch)?});$branch_name;g;
            # s;%(c(om(mit)?)?|{c(om(mit)?)?});$commit_hash;g;

            # ## BRANCH STATE
            # s;%(\+|{ahead});$ahead_count;g;
            # s;%(\-|{behind});$behind_count;g;
            # s;%(\~|{parent});$commit_parent;g;
            # s;%(\^|{merged});$commit_merged;g;

            # ## FILE STATUS MODES
            # s;%(s(taged)?|{s(taged)?});$staged_count;g;
            # s;%(u(nstaged)?|{u(nstaged)?});$unstag_count;g;

            # ## FILE STATUS COUNTS
            # s;%(mod(ified)?|{mod(ified)?});$mod_count;g;
            # s;%(add(ed)?|{add(ed)?});$add_count;g;
            # s;%(del(eted)?|{del(eted)?});$rem_count;g;
            # s;%(rem(oved)?|{rem(oved)?});$rem_count;g;
            # s;%(cop(y|ied)?|{cop(y|ied)?});$cop_count;g;
            # s;%(re(named)?|{re(named)?});$re_count;g;
            # s;%(up(dated)?|{up(dated)?});$up_count;g;
            # s;%(un(merged)?|{un(merged)?});$un_count;g;
            # s;%([?]|{untracked});$untracked_count;g;
            # s;%([!]|{ignored});$ignored_count;g;
#
#
gprompt_set_format() {

  export GPROMPT_FORMAT="$1"
  return 0
}

## Short string used to pad your prompt, recommended default is ' ' (single blank space)
#     provided string is split at midpoint (round down) to create left- and right-wrappers,
#     thus a wrapper '[]' yields '[<gprompt>]'
#     while a wrapper '[(]' yields '[<gprompt>(]'
gprompt_set_wrapper() {
  export GPROMPT_WRAPPER="$1"
  return 0
}

## Type of path that should be displayed by %d when not in a git-repo
#     options are:  'abs',  'rel'
gprompt_set_pathtype() {
  if [[ $1 == 'abs' ]] || [[ $1 == 'rel' ]]
  then
    export GPROMPT_WRAPPER="$1"
    return 0
  else
    export GPROMPT_WRAPPER="abs"
    return 1
  fi
}

## Overwrites the existing gprompt conf file with the currently exported gprompt definitions for your session.
#
gprompt_save() {
  mkdir ~/.gprompt 2> /dev/null
  touch ~/.gprompt/.gprompt_conf

  echo "gpropmpt - saving current config"

  for xvar in "${gprompt_exports[@]}"
  do
    local gprompt_xvar_save="$xvar='$( eval echo "\${$xvar}" )'"
    echo "    $gprompt_xvar_save"

    sed -i -e "/^$xvar=/d" ~/.gprompt/.gprompt_conf
    echo "$gprompt_xvar_save" >> ~/.gprompt/.gprompt_conf
  done
}



## ----------------------------- ##
##   gprompt private functions
## ----------------------------- ##

## runs in the background, exports a flag when an update is needed
#
__gprompt_updater_loop() {
  while true
  do
    export GPROMPT_UPDATE_NEEDED="$( __gprompt_updater_check )"
    sleep $GPROMPT_UPDATE_INTERVAL
  done
}

## checks if an update is available
#
__gprompt_updater_check() {
  echo 0
}

## determines what to do when an update is ready (ask/auto/suppress)
#
__gprompt_updater_mode() {
  echo 0
}

## updates gprompt to the latest 'stable' tag
#
__gprompt_updater() {
  local pwd="$(pwd)"
  cd $gprompt_source
  git pull https://github.com/faelin/gprompt.git stable
  cd $pwd
}



## -------------------------- ##
##   gprompt core functions
## -------------------------- ##

## Updates gprompt, does not provide output
#     returns 0 before git-status variables would be updated, if PWD is not a git repo
#
gprompt_git_status() {

  ## full_path gives the PWD in relative or absolute form depending on the state of $GPROMPT_PATHTYPE
  full_path=$( [[ $GPROMPT_PATHTYPE == 'rel' ]] && pwd -L | sed -E "s|^(/Users|/home)?/`whoami`(/.+)?|~\2|" || pwd -L )
  repo_name=$( basename -s .git $( git config --get remote.origin.url ) 2> /dev/null )

  if [[ -n $repo_name ]]
  then

    repo_status=$( git status --branch --ignored --porcelain=2 )
    repo_parent=$( git show -s --format='%P' HEAD )
    parent_path=$( sed -nE "s|^(.*)/$repo_name(/.*)?$|\1|p" <<< "$full_path" )
    local_path=$(  sed -nE "s|^(.*)/$repo_name(/.*)?$|\2|p" <<< "$full_path" )

    ## looks like:
    ##   '<parent1 SHA> <parent2 SHA>'
    commit_parent=$( sed -nE 's!^([[:alnum:]]{7}).*$!\1!p' <<< "$repo_parent" )
    commit_merged=$( sed -nE 's!^([[:alnum:]]{7})[[:alnum:]]+ ([[:alnum:]]{7}).*$!\2!p' <<< "$repo_parent" )


    ## looks like:
    ##   '# branch.oid <commit> | (initial)'        Current commit.
    ##   '# branch.head <branch> | (detached)'      Current branch.
    ##   '# branch.upstream <upstream_branch>'      If upstream is set.
    ##   '# branch.ab +<ahead> -<behind>'           If upstream is set and the commit is present.
    commit_hash=$(  sed -nE 's!^# branch.oid (\((initial)\)|([[:alnum:]]{7})).*$!\2\3!p' <<< "$repo_status"  )
    branch_name=$(  sed -nE 's!^# branch.head (\((detached)\)|(.*))$!\2\3!p' <<< "$repo_status"  )
    origin_name=$(  sed -nE 's!^# branch.upstream (.*)$!\1!p' <<< "$repo_status"  )
    ahead_count=$(  sed -nE 's!^# branch.ab \+([[:digit:]]+) -([[:digit:]]+)$!\1!p' <<< "$repo_status" | sed -nE 's/[[:blank:]]*0*([1-9][0-9]*)/\1/p'  )
    behind_count=$( sed -nE 's!^# branch.ab \+([[:digit:]]+) -([[:digit:]]+)$!\2!p' <<< "$repo_status" | sed -nE 's/[[:blank:]]*0*([1-9][0-9]*)/\1/p' )
    staged_count=$( grep -cE '^[[:alnum:]]+ [^[:blank:].][^[:blank:]]' <<< "$repo_status" | sed -nE 's/[[:blank:]]*0*([1-9][0-9]*)/\1/p' )
    unstag_count=$( grep -cE '^[[:alnum:]]+ [^[:blank:]][^[:blank:].]' <<< "$repo_status"  | sed -nE 's/[[:blank:]]*0*([1-9][0-9]*)/\1/p' )


    ## reference:
    ##   M = modified
    ##   A = added
    ##   D = deleted
    ##   C = copied
    ##   R = renamed
    ##   U = updated but unmerged
    ##   ! = ignored
    ##   ? = untracked
    mod_count=$( grep -cE '^.M' <<< "$repo_status" | sed -nE 's/[[:blank:]]*0*([1-9][0-9]*)/\1/p' )
    add_count=$( grep -cE '^.A' <<< "$repo_status" | sed -nE 's/[[:blank:]]*0*([1-9][0-9]*)/\1/p' )
    del_count=$( grep -cE '^.D' <<< "$repo_status" | sed -nE 's/[[:blank:]]*0*([1-9][0-9]*)/\1/p' )
    cop_count=$( grep -cE '^.C' <<< "$repo_status" | sed -nE 's/[[:blank:]]*0*([1-9][0-9]*)/\1/p' )
    re_count=$(  grep -cE '^.D' <<< "$repo_status" | sed -nE 's/[[:blank:]]*0*([1-9][0-9]*)/\1/p' )
    up_count=$(  grep -cE '^.U' <<< "$repo_status" | sed -nE 's/[[:blank:]]*0*([1-9][0-9]*)/\1/p' )
    ignored_count=$(   grep -ce '^!!' <<< "$repo_status" | sed -nE 's/[[:blank:]]*0*([1-9][0-9]*)/\1/p' )
    untracked_count=$( grep -ce '^??' <<< "$repo_status" | sed -nE 's/[[:blank:]]*0*([1-9][0-9]*)/\1/p' )

  else
    local_path="$full_path"
  fi
}

## Replaces gprompt-specific escapes with printf-parsible ANSI color escape wrapped in PS1-parsible non-printing-characters brackets
#     exclamation points ('!') in  sed  substitutions are purely to increase legibility amonst a lot of backslashes
#
gprompt_parse_format() {
  local gprompt_string="$GPROMPT_FORMAT"

  ## merge all parallel color format markers
  while [[ $( grep -E '\\c(([[:digit:]]+)|{([[:digit:];]+)})\\c(([[:digit:]]+)|{([[:digit:];]+)})' <<< "$gprompt_string" ) ]]
  do
    gprompt_string="$( sed -E 's!\\c(([[:digit:]]+)|{([[:digit:];]+)})\\c(([[:digit:]]+)|{([[:digit:];]+)})!\\c{\2\3;\5\6}!g' <<< "$gprompt_string" )"
  done


  gprompt_string=$(
    sed -E '
              s!\\\[!\\001!g;
                  ## replace all opening non-printing-character escapes ('\[')
              s!\\\]!\\002!g;
                  ## replace all closing non-printing-character escapes ('\]')
              s!\\e!\\033!g;
                  ## replace all ANSI escape characters ('\e')

              s!\\c(([[:digit:]]+)|{([[:digit:];]+)})!\\033[\2\3m!g;
                  ## reformat user color-codes into ANSI valid escapes
            # s!\\t<([[:digit:]]+)>!$(tput \1)!eg;
                  ## reformat user tput-codes into tput commands
              s!(\\033\[[[:digit:];]+m)!\\001\1\\002!g
                  ## wrap all ANSI color-escapes in non-printing-character escapes
           ' <<< "$gprompt_string"
  )


  # ## this chunk condenses all parallel ANSI color-escapes and redundant non-printing-character escapes
  # #
  # while [[ $( grep -E '\\033\[([[:digit:];]+)m\\033\[([[:digit:];]+)m' <<< "$gprompt_string" ) ]]
  # do
  #   gprompt_string="$( sed -E 's!\\033\[([[:digit:];]+)m\\033\[([[:digit:];]+)m!\\033[\1;\2m!g' <<< "$gprompt_string" )"
  # done

  # while [[ $( grep -vE '\\001\\001\\033\[([[:digit:];]+)m\\002\\002' <<< "$gprompt_string" ) ]]
  # do
  #   gprompt_string="$( sed -E 's!\\001\\001(\\033\[[[:digit:];]+m)\\002\\002!\\001\1\\002!g' <<< "$gprompt_string" )"
  # done

  # while [[ $( grep -E '\\001\\033\[([[:digit:];]+)m\\002\\001\\033\[([[:digit:];]+)m\\002' <<< "$gprompt_string" ) ]]
  # do
  #   gprompt_string="$( sed -E 's!\\001\\033\[([[:digit:];]+)m\\002\\001\\033\[([[:digit:];]+)m\\002!\\001\\003[\1;\2m\\002!g' <<< "$gprompt_string" )"
  # done

  echo "$gprompt_string"
}

## Outputs the a populated git-prompt based on the contents of GPROMPT_FORMAT (see the `gprompt_set_format` function description for more information)
#
gprompt_populate_prompt() {
  gprompt_git_status

  local gprompt_string=$(gprompt_parse_format)

  if [[ -n $repo_name ]]
  then
    # if in a git-repo, populate all format-strings
    sed -E "
            ## DIRECTORY INFO
            s/%(d(ir(ectory)?)?|{d(ir(ectory)?)?})/%directory/g;    s|%directory|$local_path|g;
            s/%(p(arent)?|{p(arent)?})/%parent/g;                   s|%parent|$parent_path|g;
            s/%((full)?path|{(full)?path})/%path/g;                 s|%path|$full_path|g;

            ## REPO INFO
            s/%(r(epo)?|{r(epo)?})/%repo/g;                s|%repo|$repo_name|g;
            s/%(b(ranch)?|{b(ranch)?})/%branch/g;          s|%branch|$branch_name|g;
            s/%(c(om(mit)?)?|{c(om(mit)?)?})/%commit/g;    s|%commit|$commit_hash|g;

            ## BRANCH STATE
            s/%(\+|{ahead})/$ahead_count/g;
            s/%(\-|{behind})/$behind_count/g;
            s/%(\~|{parent})/$commit_parent/g;
            s/%(\^|{merged})/$commit_merged/g;

            ## FILE STATUS MODES
            s/%(s(taged)?|{s(taged)?})/$staged_count/g;
            s/%(u(nstaged)?|{u(nstaged)?})/$unstag_count/g;

            ## FILE STATUS COUNTS
            s/%(mod(ified)?|{mod(ified)?})/$mod_count/g;
            s/%(add(ed)?|{add(ed)?})/$add_count/g;
            s/%(del(eted)?|{del(eted)?})/$del_count/g;
            s/%(rem(oved)?|{rem(oved)?})/$rem_count/g;
            s/%(cop(y|ied)?|{cop(y|ied)?})/$cop_count/g;
            s/%(re(named)?|{re(named)?})/$re_count/g;
            s/%(up(dated)?|{up(dated)?})/$up_count/g;
            s/%(un(merged)?|{un(merged)?})/$un_count/g;
            s/%([?]|{untracked})/$untracked_count/g;
            s/%([!]|{ignored})/$ignored_count/g;

           " <<< "$gprompt_string"
  else
    # if not a git-repo, strip all formatting characters except for  %d
    sed -E "
            s/%(d(ir(ectory)?)?|{d(ir(ectory)?)?})/%directory/g;    s|%directory|$local_path|g;

            s/%([[:alnum:]]+|[?!~^+-]|{[[:alnum:]]+})//g;

           " <<< "$gprompt_string"
  fi
}

## Removes blank/useless values wrapped in curly-braces, then subsequently removes ALL unescaped curly-braces!
#     blank/useless is defined as any value that DOES NOT contain non-formatting alphanumeric characters
#
gprompt_cleanup_prompt() {
  local gprompt_string=$1

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
  local gprompt_string=`gprompt_cleanup_prompt "$( gprompt_populate_prompt )"`

  # this chunk formates the gprompt wrapper variables, which are used to pad the gprompt string
  #     for more info, see the   gprompt_set_wrapper()   description
  local gprompt_wrapper_length=${#GPROMPT_WRAPPER}
  local gprompt_wrapper_midpoint=$(($gprompt_wrapper_length/2))
  local gprompt_wrapper_left
  local gprompt_wrapper_right

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



