#!/usr/bin/env perl

#use warnings;
#use strict;
use File::Basename;
use YAML::Tiny;
use Digest::MD5 qw/ md5_hex /;
use IO::File;
use feature qw/ say switch /;


## GPROMPT GLOBAL VARIABLES

my $version = '2019.04.27.1 (perl)';
my $source = dirname(__FILE__);
my $update = 0;
my $session = getppid;

my %settings = (
                    autosave  =>  '',
                    backup    =>  '',
                    format    =>  '',
                    pathtype  =>  '',
                    vanilla   =>  '',
                    config    =>  '',
                    refresh   =>  '',
                    update    =>  '',
                    updater   =>  '',
                );
my %commands = (
                    disable   =>  \&disable,
                    generate  =>  \&generate,
                    help      =>  \&help,
                    init      =>  \&init,
                    load      =>  \&load,
                    off       =>  \&off,
                    print     =>  \&print,
                    reload    =>  \&reload,
                    reset     =>  \&reset,
                    save      =>  \&save,
                    update    =>  \&update,
                    version   =>  \&version,
                );
my %flags = (
                 d  =>  'disable',
                 i  =>  'init',
                 l  =>  'load',
                 o  =>  'off',
                 r  =>  'reload',
                 R  =>  'reset',
                 s  =>  'save',
                 v  =>  'version',
             );
my %options = (
                 a  =>  'autosave',
                 b  =>  'backup',
                 C  =>  'config',
                 f  =>  'format',
                 h  =>  'help',
                 I  =>  'refresh',
                 p  =>  'print',
                 u  =>  'update',
                 U  =>  'updater',
               );
my $xvars_string    = ( join '|' => keys %xvars    );
my $commands_string = ( join '|' => keys %commands );
my $flags_string    = ( join ''  => keys %flags    );
my $options_string  = ( join ''  => keys %options  );






my %man_sects = (
                        'NAME'           =>  [ 1, $name_text ],
                        'VERSION'        =>  [ 2, $vers_text ],
                        'SYNOPSIS'       =>  [ 3, $syno_text ],
                        'CONFIGURATION'  =>  [ 4, $conf_text ],
                        'SETTINGS'       =>  [ 5, $optn_text ],
                        'COMMANDS'       =>  [ 6, $coms_text ],
                        'FORMATTING'     =>  [ 7, $form_text ],
                        'EXIT CODES'     =>  [ 8, $exit_text ],
                        'EXAMPLES'       =>  [ 9, $exam_text ],
                   );



## ---------------- ##
##   gprompt main
## ---------------- ##

sub main {
    # `gprompt_updater_loop &> /dev/null`
    # `gprompt_updater_loop_id=$!`
    
    gprompt( @ARGV );
}

sub gprompt(@) {
    my @args = @_;
    my %actions;
    
    
    ## if the first argument is a command word, all subsequent args get passed to the function indicated by the commands hash
    if ( $args[0] =~ qr/^ ($commands_string) $/x ) {
        return $commands{ $1 }->( @args[1,-1] );
    }
    


    
    
    ## iterate over all args
    for (my $i = 0; $i <= $#args; $i++) {
        if ($args[$i] =~ qr/^ - ([$flags_string]+) $/x) {
                              ## [dilorRsv]
                                 
            $actions{ $flags{$_} }++ for split '' => $1;  ## match short-name flags that don't take arguments 

        } elsif ($args[$i] =~ qr/^ - ([$options_string]) $/x) {
                                   ## [abCfhIpuU]

            $actions{ $options{$1} } = $args[++$i]  ## match individual short-name flag that require arguments

        } elsif ($args[$i] =~ qr/^  ( --  ((?<get>get)-|set-)?   )?  (?<xvar>$xvars_string) (?(<get>)| = (?<value>.*))?  $/x) {

            if (  $+{get}  ) {
                say uc $+{xvar} . ": '$xvars{ $+{xvar} }'";
            } elsif ( $+{value} ) {
                $xvars{ $+{xvar} } = $args[++$i];
                say uc $+{xvar} . " set to '$xvars{ $+{xvar} }'";
            } else {
                $comamnds{save}->( '-f',     )  if $args[$i+1] =~ /^-s$/;
                $comamnds{load}->( $+{xvar}, )  if $args[$i+1] =~ /^-l$/;
                $xvars{ $+{xvar} } = $args[++$i];
                say uc $+{xvar} . " set to '$xvars{ $+{xvar} }'";
            }

        }   else {
                
            warn "\nUnrecognized argument '$args[$i]'! Try 'gprompt help' for more information.\n"
                ## print error message for any argument that seems invalid.
        }
    }
    
    # say "Option '$_' requires an argument.\n" . __wrap_text( $uses_text );
    # gprompt_save() if $opts{load};
}



