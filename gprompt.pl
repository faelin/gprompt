#!/usr/bin/env perl

use warnings;
use strict;
use feature qw/ say /;

use Digest::file qw/ digest_file_hex /;
use File::Basename;
use File::Path qw/ mkpath /;
use IO::File;
use Scalar::Util qw/ looks_like_number /;
use Storable;


## GPROMPT GLOBAL CONSTANTS
our $SESSION   = getppid;
our $PWD       = $ENV{PWD};
our $HOME      = $ENV{HOME};

our $LANG      = 'perl';
our $TAGFIX    = "stable-${LANG}_";
our $VERSION   = "2019.05.24.1";
our $DATEFORM  = 'yyyy.mm.dd.';

our $CURR_SUFF  = $VERSION;
our $CURR_DATE = substr $CURR_SUFF => 0, length $DATEFORM, '';

our $SOURCE    = fileparse(__FILE__);

our $ROOT_DIR  = "$HOME/.gprompt";
our $CACHE_DIR = "$ROOT_DIR/cache";
eval { mkpath("$ROOT_DIR", 0, 0744) };
eval { mkpath("$CACHE_DIR", 0, 0700) };
die "Critical error - gprompt requires read/write access to your gprompt storage directory ('$ROOT_DIR')!" if $@;


## GPROMPT GLOBAL VARIABLES



## cache contains the following key shortnames:
#    conf_nm   (config name)
#    conf_cs   (config file checksum)
#    gprompt   (gprompt format string)
#    up_time   (time of last update)
#    re_time   (time of last refresh)
#    disable   (gprompt on/off state)
#
my %cache = (
                 conf_nm => undef,
                 conf_cs => undef,
                 gprompt => undef,
                 gformat => undef,
                 up_time => 0,
                 re_time => 0,
                 disable => 0,
             );


my %settings = (
                    autosave  =>  False,
                    backup    =>  0,
                    disabled  =>  0,
                    fetch     =>  -1,
                    format    =>  '\h:\W \u\$ ',
                    relative  =>  0,
                    refresh   =>  0,
                    update    =>  600,
                    updater   =>  'ask',
                    vanilla   =>  '\h:\W \u\$ ',
               );
my $settings_match = ( join '|' => keys %settings  );


my @settings_words = (
                           'autosave',
                           'backup',
                           'fetch',
                           'format',
                           'relative',
                           'refresh',
                           'update',
                           'updater',
                           'vanilla',
                      );
my %settings_flags = (
                           a  =>  'autosave',
                           b  =>  'backup',
                           i  =>  'fetch',
                           f  =>  'format',
                           P  =>  'relative',
                           u  =>  'updater',
                           v  =>  'vanilla',
                      );
my $settings_words = ( join '|' => @settings_words  );
my $settings_flags = ( join ''  => keys %settings_flags  );

my %commands_words = (
                           generate  =>  \&generate,
                           help      =>  \&help,
                           init      =>  \&init,
                           load      =>  \&load,
                           on        =>  \&on_off,
                           off       =>  \&on_off,
                           print     =>  \&print,
                           reload    =>  \&reload,
                           reset     =>  \&reset,
                           save      =>  \&save,
                           update    =>  \&update,
                           version   =>  \&version,
                      );
my %commands_flags = (
                           g  =>  \&generate,
                           h  =>  \&help,
                           I  =>  \&init,
                           l  =>  \&load,
                           o  =>  \&on_off,
                           p  =>  \&print,
                           r  =>  \&reload,
                           R  =>  \&reset,
                           s  =>  \&save,
                           U  =>  \&update,
                      );
my $commands_words = ( join '|' => keys %commands_words  );
my $commands_flags = ( join ''  => keys %commands_flags  );


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
my $help_msg = "Try 'gprompt help' to learn what you can do with gprompt!";


## ---------------- ##
##   gprompt main
## ---------------- ##


# `updater_loop &> /dev/null`
# `updater_loop_id=$!`

gprompt( @ARGV );
    

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

## argument-parser
#
sub gprompt (@) {
    my @args = @_;
    my (%actions, $errors);

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
                    __get_set_config( $word, @args[ ++$i .. $j ] );
                    $i = $j;
                } elsif ( $flag )  {
                    __get_set_config( $settings_flags{ $flag }, $args[ ++$i ] );
                } elsif ( $value ) {
                    __get_set_config( $optn, $value );
                } elsif ( $optn ) {
                    __get_set_config( $optn );
                } elsif ( $word ) {
                    __get_set_config( $word );
                }
            }
            
            
        } else {
            
            ## print error message for any gprompt argument that seems invalid.
            $errors++;
            say "\nUnrecognized argument '$args[$i]'.\n";
        }
    }
    
    exit 1 if $errors;
}



