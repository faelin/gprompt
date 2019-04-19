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

L_BRK='\['
R_BRK='\]'
LL_BRK='\\['
RR_BRK='\\]'
LPAREN='\\('
RPAREN='\\)'

get_repo_name() {
	basename -s .git $( git config --get remote.origin.url ) 2> /dev/null
}
parse_git_status() {
	staged_count=$( git status --porcelain=1 2> /dev/null | grep -e '^[^?! ]' | wc -l | sed -E "s/([0-9]+``)/<\1>/; s/\<0\>//" | xargs )
	unstag_count=$( git status --porcelain=1 2> /dev/null | grep -e '^.[^ ]'  | wc -l | sed -E "s/([0-9]+)/(\1)/; s/\(0\)//" | xargs )
	file_state=$( [ ${unstag_count} ] || [ ${staged_count} ] && echo ' '${staged_count}${unstag_count} )
	git_state=$( git branch -v 2> /dev/null | grep '^* ' | sed -E "s/^\* ([^ ]+) [A-Za-z0-9]+( \[(behind|ahead) ([0-9]+)\])? .*$/[\1\2$file_state]/" )
	git_state=$( echo $git_state | sed -E "s/ \[behind ([0-9]+)\]/~\1/; s/ \[ahead ([0-9]+)\]/+\1/" )
	echo $git_state
}
parse_git_status_with_repo() {
	parse_git_status | sed -E "s/^\[(.*)\]$/[$(get_repo_name):\1]/"
}

colorize_git_status() {
	echo "sed -E 's|^${LL_BRK}([^:]+:)?([^~+\] ]+)(~[[:digit:]]+)?(\+[[:digit:]]+)?( )?(<[[:digit:]]+>)?(${LPAREN}[[:digit:]]+${RPAREN})?.*${RR_BRK}$|${L_BRK}${STYLE_BOLD}${COLOR_TITLE}${R_BRK}${L_BRK}[${STYLE_RESET}${R_BRK}\1${L_BRK}${STYLE_BOLD}${R_BRK}\2${L_BRK}${COLOR_BEHIND}${R_BRK}\3${L_BRK}${COLOR_AHEAD}${R_BRK}\4\5${L_BRK}${COLOR_STAGED}${R_BRK}\6${L_BRK}${COLOR_UNSTAGED}${R_BRK}\7${L_BRK}${COLOR_TITLE}${R_BRK}]${L_BRK}${TOTAL_RESET}${R_BRK}|'"
}

long_path_or_pwd() {
 	[ get_repo_name ] && pwd | sed -E "s|^.*/($(get_repo_name)(/[^[:space:]]*)?)$| Git://\1|" || pwd
}
local_path_or_pwd() {
 	[ get_repo_name ] && pwd | sed -E "s|^.*/$(get_repo_name)/?([^[:space:]]*)?$|/\1|" || pwd
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
##   EITHER basename [git_state] OR pwd (if not in a repo) $>
#export PS1=" \$( parse_git_status | $(colorize_git_status) )\$( long_path_or_pwd ) \[${STYLE_BOLD}\]\$>\[${STYLE_RESET}\] "
export PS1=" \$( parse_git_status_with_repo | $(colorize_git_status) )\$( local_path_or_pwd ) \[${STYLE_BOLD}\]\$>\[${STYLE_RESET}\] "
#
# 
##   pwd [git_state] $>
#export PS1="\[\033[1;34m\]\w\[\033[0m\]\$(parse_git_status)\[\033[97m\] \$> \[\033[0m\]"
#export PS1="\[\033[1;34m\]\w\[\033[0m\]$(color_git_status_with_repo)\[\033[97m\] \$> \[\033[0m\]"
#
#
##   user@basename [git_state] $>
#export PS1="\[\033[0m\]\u:\[\033[96m\]\W\[\033[0m\]$(color_git_status)\[\033[97m\] \$> \[\033[0m\]"
#export PS1="\[\033[0m\]\u:\[\033[96m\]\W\[\033[0m\]$(color_git_status_with_repo)\[\033[97m\] \$> \[\033[0m\]"
#
#
##   user:pwd [git_state] $>
#export PS1="\[\033[39m\]\u:\[\033[96m\]\w\[\033[0m\]$(color_git_status)\[\033[97m\] \$> \[\033[0m\]"
#export PS1="\[\033[39m\]\u:\[\033[96m\]\w\[\033[0m\]$(color_git_status_with_repo)\[\033[97m\] \$> \[\033[0m\]"
#
#
###