## --------------------- ##
##   gprompt utilities
## --------------------- ##

## Generates a formatted help-text
#
sub help {
    my @args = @_;
      
    return say __wrap_text( \%man_sects ) unless scalar @args;
    
    for my $query (@args) {
           if  ( defined $coms_sect{$query} )  {   say __wrap_text( $coms_sect{$query} )    }
        elsif  ( defined $optn_sect{$query} )  {   say __wrap_text( $optn_sect{$query} )    }
        elsif  ( defined $man_sects{$query} )  {   say __wrap_text( $man_sects{$query} )    }
        else   { say __wrap_text( "\nThere is no documentation availabe for '$query'.\n" )  }
    }
}

sub init {
    open(my $fh, "<", glob '~/.gprompt/.cache')
        or die "Could not read cache-file at ~/.gprompt/.cache";
    my $checksum = md5_base64(<$fh>);
}

## Reads the currently stored gprompt definitions from the gprompt conf file
#      • if the conf file cannot be found, gprompt will reset the existing gprompt definitions and store them to disk
#      • only the first instance of each definition will be used
#
sub gprompt_load {
    my $def_name = shift;
    
    __gprompt_load_by_id( $def_name );
}

## Resets the gprompt format back to the default values
#      NOTE: this will overwrite your custom prompt formatting! Please back up your   ~/.gprompt/.gprompt_conf   before attempting a reset!
#
sub gprompt_reset {
  $gprompt_xvars{format} = '{\c{1;93}[\c22{%r}:\c1{%b}{\c91-{%-}}{\c92+{%+}}{ {\c96<{%s}>}{\c95({%u})}}\c93]\c0}%d $>';
  $gprompt_xvars{wrapper} = ' ';
  $gprompt_xvars{pathtype} = 'abs';
  $gprompt_xvars{refresh_interval} = 0;
  $gprompt_xvars{updater_mode} = 0;
  $gprompt_xvars{updater_interval} = 600;
  $gprompt_xvars{autosave} = 1;
  $gprompt_xvars{backup} = 1;

  return gprompt_save;
}

## Disables gprompt and sets your PS1 back to the value it had before GPROMPT was initialized
#
sub gprompt_off {
  export PS1="$GPROMPT_OFF"
}


## Sets the gprompt format
#
sub gprompt_set_format {
  case "$1" in
    -h|--help|help|h|'')
      echo << EOHELP
EOHELP
      return 0
    }
    when ('*') 
      export GPROMPT_FORMAT="$1"
      say "GPROMPT - wrapper is '$GPROMPT_WRAPPER'";
      return 0
    }
  esac
}

## Short string used to pad your prompt, recommended default is ' ' (single blank space)
#     provided string is split at midpoint (round down) to create left- and right-wrappers,
#     thus a wrapper '[]' yields '[<gprompt>]'
#     while a wrapper '[(]' yields '[<gprompt>(]'
#
sub gprompt_set_wrapper {
  export GPROMPT_WRAPPER="$1"
  return 0
}