## --------------------- ##
##   gprompt utilities
## --------------------- ##


##
#
sub generate () {
    
}

## Generates a formatted help-text
#
sub help (@) {
    my @args = @_;
      
    # return say __wrap_text( \%man_sects ) unless scalar @args;
    
    # for my $query (@args) {
    #        if  ( defined $coms_sect{$query} )  {   say __wrap_text( $coms_sect{$query} )    }
    #     elsif  ( defined $optn_sect{$query} )  {   say __wrap_text( $optn_sect{$query} )    }
    #     elsif  ( defined $man_sects{$query} )  {   say __wrap_text( $man_sects{$query} )    }
    #     else   { say __wrap_text( "\nThere is no documentation availabe for '$query'.\n" )  }
    # }
}

## Prepares a new session to use gprompt
#    1. clears the session-cache namespace
#    2. loads the named config (uses the default config if no name is provided)
#
sub init (;$) {
    my $name = shift;
    $name = $name || 'default';
    
    &__clear_session_caches();
    
    ## load the named configuration-file
    &load('-f', $name);
}

## Reads the currently stored gprompt definitions from the gprompt conf file
#      • if the conf file cannot be found, gprompt will reset the existing gprompt definitions and store them to disk
#      • only the first instance of each definition will be used
#
sub load (;$$) {
    my ($option, $target) = @_;
       ($target, $option) = ($option, $target)  unless  $option eq '-f';  # swap $option and $name unless $option is valid
    
    $target = 'default' unless defined $target;
    
    my ($name, $conf, $sect) = split /@|:/ => $target;
    
    $name = ($name || $conf);
    
    my %loaded = &__load_by_name( $name, $option );
    
    if ( $sect ) {
        $settings{$sect} = $loaded{$sect};
    } else {
        $settings{$_} = $loaded{$_} for keys %loaded;
    }

    ## store the newly loaded configuration in a session cache
    &__save_cache();
}

## Activates/deactivates the named config file
#    • if no name is provided, then only the current session will be modified
#    • when deactivated, `gprompt generate` will print the 'vanilla' prompt
#
sub on_off (;$) {
  $cache{disable} = !$cache{disable};
  &__save_cache();
}

## Prints a formatted list of the current gprompt configuration settings
#
sub print (;$) {
    print for __format_print();
}

## Resets the current gprompt configuration settings back to the default configuration
#
sub reload () {
    load '-f' => 'default'
}

## Resets the gprompt 'default' configuration settings back to the hard-coded default values
#      clears all currently unused caches
#
sub reset () {
  &__prune_caches();
    
  $settings{autosave}  =  0;
  $settings{backup}    =  0;
  $settings{disabled}  =  0;
  $settings{format}    =  '{\c{1;93}[\c22{%r}:\c1{%b}{\c91-{%-}}{\c92+{%+}}{ {\c96<{%s}>}{\c95({%u})}}\c93]\c0}%d $>';
  $settings{relative}  =  0;
  $settings{vanilla}   =  '\h:\W \u\$ ';
  $settings{fetch}     =  -1;
  $settings{updater}   =  'ask';

  &save('default');
}

## Stores the current gprompt config into a save file
#    prompts user for overwrite-permission if a config file with the given $name already exists.
#
sub save ($;$) {
    my ($flag, $name) = @_;
       ($name, $flag) = ($flag, $name)  unless  $flag eq '-f';  # swap $flag and $name unless $flag is valid

    # confirm overwrite if targetted save-file already exists
    if ( $flag ne '-f'  and  -f "$root_dir/$name.conf" ) {
        print "There is already a saved config with the name '$name'. Do you want to overwrite it? [yN]: ";
        until ( <> =~ /^((?<yes>[Yy](es)?)|(?<no>([Nn]o?)?))$/x) {
            print "\tunrecognized response; do you want to overwrite the '$name' config file? [yN]: ";
        }
        return 0 if defined $+{no};
        
        if ( lc $name eq 'default' ) {
            print "This will modify the gprompt default configuration file. Are you sure you want to continue? [yN]: ";
            until ( <> =~ /^((?<yes>[Yy](es)?)|(?<no>([Nn]o?)?))$/x) {
                print "\tunrecognized response; are you sure you want to overwrite the default configuration file? [yN]: ";
            }
            return 0 if defined $+{no};
        }
    }
    
    
    # write save to file
    open( my $conf_fh, '>' => "$root_dir/$name.conf" )
        or say "Error - could not save to configuration file '$root_dir/$name.conf': $!";
    
    print $conf_fh for __format_print();

    close $conf_fh;
    
    
    # store current save-state in cache
    $cache{conf_cs} = __generate_checksum($name);
    $cache{conf_nm} = $name;
    __save_cache();
}

