#
#
#  MUTABLE COLOR BLOCK — EDIT THIS TO DETERMINE COLOR SCHEME
#
###
COLOR_BEHIND='\e[91m'
COLOR_AHEAD='\e[92m'
COLOR_TITLE='\e[93m'
COLOR_UNSTAGED='\e[95m'
COLOR_STAGED='\e[96m'
###
#
#
#
#

TOTAL_RESET='\e[0m'
STYLE_BOLD='\e[1m'
STYLE_RESET='\e[22m'


GPROMPT_FORMAT='{[%r:%b%~%+{ {<%s>}{(%u)}}]}%d $>'
#GPROMPT_FORMAT='{%p[%r:%b%~%+ <%s>(%u)]}%d $> '
#GPROMPT_FORMAT='[%r:%b%~%+ <%s>(%u)] Git://%r%d $> '
#GPROMPT_FORMAT='%p [%b%~%+ <%s>(%u)]'
GPROMPT_WRAPPER=' '

get_git_status() {
  full_path=$( pwd )
  repo_name=$( basename -s .git $( git config --get remote.origin.url ) 2> /dev/null | xargs )

  part_path=$( [ $repo_name ] && sed -nE "s|^(.*)/$repo_name(/.*)?$|\1|p" <<< $pre_path )
  repo_path=$( [ $repo_name ] && sed -nE "s|^.*/$repo_name(/.*)?$|\1|p" <<< $repo_path || echo "$full_path" )
  [ -z $repo_name ] && return 1

  branch_status=$( [ $repo_name ] && git branch -v 2> /dev/null | grep '^* ' | xargs )

  staged_count=$(  [ $repo_name ] && git status --porcelain=1 2> /dev/null | grep -e '^[^?! ]' | wc -l | sed -E 's|0||' | xargs )
  unstag_count=$(  [ $repo_name ] && git status --porcelain=1 2> /dev/null | grep -e '^.[^ ]'  | wc -l | sed -E 's|0||' | xargs )

  branch_name=$(  [ $repo_name ] && sed -nE 's|^[[:blank:]]*\*[[:blank:]]+([^[[:blank:]]+)[[:blank:]].*|\1|p' <<< $branch_status  )
  ahead_count=$(  [ $repo_name ] && sed -nE 's|^[[:blank:]]*\*[[:blank:]]+[^[[:blank:]]+[[:blank:]]+(\[ahead[[:blank:]]+([[:digit:]]+)\])?.*|\2|2' <<< $branch_status  | xargs )
  behind_count=$( [ $repo_name ] && sed -nE 's|^[[:blank:]]*\*[[:blank:]]+[^[[:blank:]]+[[:blank:]]+(\[behind[[:blank:]]+([[:digit:]]+)\])?.*|\2|2' <<< $branch_status  | xargs )
}

strip_git_prompt() {
  read gprompt_input
  if [ -z $repo_name ];  ## if pwd is not a git repo
  then
    ## strip all non-escaped-curly-brace wrapped content, recursively from the inside out
    while [ "$( grep -E '(^|[^\\]){([^{}\\]+|\\[^{}]|\\\\|\\{|\\})*}' <<< $gprompt_input  )" ]
    do
      gprompt_input=$( sed -E 's/(^|[^\\]){([^{}\\]+|\\[^{}]|\\\\|\\{|\\})*}/\1/g' <<< $gprompt_input  )
    done
  else
    ## strip all "empty" (not [A-Za-z0-9\s_-]) non-escaped-curly-brace wrapped content, recursively from the inside out
    while [ "$( grep -E '(^|[^\\]){([^{}[:alnum:][:blank:]_-]*|[[:blank:]]+)}' <<< $gprompt_input  )" ]
    do
      gprompt_input=$( sed -E 's/(^|[^\\]){([^{}[:alnum:][:blank:]_-]*|[[:blank:]]+)}/\1/g' <<< $gprompt_input  )
    done
  fi

  ## strip all non-escaped curly braces, from left to right
  while [ "$( grep -E '(^|[^\\])[{}]' <<< $gprompt_input )" ]
  do
    gprompt_input=$( sed -E 's/(^|[^\\])[{}]/\1/g' <<< $gprompt_input  )
  done

  echo "$gprompt_input"
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
      <<< $GPROMPT_FORMAT
## this line intentionally left blank
}

colorize_git_prompt() {
	sed -E "s|^\[([^:]+:)?([^~+\] ]+)(~[[:digit:]]+)?(\+[[:digit:]]+)?( )?((<[[:digit:]]+>)?)((\([[:digit:]]+\))?).*\].*$|\[$STYLE_BOLD$COLOR_TITLE\]\[[$STYLE_RESET\]\1\[$STYLE_BOLD\]\2\[$COLOR_BEHIND\]\3\[$COLOR_AHEAD\]\4\5\[$COLOR_STAGED\]\6\[$COLOR_UNSTAGED\]\8\[$COLOR_TITLE\]]\[$TOTAL_RESET\]|"
}

generate_git_prompt() {
  get_git_status
  parse_git_format | strip_git_prompt
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