## Type of path that should be displayed by %d when not in a git-repo
#     options are:  'abs',  'rel'
#
sub gprompt_set_pathtype {
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
sub gprompt_save {
    # use Storable;
    # store \%table, 'file';
    # $hashref = retrieve('file');
    
    
    
  mkdir ~/.gprompt 2> /dev/null
  touch ~/.gprompt/.gprompt_conf

  echo "gpropmpt - saving current config"

  for xvar in "${gprompt_xvars[@]}"
  do
    local gprompt_xvar_save="$( eval echo "\${$xvar}" )"
    echo "    $xvar='$gprompt_xvar_save'"

    sed -i -e "/^$xvar=/d" ~/.gprompt/.gprompt_conf
    echo "$xvar='$gprompt_xvar_save'" >> ~/.gprompt/.gprompt_conf
  done
}



## ----------------------------- ##
##   gprompt private functions
## ----------------------------- ##

sub __gprompt_load_by_id {
    my $ppid = shift;
    
    open my $conf_fh, '<' => glob '~/.gprompt/.gprompt_conf'
        or gprompt_reset;
    
    my @config = @{[<FILE>]};
    print $total,"\n";

      if ( -f ~/.gprompt/.gprompt_conf and `wc -l ~/.gprompt/.gprompt_conf | xargs | cut -d' ' -f1` > 0 ) {
        foreach $xvar (@gprompt_xvars) {
          local gprompt_xvar_load="$(tail -r ~/.gprompt/.gprompt_conf | grep -m 1 -E "^$xvar='[^']*'$" )"
          [[ -n $gprompt_xvar_load ]] && eval "export $gprompt_xvar_load" || return 1
        }
      } else {
        
      }
}