## Immediately attempts to update the gprompt source-files
#
sub update (;$) {
    my $request  = shift;
    my @versions = __list_versions();
    
    my $tag = __updater_check();
    #   git -C $source pull https://github.com/faelin/gprompt.git stable
    
    die "Failed to update! No such version '$vers'." if $!;
}

## Prints the gprompt version string
#
sub version () {
    say "gprompt release " . VERSION;
}



## ----------------------------- ##
##   gprompt private functions
## ----------------------------- ##


sub __format_print () {
    my @lines;
    
    for my $key ( keys %settings ) {
        my $param = $settings{$key};
        
        push @lines => sprintf( "%-10s %s\n" => "$key:", ($param =~ /^ -?\d+ $/x ? $param : "'$param'") );
    }
    
    return @lines;
}


sub __generate_checksum (;$) {
    my $name = shift || 'default';
    
    return digest_file_hex( "$root_dir/$name.conf" => 'SHA-1');
}

## Sorts cache-files by name and then by suffix, numerically
#
sub cache_sort {
                      my ( $a_name, undef, $a_suff ) = fileparse( $a => qr/\d+$/ );
                      my ( $b_name, undef, $b_suff ) = fileparse( $b => qr/\d+$/ );
                            # for fileparse, suffix-pattern MUST NOT include the '.', or suffixes will be compared as decimals (i.e. '.10 <=> .1' )
                      
                      my $session_cmp = $a_name <=> $b_name;
                      
                      return ($session_cmp or $a_suff <=> $b_suff);
                };

## Loads the latest cache for the specified session (defaults to current session)
#    loads config from the default config-file if no cache can be found
#
sub __load_cache (;$) {
    my $id = shift || $session;
    my @cache_list;
    
    ## list of all caches for the current session id
    ##     (session = ppid of script process)
    @cache_list = sort cache_sort glob "$cache_dir/$id.*";
    
    load() unless scalar @cache_list;
    
    ## load the highest-numbered (e.g. the most recent) cache for the current session
    %cache = %{ retrieve(  $cache_list[-1]  ) };
    
    load() if $cache{conf_cs} ne __generate_checksum( $cache{conf_nm} );
}

## Clears existing cache files for the specified session before saving a new cache file (defaults to current session)
#
sub __save_cache (;$) {
    my $id = shift || $session;
    my (@cache_list, $name, $suffix);
       
    ## remove all non-locked caches for the current session before trying to save the new cache
    &__clear_session_caches();
    
    ## list of all caches for the current session id
    ##     (session = ppid of script process)
    @cache_list = sort cache_sort glob "$cache_dir/$id.*";
    
    ## increment the suffix of the highest-numbered (e.g. the most recent) cache for the current session by one
    ##    then store the current session-cache under the new suffix
    ($name, undef, $suffix) = fileparse( $cache_list[-1] => qr/\d+$/ ) if scalar @cache_list;
    $suffix++;
    store \%cache => "$cache_dir/$name.$suffix";
}

## Remove any cache-file whose id or 'session number' (ppid of this process) is no longer in use
#
sub __clear_session_caches (;$) {
    my $id = shift || $session;
    
    unlink for glob "$cache_dir/$id.*";
}

## Remove unused cache-files
#
sub __prune_caches () {
    my ($cache, $name);
    
    ## remove any cache-file whose id or 'session number' (ppid of this process) is no longer in use
    for my $cache ( glob "$cache_dir/*.*" ) {
        $name = fileparse( $cache => qr/\.\d+$/ );
        
        unlink $cache unless `ps -o command= -c` =~ /  bash  |  (c|k|tc|z)? sh  /x;
    }
}

