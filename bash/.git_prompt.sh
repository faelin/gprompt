COLOR_RED='\\033[91m'
COLOR_GREEN='\\033[92m'
COLOR_YELLOW='\\033[93m'
COLOR_PINK='\\033[95m'
COLOR_CYAN='\\033[96m'
COLOR_RESET='\\033[0m'
STYLE_BOLD='\\033[1m'
STYLE_RESET='\\033[22m'


parse_git_branch() {
	staged_count=$(git status --porcelain=1 2> /dev/null | grep -e '^[^?! ]' | wc -l | sed -E "s/([0-9]+``)/<\1>/; s/\<0\>//" | xargs)
	unstag_count=$(git status --porcelain=1 2> /dev/null | grep -e '^.[^ ]'  | wc -l | sed -E "s/([0-9]+)/(\1)/; s/\(0\)//" | xargs)
	file_state=$([ ${unstag_count} ] || [ ${staged_count} ] && echo ' '${staged_count}${unstag_count})
	git_state=$(git branch -v 2> /dev/null | grep '^* ' | sed -E "s/^\* ([^ ]+) [A-Za-z0-9]+( \[(behind|ahead) ([0-9]+)\])? .*$/[\1\2$file_state]/")
	git_state=$(echo $git_state | sed -E "s/ \[behind ([0-9]+)\]/~\1/; s/ \[ahead ([0-9]+)\]/+\1/")
	echo $git_state
}
color_git_branch() {
	parse_git_branch | sed -E "s/^\[([^~+ ]+)(~[0-9]+)?(\+[0-9]+)?( )?(<[0-9]+>)?(\([0-9]+\))?\]$/$(echo " \\\[${STYLE_BOLD}${COLOR_YELLOW}\\\][\1\\\[${COLOR_RED}\\\]\2\\\[${COLOR_GREEN}\\\]\3\4\\\[${COLOR_CYAN}\\\]\5\\\[${COLOR_PINK}\\\]\6\\\[${COLOR_YELLOW}\\\]]\\\[${COLOR_RESET}\\\]")/"
}
 
parse_git_branch_with_repo() {
	repo_name=$(basename -s .git `git config --get remote.origin.url` 2> /dev/null)
	parse_git_branch | sed -E "s/^\[(.*)\]$/[${repo_name}:\1]/"
}
color_git_branch_with_repo() {
	parse_git_branch_with_repo | sed -E "s/^\[([^:]+)(:[^~+ ]+)(~[0-9]+)?(\+[0-9]+)?( )?(<[0-9]+>)?(\([0-9]+\))?\]$/$(echo " \\\[${STYLE_BOLD}${COLOR_YELLOW}\\\][\\\[${STYLE_RESET}\\\]\1\\\[${STYLE_BOLD}\\\]\2\\\[${COLOR_RED}\\\]\3\\\[${COLOR_GREEN}\\\]\4\5\\\[${COLOR_CYAN}\\\]\6\\\[${COLOR_PINK}\\\]\7\\\[${COLOR_YELLOW}\\\]]\\\[${COLOR_RESET}\\\]")/"
}
 
basename_or_pwd() {
 	[ "$(git branch 2> /dev/null)" ] && basename $(pwd) || pwd
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
#export PS1="\[\033[1;34m\]$(basename_or_pwd)\[\033[0m\]$(color_git_branch)\[\033[97m\] \$> \[\033[0m\]"
export PS1="\[\033[1;34m\]$(basename_or_pwd)\[\033[0m\]$(color_git_branch_with_repo)\[\033[97m\] \$> \[\033[0m\]"
#
# 
##   pwd [git_state] $>
#export PS1="\[\033[1;34m\]\w\[\033[0m\]$(color_git_branch)\[\033[97m\] \$> \[\033[0m\]"
#export PS1="\[\033[1;34m\]\w\[\033[0m\]$(color_git_branch_with_repo)\[\033[97m\] \$> \[\033[0m\]"
#
#
##   user@basename [git_state] $>
#export PS1="\[\033[0m\]\u:\[\033[96m\]\W\[\033[0m\]$(color_git_branch)\[\033[97m\] \$> \[\033[0m\]"
#export PS1="\[\033[0m\]\u:\[\033[96m\]\W\[\033[0m\]$(color_git_branch_with_repo)\[\033[97m\] \$> \[\033[0m\]"
#
#
##   user:pwd [git_state] $>
#export PS1="\[\033[39m\]\u:\[\033[96m\]\w\[\033[0m\]$(color_git_branch)\[\033[97m\] \$> \[\033[0m\]"
#export PS1="\[\033[39m\]\u:\[\033[96m\]\w\[\033[0m\]$(color_git_branch_with_repo)\[\033[97m\] \$> \[\033[0m\]"
#
#
###