##
# my @man_pattern=(
#                   NAME => [ $name_text ],
#                   VERSION => [ $vers_text ],
#                   SYNOPSIS => [ $uses_text, $help_text ],
#                   CONFIGURATION => [ $conf_text ],
#                   COMMANDS => [
#                                    $coms_text{init},
#                                    $coms_text{off},
#                                    $coms_text{reset},
#                                    $coms_text{load},
#                                    $coms_text{save},
#                                    $coms_text{update},
#                                    $coms_text{version},
#                                ],
#                   OPTIONS => [ $optn_text ],
#                   EXIT => [ $exit_text ],
#                   EXAMPLES => [ $exam_text ],
#               );
#
#
#
sub __wrap_text {
    my ( $input ) = shift;
    my $cols  = `tput cols`;
    my ( $filler, $unwrapped;
    
    my ( $body, $wrapped, $unwrapped )
    if ( ref $input eq 'ARRAY' ) {
        foreach $section ( @$input ) {
            if ( ref $section eq 'ARRAY' ) {
                foreach $subsec ( @$section ) {
                    @stack = split '\b' => ( $subsec =~ s/\n/ /r );
                    my $level = 0;
                    my $body = '';
                    for (my $i; $i <= $#stack; $i++) {
                        my $word = '';
                        if      ( $stack[$i] eq '[' ) {
                            $level++ xor $word .= $stack[$i]
                        } elsif ( $stack[$i] eq ']' ) {
                            $level-- xor $word .= $stack[$i]
                        } elsif (    $level > 0     ) {
                            $word .= $stack[$i]
                        }
                        
                        if ((length $word + length $body) < ($cols - 1)) {
                            $body .= $word 
                        } else {
                            $body .= "\$word"
                        }
                    }
                    
                    $prepped = ''
                }
            else {
                $unwrapped = ( $section =~ s/\n/ /r );
                $prepped = $unwrapped;
            }
            
            $wrapped = $prepped;
        }
    } else {
        $wrapped = ( $input =~ s/\n/ /r );
    }

    return $wrapped; 
}

## runs in the background, exports a flag when an update is needed
#
sub __gprompt_updater_loop {
  while true
  do
    export GPROMPT_UPDATE_NEEDED="$( __gprompt_updater_check )"
    sleep $GPROMPT_UPDATER_INTERVAL
  done
}

## checks if an update is available
#
sub __gprompt_updater_check {
  echo 0
}

## determines what to do when an update is ready (ask/auto/suppress)
#
sub __gprompt_updater_mode {
  echo 0
}

## updates gprompt to the latest 'stable' tag
#
sub __gprompt_updater {
  local pwd="$(pwd)"
  cd $gprompt_source
  git pull https://github.com/faelin/gprompt.git stable
  cd $pwd
}



## -------------------------- ##
##   gprompt core functions
## -------------------------- ##

## Updates gprompt, does not provide output
#     returns 0 before git-status variables would be updated, if CWD is not a git repo
#
sub gprompt_git_status {

  ## full_path gives the CWD in relative or absolute form depending on the state of $GPROMPT_PATHTYPE
  full_path  =  [[ $GPROMPT_PATHTYPE == 'rel' ]] && pwd -L | sed -E "s|^(/Users|/home)?/`whoami`(/.+)?|~\2|" || pwd -L
  repo_name  =  basename -s .git $( git config --get remote.origin.url ) 2> /dev/null

  if [[ -n $repo_name ]]
  then
    repo_status  =  git status --branch --ignored --porcelain=2
    repo_parent  =  git show -s --format='%P' HEAD
    parent_path  =  sed -nE "s|^(.*)/$repo_name/.*?$|\1|p" <<< "$full_path"
    local_path   =  sed -nE "s|^.*/$repo_name(/.*)?$|\1|p" <<< "$full_path"

    ## looks like:
    ##   '<parent1 SHA> <parent2 SHA>'
    commit_parent  =  sed -nE 's!^([[:alnum:]]{7}).*$!\1!p' <<< "$repo_parent"
    commit_merged  =  sed -nE 's!^([[:alnum:]]{7})[[:alnum:]]+ ([[:alnum:]]{7}).*$!\2!p' <<< "$repo_parent"


    ## looks like:
    ##   '# branch.oid <commit> | (initial)'        Current commit.
    ##   '# branch.head <branch> | (detached)'      Current branch.
    ##   '# branch.upstream <upstream_branch>'      If upstream is set.
    ##   '# branch.ab +<ahead> -<behind>'           If upstream is set and the commit is present.
    commit_hash   =  sed -nE 's!^# branch.oid (\((initial)\)|([[:alnum:]]{7})).*$!\2\3!p' <<< "$repo_status"
    branch_name   =  sed -nE 's!^# branch.head (\((detached)\)|(.*))$!\2\3!p' <<< "$repo_status"
    origin_name   =  sed -nE 's!^# branch.upstream (.*)$!\1!p' <<< "$repo_status"
    ahead_count   =  sed -nE 's!^# branch.ab \+([[:digit:]]+) -([[:digit:]]+)$!\1!p' <<< "$repo_status"
    behind_count  =  sed -nE 's!^# branch.ab \+([[:digit:]]+) -([[:digit:]]+)$!\2!p' <<< "$repo_status"
    staged_count  =  grep -cE '^[[:alnum:]]+ [^[:blank:].][^[:blank:]]' <<< "$repo_status" | wc -l | xargs
    unstag_count  =  grep -cE '^[[:alnum:]]+ [^[:blank:]][^[:blank:].]' <<< "$repo_status" | wc -l | xargs


    ## reference:
    ##   M = modified
    ##   A = added
    ##   D = deleted
    ##   C = copied
    ##   R = renamed
    ##   U = updated but unmerged
    ##   ! = ignored
    ##   ? = untracked
    mod_count        =  grep -cE '^.M' <<< "$repo_status" | wc -l | xargs
    add_count        =  grep -cE '^.A' <<< "$repo_status" | wc -l | xargs
    del_count        =  grep -cE '^.D' <<< "$repo_status" | wc -l | xargs
    cop_count        =  grep -cE '^.C' <<< "$repo_status" | wc -l | xargs
    re_count         =  grep -cE '^.D' <<< "$repo_status" | wc -l | xargs
    up_count         =  grep -cE '^.U' <<< "$repo_status" | wc -l | xargs
    ignored_count    =  grep -ce '^!!' <<< "$repo_status" | wc -l | xargs
    untracked_count  =  grep -ce '^??' <<< "$repo_status" | wc -l | xargs

  else
    local_path="$full_path"
  fi
}

## Replaces gprompt-specific escapes with printf-parsible ANSI color escape wrapped in PS1-parsible non-printing-characters brackets
#     exclamation points ('!') in  sed  substitutions are purely to increase legibility amonst a lot of backslashes
#
sub gprompt_parse_format {
  local gprompt_string="$GPROMPT_FORMAT"

  ## merge all parallel color format markers
  while [[ $( grep -E '\\c(([[:digit:]]+)|{([[:digit:];]+)})\\c(([[:digit:]]+)|{([[:digit:];]+)})' <<< "$gprompt_string" ) ]]
  do
    gprompt_string="$( sed -E 's!\\c(([[:digit:]]+)|{([[:digit:];]+)})\\c(([[:digit:]]+)|{([[:digit:];]+)})!\\c{\2\3;\5\6}!g' <<< "$gprompt_string" )"
  done


  gprompt_string=$(
    sed -E '
              s/%([[:alnum:]]+|[[:alnum:]?!~^+_-])/%{\1}/g;
                  ## wrap all formatting codes in curly braces ('{}')
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
sub gprompt_populate_prompt {
  gprompt_git_status

  local gprompt_string=$(gprompt_parse_format)

  if [[ -n $repo_name ]]
  then
    # if in a git-repo, populate all format-strings
    sed -E "
            ## DIRECTORY INFO
            s/%{p(ath)?}/%{parent_path}/g;                   s|%{parent_path}|$parent_path|g;
            s/%{(d(ir(ectory)?)?|local)}/%{local_path}/g;    s|%{local_path}|$local_path|g;
            s/%{f(ull(_path)?)?}/%{full_path}/g;             s|%{full_path}|$full_path|g;

            ## REPO INFO
            s/%{r(epo)?}/%repo/g;                      s|%repo|$repo_name|g;
            s/%{b(ranch)?}/%branch/g;                  s|%branch|$branch_name|g;
            s/%{(c(om(mit)?)?|hash|sha)}/%commit/g;    s|%commit|$commit_hash|g;

            ## BRANCH STATE
            s/%{(\+|ahead)}/$ahead_count/g;
            s/%{(\-|behind)}/$behind_count/g;
            s/%{(\~|parent)}/$commit_parent/g;
            s/%{(\^|merged)}/$commit_merged/g;

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
    ## if not a git-repo, strip all remaining formatting characters except for  %d
    sed -E "
            s/%{f(ull(_path)?)?}/%{full_path}/g;    s|%full_path|$full_path|g;

            s/%([[:alnum:]]+|[?!~^+-]|{[[:alnum:]]+})//g;

           " <<< "$gprompt_string"

    ## strip all curly-brace wrapped content, recursively from the inside out
    while [[ $( grep -m 1 -E '(^|[^\\]){([^\\{}]+|\\[^{}]|\\[{}])*}' <<< "$gprompt_string" ) ]]
    do
      gprompt_string="$( sed -E 's/(^|[^\\]){([^\\{}]+|\\[^{}]|\\[{}])*}/\1/g' <<< "$gprompt_string"  )"
    done
  fi
}

## Removes blank/useless values wrapped in curly-braces, then subsequently removes ALL unescaped curly-braces!
#     blank/useless is defined as any value that DOES NOT contain non-formatting alphanumeric characters
#
sub gprompt_cleanup_prompt {
  local gprompt_string=$1

  ## strip all blank/useless curly-brace wrapped content, recursively from the inside out
  while [[ $( grep -m 1 -E '(^|[^\\]){((\\001\\033\[[[:digit:];]+m\\002|\\c([[:digit:]]+|{[[:digit:];]+})|%[[:alpha:]~+]|[^{}[:alnum:]]*)+|[[:blank:]]+)}' <<< "$gprompt_string" ) ]]
  do
    gprompt_string="$( sed -E 's/(^|[^\\]){((\\001\\033\[[[:digit:];]+m\\002|\\c([[:digit:]]+|{[[:digit:];]+})|%[[:alpha:]~+]|[^{}[:alnum:]]*)+|[[:blank:]]+)}/\1/g' <<< "$gprompt_string"  )"
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
sub gprompt_generate {
    grpompt_reset unless __gprompt_load(getppid);
    
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