## Verify that the provided $val is a valid argument for the config option $key
#    sets $val to undef if value doesn't reflect accepted values for the current $key
#
sub __accept_parameters ($$) {
    my ($key, $val) = @_;
    
    if ( $key eq 'autosave' ) {
        $val = 1 if lc $val eq 'true';
        $val = 0 if lc $val eq 'false';
        $val = undef unless $val =~ /^ ( 0 | 1 ) $/x;
    } elsif ( $key eq 'backup' ) {
        $val = undef unless $val =~ /^ -?\d+ $/x;
    } elsif ( $key eq 'disabled' ) {
        $val = 1 if lc $val eq 'true';
        $val = 0 if lc $val eq 'false';
        $val = undef unless $val =~ /^ ( 0 | 1 ) $/x;
    } elsif ( $key eq 'fetch' ) {
        $val = undef unless $val =~ /^ \d+ $/x;
    } elsif ( $key eq 'format' ) {
        $val = undef unless $val;
    } elsif ( $key eq 'relative' ) {
        $val = 1 if lc $val =~ /^ rel(ative)? $/x;
        $val = 0 if lc $val =~ /^ abs(olute)? $/x;
        $val = undef unless $val =~ /^ ( 0 | 1 ) $/x;
    } elsif ( $key eq 'refresh' ) {
        $val = undef unless $val =~ /^ \d+ $/x;
    } elsif ( $key eq 'update' ) {
        $val = undef unless $val =~ /^ \d+ $/x;
    } elsif ( $key eq 'updater' ) {
        $val =  1 if lc $val =~ /^ auto(matic)? $/x;
        $val =  0 if lc $val =~ /^ ( ask | default ) $/x;
        $val = -1 if lc $val =~ /^ ( supress | ignore | never ) $/x;
        $val = undef unless $val =~ /^ ( -1 | 0 | 1 ) $/x;
    } elsif ( $key eq 'vanilla' ) {
        $val = undef unless $val;
    } else {
        return 'error';
    }
    
    return $val;
}

## Loads the config file indicated by the provided $name (loads the default config if no name is provided)
#
sub __load_by_name (@) {
    my ($name, $option) = @_;    
    $name = (lc $name or 'default');
    
    open( my $conf_fh, '<' => "$root_dir/$name.conf" )
        or say "Error - could not load configuration file '$root_dir/$name.conf': $!" and &reset();

    for (<$conf_fh>) {
        next if /^ \s* #/x;
        
        my ($key, $val) = /^ (\w+): \h+ (.*) $/x;
     
        $key = lc $key;
        $val = &__accept_parameters( $key => $val );
        
        say "Error - invalid configuration option '$key' at '$name.conf' line ${.}."
            and next
            if $val eq 'error';
            
        say "Error - configuration option '$key' requires a valid argument at '$name.conf' line ${.}."
            and next
            unless defined $val;
        
        $settings{$key} = $val;
    }
    close $conf_fh;
}

