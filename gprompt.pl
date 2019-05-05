#!/usr/bin/env perl

use warnings;
use strict;
use feature qw/ say /;

use Digest::MD5 qw/ md5_hex /;
use File::Basename;
use File::Path qw/ mkpath /;
use IO::File;
use Scalar::Util qw/ looks_like_number /;
use Storable;


## GPROMPT GLOBAL VARIABLES

my $version = '2019.04.29.1 (perl)';
my $source  = fileparse(__FILE__);
my $session = getppid;
my $root_dir  = "$ENV{HOME}/.gprompt";
my $cache_dir = "$root_dir/cache";
eval { mkpath("$cache_dir", 0, 0700) };
die "Critical error - gprompt requires read/write access to your gprompt storage directory ('$root_dir')!" if $@;


my %cache = (
                 conf_nm => undef,
                 conf_cs => undef,
                 gprompt => undef,
                 up_time => 0,
                 re_time => 0,
                 disable => 0,
             );

my %settings = (
                   autosave  =>  0,
                   backup    =>  0,
                   config    =>  "$root_dir/default.conf",
                   disabled  =>  0,
                   format    =>  '\h:\W \u\$ ',
                   pathtype  =>  'abs',
                   vanilla   =>  '\h:\W \u\$ ',
                   fetch     =>  -1,
                   updater   =>  'ask',
               );



my %man_sects = (
                    'NAME'           =>  1,
                    'VERSION'        =>  2,
                    'SYNOPSIS'       =>  3,
                    'CONFIGURATION'  =>  4,
                    'SETTINGS'       =>  5,
                    'COMMANDS'       =>  6,
                    'FORMATTING'     =>  7,
                    'EXIT CODES'     =>  8,
                    'EXAMPLES'       =>  9,
                );


my %settings_words = (
                           autosave  =>  \&__autosave,
                           backup    =>  \&__backup,
                           config    =>  \&__config,
                           format    =>  \&__format,
                           pathtype  =>  \&__pathtype,
                           fetch     =>  \&__fetch,
                           updater   =>  \&__updater,
                           vanilla   =>  \&__vanilla,
                      );
my %settings_flags = (
                           a  =>  \&__autosave,
                           b  =>  \&__backup,
                           c  =>  \&__config,
                           f  =>  \&__format,
                           i  =>  \&__fetch,
                           u  =>  \&__updater,
                           v  =>  \&__vanilla,
                      );
my $settings_words = ( join '|' => keys %settings_words  );
my $settings_flags = ( join ''  => keys %settings_flags  );

