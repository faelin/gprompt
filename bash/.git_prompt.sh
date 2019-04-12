parse_git_branch() {
	mod_count=$(git ls-files -d -m -o --no-empty-directory --exclude-standard 2> /dev/null | wc -l | sed -E "s/^ +0$//; s/ +([0-9]+)/ <\1>/")
	git_status=$(git branch -v 2> /dev/null | grep '^* ' | sed -E "s/^\* ([^ ]+) [A-Za-z0-9]+( \[(behind|ahead) ([0-9]+)\])? .*$/[\1\2${mod_count}]/")
	git_status=$(echo $git_status | sed -E "s/ \[behind ([0-9]+)\]/~\1/; s/ \[ahead ([0-9]+)\]/+\1/")
	echo $git_status
}
print_git_branch() {
	parse_git_branch | sed -E "s/^\[([^~+ ]+)(~[0-9]+)?(\+[0-9]+)?( <[0-9]+>)?\]$/$(echo -e " \033[1;33m[\1\033[31m\2\033[33m\033[92m\3\033[33m\033[95m\4\033[33m]\033[0m")/"
}
 
parse_git_branch_with_repo() {
	repo_name=$(basename -s .git `git config --get remote.origin.url` 2> /dev/null)
	parse_git_branch | sed -E "s/^\[(.*)\]$/[${repo_name}:\1]/"
}
print_git_branch_with_repo() {
	parse_git_branch_with_repo | sed -E "s/^\[([^:]+)(:[^~+ ]+)(~[0-9]+)?(\+[0-9]+)?( <[0-9]+>)?\]$/$(echo -e " \033[1;33m[\033[22;21m\1\033[1m\2\033[31m\3\033[33m\033[92m\4\033[33m\033[95m\5\033[33m]\033[0m")/"
}
 
is_git_branch() {
 	git branch 2> /dev/null
}
 
### PS1 OPTIONS:
### these PS1 prompts will show you the branchname (if in a git repo), number of commits behind (if any), and number of modified files (if any)
### for each prompt type, the first (1st) option will show you only the git-branch and status, while the second (2nd) will show you the project and branch
###    git_status examples
###      [master~1]          is on the 'master' branch of the repo you are in, one (1) commit behind the remote HEAD
###      [devel <3>]         is on the 'devel'  branch of the repo you are in, with three (3) modified/added/deleted files
###      [my_proj:stuff+2]   is on the 'stuff' branch of the 'my_proj' repo (the repo you are in), two (2) commits ahead of the remote HEAD
#
#
##   EITHER basename [git_status] OR pwd (if not in a repo) $>
#export PS1='\[\033[1;34m`[ "$(is_git_branch)" ] && basename $(pwd) || pwd`\033[0m\]\[$(print_git_branch)\]\[\033[97m\] \$> \[\033[0m\]'
export PS1='\[\033[1;34m`[ "$(is_git_branch)" ] && basename $(pwd) || pwd`\033[0m\]\[$(print_git_branch_with_repo)\]\[\033[97m\] \$> \[\033[0m\]'
#
# 
##   pwd [git_status] $>
#export PS1='\[\033[1;34m\w\[\033[0m\]\[`print_git_branch`\]\[\033[97m\] \$> \[\033[0m\]'
#export PS1='\[\033[1;34m\w\[\033[0m\]\[`print_git_branch_with_repo`\]\[\033[97m\] \$> \[\033[0m\]'
#
#
##   user@basename [git_status] $>
#export PS1='\[\u\]:\[\033[96m\W\[\033[0m\]\[`print_git_branch`\]\[\033[97m\] \$> \[\033[0m\]'
#export PS1='\[\u\]:\[\033[96m\W\[\033[0m\]\[`print_git_branch_with_repo`\]\[\033[97m\] \$> \[\033[0m\]'
#
#
##   user:pwd [git_status] $>
#export PS1='\[\033[39m\u\]:\[\033[96m\w\[\033[0m\]\[`print_git_branch`\]\[\033[97m\] \$> \[\033[0m\]'
#export PS1='\[\033[39m\u\]:\[\033[96m\w\[\033[0m\]\[`print_git_branch_with_repo`\]\[\033[97m\] \$> \[\033[0m\]'
#
#
###