## Sets the indicated gprompt config definition
#
sub __get_set_config ($@) {
    my ($key, $opt, $val) = @_;
       ($val, $opt) = ($opt, $val)  unless  $opt eq '-s';  # swap $flag and $name unless $flag is valid
    
    return say "gprompt $key is currently set to '$settings{$key}'"  unless  $val;
     
    $key = lc $key;
    $val = &__accept_parameters( $key => $val );

    ## set $val to undef if value doesn't reflect accepted values for the current $key
    say "Warning - '$val' does not interact with git. $help_msg\n"  if  $key eq 'format' and $val !~ / (?<!\\) ( { | %[\w!?^~+-] ) /x;

    return say "Error - invalid argument for configuration option '$key'. $help_msg"  unless  $val;
    
    $settings{$key} = $val;
    &save( $cache{conf_nm} ) if $opt eq '-s';
}



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



## runs in the background, exports a flag when an update is needed
#
sub __updater_loop () {
}


## lists the existing releases of gprompt
#
sub __list_versions () {
    my @versions = split /\n/ => `git tag -l "stable-perl_*"`;
    
    return sort {
                    my $a_suff = substr( $a => length $TAGFIX );
                    my $b_suff = substr( $b => length $TAGFIX );
                    
                    my $a_date = substr( $a_suff => 0, length $DATEFORM, '' );
                    my $b_date = substr( $b_suff => 0, length $DATEFORM, '' );
                    
                    return ($b_date cmp $a_date or $b_suff <=> $a_suff);
                } @versions;
}


## lists the available updates (updates found after the current local version)
#
sub __updater_check () {
    my @versions;

    for my $check ( __list_versions() ) {
        my $check_suff = substr $check => length $TAGFIX;
        my $check_date = substr $check_suff => 0, length $DATEFORM, '';
        
        push @verions => $check if ($CURR_DATE < $check_date or $CURR_SUFF < $check_suff)
    }
    
    return @versions;
}



## determines what to do when an update is ready (ask/auto/suppress)
#
sub __updater_mode {
}



## -------------------------- ##
##   gprompt core functions
## -------------------------- ##


## Updates gprompt, does not provide output
#     returns 0 before git-status variables would be updated, if CWD is not a git repo
#
sub git_status {
    
    my $full_path  =  $settings{relative} ? $PWD =~ s!^ $HOME (?= $ | /)!~/!rx : $PWD;
    
    my @repo_status  =  split /\n/ => `git status --branch --untracked-files --ignored --porcelain=2 2>/dev/null`;
    
    if ( scalar @repo_status ) {
        
        ## name of repo origin
        my $repo_name  =  fileparse `git rev-parse --show-toplevel 2>/dev/null`;
        my ($parent_path, $local_path)  =  $full_path =~ m|^ (.*) /$repo_name (/.*)? $|x;

        ## looks like:
        ##   '<parent1 short-SHA> <parent2 short-SHA>'
        my $repo_parent    =  `git show -s --format='%p' HEAD`;
        my ($commit_parent, $commit_merged)  =  $repo_parent =~ m!^(\w+) \s* (\w*)$!x;


        my %fields = (
                          ab       => '',
                          oid      => '',
                          head     => '',
                          upstream => '',
                      );
        
        for my $item ( @repo_status ) {
                
            ## branch-status header looks like:
            ##   '# branch.oid <commit> | (initial)'        Current commit.
            ##   '# branch.head <branch> | (detached)'      Current branch.
            ##   '# branch.upstream <upstream_branch>'      If upstream is set.
            ##   '# branch.ab +<ahead> -<behind>'           If upstream is set and the commit is present.
            $fields{ $1 } = $2 and next  if  $item =~ /^#  branch\.(\w++)  \h++  (.++)/x
            $fields{ staged   }++  if  $item =~ /^[12u] \h++ [^.]/x
            $fields{ unstaged }++  if  $item =~ /^[12u] \h++ .[^.]/x
            $fields{ staged }++  if  $item =~ /^1 \h++ [^.]/x
        }
        
        
        my $staged_count  =  grep -cE '^[[:alnum:]]+ [^[:blank:].][^[:blank:]]' <<< "$repo_status" | wc -l | xargs
        $unstag_count  =  grep -cE '^[[:alnum:]]+ [^[:blank:]][^[:blank:].]' <<< "$repo_status" | wc -l | xargs


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

    } else {
        $local_path = "$full_path"
    }
}

## Replaces gprompt-specific escapes with printf-parsible ANSI color escape wrapped in PS1-parsible non-printing-characters brackets
#     exclamation points ('!') in  sed  substitutions are purely to increase legibility amonst a lot of backslashes
#
sub parse_format {
  local string="$FORMAT"

  ## merge all parallel color format markers
  while [[ $( grep -E '\\c(([[:digit:]]+)|{([[:digit:];]+)})\\c(([[:digit:]]+)|{([[:digit:];]+)})' <<< "$string" ) ]]
  do
    string="$( $string =~ s!\\c(([[:digit:]]+)|{([[:digit:];]+)})\\c(([[:digit:]]+)|{([[:digit:];]+)})!\\c{\2\3;\5\6}!g )"
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
  #   string="$( $string =~ s!\\033\[([[:digit:];]+)m\\033\[([[:digit:];]+)m!\\033[\1;\2m!g )"
  # done

  # while [[ $( grep -vE '\\001\\001\\033\[([[:digit:];]+)m\\002\\002' <<< "$string" ) ]]
  # do
  #   string="$( $string =~ s!\\001\\001(\\033\[[[:digit:];]+m)\\002\\002!\\001\1\\002!g )"
  # done

  # while [[ $( grep -E '\\001\\033\[([[:digit:];]+)m\\002\\001\\033\[([[:digit:];]+)m\\002' <<< "$string" ) ]]
  # do
  #   string="$( $string =~ s!\\001\\033\[([[:digit:];]+)m\\002\\001\\033\[([[:digit:];]+)m\\002!\\001\\003[\1;\2m\\002!g )"
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
      string="$( $string =~ s/(^|[^\\]){([^\\{}]+|\\[^{}]|\\[{}])*}/\1/g  )"
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
    string="$( $string =~ s/(^|[^\\]){((\\001\\033\[[[:digit:];]+m\\002|\\c([[:digit:]]+|{[[:digit:];]+})|%[[:alpha:]~+]|[^{}[:alnum:]]*)+|[[:blank:]]+)}/\1/g  )"
  done

  ## strip all non-escaped curly braces, from left to right
  while [[ $( grep -m 1 -E '(^|[^\\])[{}]' <<< "$string" ) ]]
  do
    string="$( $string =~ s/(^|[^\\])[{}]/\1/g  )"
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



