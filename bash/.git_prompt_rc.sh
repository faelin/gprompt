#
#
#  MUTABLE COLOR BLOCK — EDIT THIS TO DETERMINE COLOR SCHEME
#
###
COLOR_BEHIND='91'
COLOR_AHEAD='92'
COLOR_TITLE='93'
COLOR_UNSTAGED='95'
COLOR_STAGED='96'
###
#
#
#
#

TOTAL_RESET='0'
STYLE_BOLD='1'
STYLE_RESET='22'

GPROMPT_FORMAT='{\c{1;93}[\c22%r:\c1%b{\c91~%~}{\c92+%+}{ {\c96<%s>}{\c95(%u)}}\c93]\c0}%d $>'
#GPROMPT_FORMAT='{%p[%r:%b%~%+ <%s>(%u)]}%d $>'
#GPROMPT_FORMAT='[%r:%b%~%+{(%c)} <%s>(%u)] Git://%r%d $>'
#GPROMPT_FORMAT='%p [%b%~%+{(%c)} <%s>(%u)]'
GPROMPT_WRAPPER=' '

get_git_status() {
  full_path=$( pwd )
  repo_name=$( basename -s .git $( git config --get remote.origin.url ) 2> /dev/null )

  part_path=$( [ $repo_name ] && sed -nE "s|^(.*)/$repo_name(/.*)?$|\1|p" <<< "$pre_path" )
  repo_path=$( [ $repo_name ] && sed -nE "s|^.*/$repo_name(/.*)?$|\1|p" <<< "$repo_path" || echo "$full_path" )
  [ -z $repo_name ] && return 1

  branch_status=$( [ $repo_name ] && git branch -v 2> /dev/null | grep '^* ' )

  staged_count=$( [ $repo_name ] && git status --porcelain=1 2> /dev/null | grep -e '^[^?! ]' | wc -l | sed -E 's|0||' | xargs )
  unstag_count=$( [ $repo_name ] && git status --porcelain=1 2> /dev/null | grep -e '^.[^ ]'  | wc -l | sed -E 's|0||' | xargs )

  branch_name=$(  [ $repo_name ] && sed -nE 's|^[[:blank:]]*\*[[:blank:]]+([^[[:blank:]]+)[[:blank:]]+[^[:blank:]]+[[:blank:]]+.*|\1|p' <<< "$branch_status"  )
  commit_name=$(  [ $repo_name ] && sed -nE 's|^[[:blank:]]*\*[[:blank:]]+[^[[:blank:]]+[[:blank:]]+([^[:blank:]]+)[[:blank:]]+.*|\1|p' <<< "$branch_status"  )
  ahead_count=$(  [ $repo_name ] && sed -nE 's|^[[:blank:]]*\*[[:blank:]]+[^[:blank:]]+[[:blank:]]+[^[:blank:]]+[[:blank:]]+(\[ahead[[:blank:]]+([[:digit:]]+)\])?.*|\2|p' <<< "$branch_status"  | xargs )
  behind_count=$( [ $repo_name ] && sed -nE 's|^[[:blank:]]*\*[[:blank:]]+[^[:blank:]]+[[:blank:]]+[^[:blank:]]+[[:blank:]]+(\[behind[[:blank:]]+([[:digit:]]+)\])?.*|\2|p' <<< "$branch_status"  | xargs )
}

parse_git_format() {
  sed -e "s|%r|$repo_name|g" \
      -e "s|%d|$repo_path|g" \
      -e "s|%p|$part_path|g" \
      -e "s|%p|$full_path|g" \
      -e "s|%b|$branch_name|g" \
      -e "s|%+|$ahead_count|g" \
      -e "s|%~|$behind_count|g" \
      -e "s|%s|$staged_count|g" \
      -e "s|%u|$unstag_count|g" \
      <<< $GPROMPT_FORMAT | \
  sed -E 's/\\c(([[:digit:]]+)|{([[:digit:];]+)})(\\c(([[:digit:]]+)|{([[:digit:];]+)}))?/\\[\\e[\2\3;\5\6m\\]/g'
#     -E 's|((\\e\[([[:digit:]]+;)+m)+)|\[\1\]|g' \
#     -E "s|\\t<([[:digit:]]+)>|\e[\2\3m|g" \
## this line intentionally left blank
}

strip_git_prompt() {
  gprompt_input=$1
  if [ -z $repo_name ];  ## if pwd is not a git repo
  then
    ## strip all non-escaped-curly-brace wrapped content, recursively from the inside out
    while [ "$( grep -E '(^|[^\\]){([^{}\\]+|\\[^{}]|\\\\|\\{|\\})*}' <<< $gprompt_input  )" ]
    do
      gprompt_input=$( sed -E 's/(^|[^\\]){([^{}\\]+|\\[^{}]|\\\\|\\{|\\})*}/\1/g' <<< $gprompt_input  )
    done
  else
    ## strip all "empty" (not [A-Za-z0-9\s_-]) non-escaped-curly-brace wrapped content, recursively from the inside out
    while [ "$( grep -E '(^|[^\\]){((\\[\\e\[[[:digit:];]+m\\]|[^{}[:alnum:][:blank:]_-]*)+|[[:blank:]]+)}' <<< $gprompt_input  )" ]
    do
      gprompt_input=$( sed -E 's/(^|[^\\]){((\\[\\e\[[[:digit:];]+m\\]|[^{}[:alnum:][:blank:]_-]*)+|[[:blank:]]+)}/\1/g' <<< $gprompt_input  )
    done
  fi

  ## strip all non-escaped curly braces, from left to right
  while [ "$( grep -E '(^|[^\\])[{}]' <<< $gprompt_input )" ]
  do
    gprompt_input=$( sed -E 's/(^|[^\\])[{}]/\1/g' <<< $gprompt_input  )
  done

  echo $gprompt_input
}

generate_git_prompt() {
  get_git_status
  strip_git_prompt "$(parse_git_format)"
}
### PS1 OPTIONS:
### these PS1 prompts will show you the branchname (if in a git repo), number of commits behind (if any), and number of modified files (if any)
### for each prompt type, the first (1st) option will show you only the git-branch and status, while the second (2nd) will show you the project and branch
###    FORMATTING IS AS FOLLOWS:  [repo:branch~n <x>(y)] where
###       'repo'    is the name of the repository you are in
###       'branch'  is the name of the branch you are viewing
###       '~n'      is the position of your local HEAD relative to the remote origin  (~ is locally behind, + is locally ahead, 'n' is the number of commits)
###       '<x>'     is the number of files that are staged for pushing
###       '(y)'     is the number of files that have been modified/added/deleted but are NOT YET STAGED
###
###    git_state examples:
###       [master~1]          is on the 'master' branch of the repo you are in, one (1) commit behind the remote HEAD
###       [stuffs+2]          is on the 'stuffs' branch of the repo you are in, two (2) commits ahead of the remote HEAD
###       [devel (5)]         is on the 'devel'  branch of the repo you are in, with five (5) modified/added/deleted files
###       [devel <3>(1)]      is on the 'devel'  branch of the repo you are in, with three (3) staged files and one (1) modified/added/deleted file
###       [my_proj:stuff+2]   is on the 'stuff'  branch of the 'my_proj' repo (the repo you are in), two (2) commits ahead of the remote HEAD
#
#
export PS1='$GPROMPT_WRAPPER$( generate_git_prompt )$GPROMPT_WRAPPER'
#
#
###