my %commands_words = (
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
my %commands_flags = (
                           d  =>  \&disable,
                           g  =>  \&generate,
                           h  =>  \&help,
                           I  =>  \&init,
                           l  =>  \&load,
                           o  =>  \&off,
                           p  =>  \&print,
                           r  =>  \&reload,
                           R  =>  \&reset,
                           s  =>  \&save,
                           U  =>  \&update,
                      );
my $commands_words = ( join '|' => keys %commands_words  );
my $commands_flags = ( join ''  => keys %commands_flags  );

my $version_patt = qr/  \d{4}\.\d{2}(\.\d{2})+  ( \(\w+\) )?  /;
my $setting_patt = qr/  @  [^\s:]+  (:[^\s:]+)*  /x;
my $command_patt = qr/^(?:
                                ## configuration settings
                           |      (?<set_word>  $settings_words   )
                           |  --  (?<set_optn>  $settings_words   )  (=(?<value>.*))?
                           |   -  (?<set_flag> [$settings_flags]  )
                           
                                ## commands
                           |      (?<com_word>  $commands_words   )
                           |   -  (?<com_flag> [$commands_flags]+ )
                        )$/x;

my $error_msg = "Try 'gprompt help' to learn what you can do with gprompt!";


## ---------------- ##
##   gprompt main
## ---------------- ##


# `updater_loop &> /dev/null`
# `updater_loop_id=$!`

gprompt( @ARGV );
    

## argument-parser
#
sub gprompt(@) {
    my @args = @_;
    my (%actions, $errors);
    
    if ( scalar @args == 1 ) {
        
    }

    ## iterate over all args
    for (my $i = 0; $i < scalar @args; $i++) {
        
        my  ( $j, $word, $flag, $optn, $value );  # reset argument matches
        
        if ( $args[$i] =~ $command_patt ) {
            ( $j, $word, $flag )  =  ( $i, $+{com_word}, $+{com_flag} );
            
            
            if ( $word ) {
                
                if ( $word eq 'save' or $word eq 'load' ) {
                    $j++  if  $args[$j+1]  and  $args[$j+1] eq '-f';
                    $j++  if  $args[$j+1]  and  $args[$j+1] =~ /^ $setting_patt $/x;
                } elsif ( $word eq 'update' ) {
                    $j++  if  $args[$j+1]  and  $args[$j+1] =~ /^(?:  --list  |  $version_patt  )$/x;
                } elsif ( $word eq 'help' ) {
                    $j++  if  $args[$j+1];
                } elsif ( $word eq 'init' ) {
                    $j++  if  $args[$j+1];
                }
                
                if ( $i < $j ) {
                    $commands_words{ $+{com_word} }->( @args[ ++$i .. $j ] );
                    $i = $j;
                } else {
                    $commands_words{ $+{com_word} }->();
                }
                
            } elsif ( $flag ) {
                
                if ( $flag eq 's' or $flag eq 'l' ) {
                    $j++  if  $args[$j+1]  and  $args[$j+1] =~ /^ $setting_patt $/x;
                } elsif ( $flag eq 'u' ) {
                    $j++  if  $args[$j+1]  and  $args[$j+1] =~ /^ $version_patt $/x;
                } elsif ( $flag eq 'h' ) {
                    $j++  if  $args[$j+1];
                }
                
                if ( $i < $j ) {
                    $commands_flags{ $+{com_flag} }->( @args[ ++$i .. $j ] );
                    $i = $j;
                } else {
                    $commands_flags{ $+{com_flag} }->();
                }
                
            } else {
                ( $j, $word, $flag, $optn, $value )  =  ( $i, $+{set_word}, $+{set_flag}, $+{set_optn}, $+{value} );
                
                if ( $word  and  $args[$i+2]  and  $args[$i + 1] eq '-s' ) {
                    $j = $i + 2;
                } elsif ( $word  and  $args[$i+1] ) {
                    $j = $i + 1;
                }
                
                if ( $word and $args[$i+1] ) {
                    $settings_flags{ $word }->( @args[ ++$i .. $j ] );
                    $i = $j;
                } elsif ( $flag )  {
                    $settings_flags{ $flag }->( $args[ ++$i ] );
                } elsif ( $value ) {
                    $settings_words{ $optn }->( $value );
                } elsif ( $optn ) {
                    $settings_words{ $optn }->();
                } elsif ( $word ) {
                    $settings_flags{ $word }->();
                }
            }
            
            
        } else {
            
            ## print error message for any gprompt argument that seems invalid.
            $errors++;
            warn "\nUnrecognized argument '$args[$i]'.\n";
        }
    }
    
    exit 1 if $errors;
}



## --------------------- ##
##   gprompt utilities
## --------------------- ##


## Generates a formatted help-text
#
sub help {
    my @args = @_;
      
    # return say __wrap_text( \%man_sects ) unless scalar @args;
    
    # for my $query (@args) {
    #        if  ( defined $coms_sect{$query} )  {   say __wrap_text( $coms_sect{$query} )    }
    #     elsif  ( defined $optn_sect{$query} )  {   say __wrap_text( $optn_sect{$query} )    }
    #     elsif  ( defined $man_sects{$query} )  {   say __wrap_text( $man_sects{$query} )    }
    #     else   { say __wrap_text( "\nThere is no documentation availabe for '$query'.\n" )  }
    # }
}


sub init {
    my $name = shift;
    my %sessions;
    
    __clear_session_caches();
    
    ## load the named configuration-file (&load will default is $name is undef)
    load('-f', $name);
}


## Reads the currently stored gprompt definitions from the gprompt conf file
#      • if the conf file cannot be found, gprompt will reset the existing gprompt definitions and store them to disk
#      • only the first instance of each definition will be used
#
sub load {
    my ($flag, $name) = shift;    
               $name  = $flag and $flag = undef  unless  $flag eq '-f';
        
    my %loaded = __load_by_id( $name, $flag );
    $settings{$_} = $loaded{$_} for keys %loaded;

    ## store the newly loaded configuration in a session cache
    __save_cache();
}

## Resets the gprompt format back to the default values
#      NOTE: This will overwrite your custom prompt formatting!
#            Please back up your   ~/.gprompt/default.conf   before attempting a reset!
#
sub reset {
  __clear_caches();
    
  $settings{autosave}  =  0,
  $settings{backup}    =  0,
  $settings{config}    =  "$root_dir/default.conf",
  $settings{disabled}  =  0,
  $settings{format}    =  '{\c{1;93}[\c22{%r}:\c1{%b}{\c91-{%-}}{\c92+{%+}}{ {\c96<{%s}>}{\c95({%u})}}\c93]\c0}%d $>';
  $settings{pathtype}  = 'abs';
  $settings{vanilla}   =  '\h:\W \u\$ ',
  $settings{fetch}     =  -1,
  $settings{updater}   =  'ask',

  return save( 'DEFAULT' );
}

## Disables gprompt and sets your PS1 back to the value it had before GPROMPT was initialized
#
sub off {
  $cache{disable} = 1;
  
  return __save_cache();
}

## Overwrites the existing gprompt conf file with the currently exported gprompt definitions for your session.
#
sub save {
    my ($flag, $name) = shift;
               $name  = $flag and $flag = undef  unless  $flag eq '-f';

    unless ( $flag ) {
        print "There is already a save with the name '$name'. Do you want to overwrite it? [yN]: ";
        until ( <> =~ /^((?<yes>[Yy](es)?)|(?<no>([Nn]o?)?))$/x) {
            print "\tunrecognized respons; do you want to overwrite save '$name'? [yN]: ";
        }
        return if $+{no};
    }

    __save_cache( $name or 'DEFAULT' );
    
    ## SAVE CONFIG
}



## ----------------------------- ##
##   gprompt private functions
## ----------------------------- ##

my $cache_sort = sub {
                          my ( $a_name, undef, $a_suff ) = fileparse $a => qr/\.\d+$/;
                          my ( $b_name, undef, $b_suff ) = fileparse $b => qr/\.\d+$/;
                          
                          $a_suff = 0 unless $a_suff;
                          $b_suff = 0 unless $b_suff;
                          
                          my $cmp_sessions = looks_like_number $a_name and looks_like_number $b_name;
                          
                          my $name_cmp = $cmp_sessions ? $a_name <=> $b_name : $a_name cmp $b_name;
                          
                          return $name_cmp or $a_suff <=> $b_suff;
                      };

sub __list_caches {
    my $id = shift;
       $id = '*' unless defined $id;
    
    return sort $cache_sort glob "$cache_dir/$id $cache_dir/$id.*";
}

sub __load_cache {
    my $id = shift;
       $id = $session unless defined $id;
    
    ## get the highest-numbered (e.g. the most recent) cache for the current session
    ##     (session = ppid of script process);
    my $session_cache = [ __list_caches($id) ]->[-1];
    
    ## load the relevant session-cache;
    %cache = %{ retrieve(  $session_cache  ) };
}


sub __save_cache {
    my $id = shift;
       $id = $session unless defined $id;
    
    ## get the highest-numbered (e.g. the most recent) cache for the current session
    ##     (session = ppid of script process);
    my $session_cache = [ __list_caches($id) ]->[-1];
    
    ## increment the session-cache suffix by one and store the current session-cache under the new suffix
    my ($name, undef, $suffix) = fileparse $session_cache => qr/\.\d+$/;
    $suffix++;
    store \%cache => "$cache_dir/$name.$suffix";
}


sub __clear_session_caches {
    my $id = shift;
       $id = '[0-9]*' unless defined $id;
    
    ## remove any cache-file whose id or 'session number' (ppid of this process) is no longer in use
    for ( glob "$cache_dir/$id $cache_dir/$id.*" ) {
        my $name = fileparse $_ => qr/\.\d+$/;
        
        unlink unless looks_like_number $name and kill 0, $name;
    }
}


sub __clear_caches {
    my $id = shift;
       $id = '*' unless defined $id;
       
    unlink glob "$cache_dir/$id $cache_dir/$id.*";
}


sub __load_by_id {
    my ($optn, $name, $sect) = split /@|:/ => shift;
    my (%conf, %paths);
    my $flag = shift;
    
    $name = 'DEFAULT' unless $name;
    
    open( my $conf_fh, '<' => glob $settings{config} )
        or say "Error - could not load configuration file '$settings{config}': $!" and &reset();

    my $slurp = 0;
    for (<$conf_fh>) {
        if ( /^\h*([^:]+):/  and  $1 eq uc $name ) {
            $slurp = 1;
        } elsif ($slurp  and  /^  \h+  -  \h+  (?<set>[^:]+)  :  \h+  (?<val>.*)  $/x) {
            $conf{$+{set}} = $+{val};
        } else {
            last if $slurp;
        }
    }
    close $conf_fh;
        
        
        
        
        
        
        
    #   if ( -f "$root_dir/default.conf" and `wc -l ~/.gprompt/default.conf | xargs | cut -d' ' -f1` > 0 ) {
    #     foreach $setting (@settings) {
    #       local setting_load="$(tail -r ~/.gprompt/default.conf | grep -m 1 -E "^$setting='[^']*'$" )"
    #       [[ -n $setting_load ]] && eval "export $setting_load" || return 1
    #     }
    #   } else {
        
    #   }
    
    # die "GPROMPT - could not load configuration file '$settings{config}': $!";
}


## Sets the gprompt format
#
sub __format {
    my @args = @_;
    
    return say "\t-> gprompt format set to '$settings{format}'" unless scalar @args;
    
    $settings{format} = $format;
    say "GPROMPT - format set to '$WRAPPER'";
    say "GPROMPT - NOTE: '$format' does not interact with git. $error_msg\n" unless ($format =~ /{.*}|%[\w!?^~+-]/)
}


# ##
# # my @man_pattern=(
# #                   NAME => [ $name_text ],
# #                   VERSION => [ $vers_text ],
# #                   SYNOPSIS => [ $uses_text, $help_text ],
# #                   CONFIGURATION => [ $conf_text ],
# #                   COMMANDS => [
# #                                    $coms_text{init},
# #                                    $coms_text{off},
# #                                    $coms_text{reset},
# #                                    $coms_text{load},
# #                                    $coms_text{save},
# #                                    $coms_text{update},
# #                                    $coms_text{version},
# #                                ],
# #                   OPTIONS => [ $optn_text ],
# #                   EXIT => [ $exit_text ],
# #                   EXAMPLES => [ $exam_text ],
# #               );
# #
# #
# #
# sub __wrap_text {
#     my ( $input ) = shift;
#     my $cols  = `tput cols`;
#     my ( $filler, $unwrapped;
    
#     my ( $body, $wrapped, $unwrapped )
#     if ( ref $input eq 'ARRAY' ) {
#         foreach $section ( @$input ) {
#             if ( ref $section eq 'ARRAY' ) {
#                 foreach $subsec ( @$section ) {
#                     @stack = split '\b' => ( $subsec =~ s/\n/ /r );
#                     my $level = 0;
#                     my $body = '';
#                     for (my $i; $i <= $#stack; $i++) {
#                         my $word = '';
#                         if      ( $stack[$i] eq '[' ) {
#                             $level++ or $word .= $stack[$i]
#                         } elsif ( $stack[$i] eq ']' ) {
#                             $level-- or $word .= $stack[$i]
#                         } elsif (    $level > 0     ) {
#                             $word .= $stack[$i]
#                         }
                        
#                         if ((length $word + length $body) < ($cols - 1)) {
#                             $body .= $word 
#                         } else {
#                             $body .= "\$word"
#                         }
#                     }
                    
#                     $prepped = ''
#                 }
#             else {
#                 $unwrapped = ( $section =~ s/\n/ /r );
#                 $prepped = $unwrapped;
#             }
            
#             $wrapped = $prepped;
#         }
#     } else {
#         $wrapped = ( $input =~ s/\n/ /r );
#     }

#     return $wrapped; 
# }

# ## runs in the background, exports a flag when an update is needed
# #
# sub __updater_loop {
#   while true
#   do
#     export UPDATE_NEEDED="$( __updater_check )"
#     sleep $UPDATER_INTERVAL
#   done
# }

# ## checks if an update is available
# #
# sub __updater_check {
#   echo 0
# }

# ## determines what to do when an update is ready (ask/auto/suppress)
# #
# sub __updater_mode {
#   echo 0
# }

# ## updates gprompt to the latest 'stable' tag
# #
# sub __updater {
#   local pwd="$(pwd)"
#   cd $source
#   git pull https://github.com/faelin/gprompt.git stable
#   cd $pwd
# }



## -------------------------- ##
##   gprompt core functions
## -------------------------- ##

## Updates gprompt, does not provide output
#     returns 0 before git-status variables would be updated, if CWD is not a git repo
#
sub git_status {

  ## full_path gives the CWD in relative or absolute form depending on the state of $PATHTYPE
  full_path  =  [[ $PATHTYPE == 'rel' ]] && pwd -L | sed -E "s|^(/Users|/home)?/`whoami`(/.+)?|~\2|" || pwd -L
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
sub parse_format {
  local string="$FORMAT"

  ## merge all parallel color format markers
  while [[ $( grep -E '\\c(([[:digit:]]+)|{([[:digit:];]+)})\\c(([[:digit:]]+)|{([[:digit:];]+)})' <<< "$string" ) ]]
  do
    string="$( sed -E 's!\\c(([[:digit:]]+)|{([[:digit:];]+)})\\c(([[:digit:]]+)|{([[:digit:];]+)})!\\c{\2\3;\5\6}!g' <<< "$string" )"
  done


  string=$(
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
           ' <<< "$string"
  )


  # ## this chunk condenses all parallel ANSI color-escapes and redundant non-printing-character escapes
  # #
  # while [[ $( grep -E '\\033\[([[:digit:];]+)m\\033\[([[:digit:];]+)m' <<< "$string" ) ]]
  # do
  #   string="$( sed -E 's!\\033\[([[:digit:];]+)m\\033\[([[:digit:];]+)m!\\033[\1;\2m!g' <<< "$string" )"
  # done

  # while [[ $( grep -vE '\\001\\001\\033\[([[:digit:];]+)m\\002\\002' <<< "$string" ) ]]
  # do
  #   string="$( sed -E 's!\\001\\001(\\033\[[[:digit:];]+m)\\002\\002!\\001\1\\002!g' <<< "$string" )"
  # done

  # while [[ $( grep -E '\\001\\033\[([[:digit:];]+)m\\002\\001\\033\[([[:digit:];]+)m\\002' <<< "$string" ) ]]
  # do
  #   string="$( sed -E 's!\\001\\033\[([[:digit:];]+)m\\002\\001\\033\[([[:digit:];]+)m\\002!\\001\\003[\1;\2m\\002!g' <<< "$string" )"
  # done

  echo "$string"
}

## Outputs the a populated git-prompt based on the contents of FORMAT (see the `set_format` function description for more information)
#
sub populate_prompt {
  git_status

  local string=$(parse_format)

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

           " <<< "$string"
  else
    ## if not a git-repo, strip all remaining formatting characters except for  %d
    sed -E "
            s/%{f(ull(_path)?)?}/%{full_path}/g;    s|%full_path|$full_path|g;

            s/%([[:alnum:]]+|[?!~^+-]|{[[:alnum:]]+})//g;

           " <<< "$string"

    ## strip all curly-brace wrapped content, recursively from the inside out
    while [[ $( grep -m 1 -E '(^|[^\\]){([^\\{}]+|\\[^{}]|\\[{}])*}' <<< "$string" ) ]]
    do
      string="$( sed -E 's/(^|[^\\]){([^\\{}]+|\\[^{}]|\\[{}])*}/\1/g' <<< "$string"  )"
    done
  fi
}

## Removes blank/useless values wrapped in curly-braces, then subsequently removes ALL unescaped curly-braces!
#     blank/useless is defined as any value that DOES NOT contain non-formatting alphanumeric characters
#
sub cleanup_prompt {
  local string=$1

  ## strip all blank/useless curly-brace wrapped content, recursively from the inside out
  while [[ $( grep -m 1 -E '(^|[^\\]){((\\001\\033\[[[:digit:];]+m\\002|\\c([[:digit:]]+|{[[:digit:];]+})|%[[:alpha:]~+]|[^{}[:alnum:]]*)+|[[:blank:]]+)}' <<< "$string" ) ]]
  do
    string="$( sed -E 's/(^|[^\\]){((\\001\\033\[[[:digit:];]+m\\002|\\c([[:digit:]]+|{[[:digit:];]+})|%[[:alpha:]~+]|[^{}[:alnum:]]*)+|[[:blank:]]+)}/\1/g' <<< "$string"  )"
  done

  ## strip all non-escaped curly braces, from left to right
  while [[ $( grep -m 1 -E '(^|[^\\])[{}]' <<< "$string" ) ]]
  do
    string="$( sed -E 's/(^|[^\\])[{}]/\1/g' <<< "$string"  )"
  done

  echo "$string"
}

## Generates a fully formatted/colored/populated git-prompt that can be fed directly into your shell prompt variable
#     intended usage is   export PS1='$( generate )'   or equivalent
#
sub generate {
    grpompt_reset unless __load(getppid);
    
  local string=`cleanup_prompt "$( populate_prompt )"`

  # this chunk formates the gprompt wrapper variables, which are used to pad the gprompt string
  #     for more info, see the   set_wrapper()   description
  local wrapper_length=${#WRAPPER}
  local wrapper_midpoint=$(($wrapper_length/2))
  local wrapper_left
  local wrapper_right

  if [ $wrapper_midpoint -gt 0 ]
  then
    wrapper_left=$( echo "${WRAPPER:0:$wrapper_midpoint}" )
    wrapper_right=$( echo "${WRAPPER:$wrapper_midpoint:$wrapper_length}" )
  else
    wrapper_left="${WRAPPER}"
    wrapper_right="${WRAPPER}"
  fi

  printf "${wrapper_left}${string}${wrapper_right}"
}



